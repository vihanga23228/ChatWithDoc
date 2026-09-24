// End-to-end check of the app's service layer against a running backend (not the UI).
//
//   1. Start the backend:   cd ChatWithDoc-Backend && gradlew bootRun
//   2. Run:                 flutter test test/live_backend_test.dart --dart-define=LIVE_BACKEND=true
//                             --dart-define=API_BASE_URL=http://localhost:8055
//
// Uses the seeded accounts (patient@example.com, ravi@clinic.com). Skipped in normal test runs.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chat_with_doc/src/app/models/models.dart';
import 'package:chat_with_doc/src/app/services/api_client.dart';
import 'package:chat_with_doc/src/app/services/auth_service.dart';
import 'package:chat_with_doc/src/app/services/backend.dart';
import 'package:chat_with_doc/src/app/services/realtime_service.dart';

const _live = bool.fromEnvironment('LIVE_BACKEND');

/// One logged-in user with their own API client and realtime connection.
class _Session {
  final api = ApiClient(TokenStore(persist: false));
  late final auth = AuthService(api);
  late final backend = Backend(api);
  late final realtime = RealtimeService(api);
}

Future<T> _next<T>(Stream<T> stream, bool Function(T) test) =>
    stream.firstWhere(test).timeout(const Duration(seconds: 10));

Future<void> _connected(RealtimeService realtime) async {
  if (realtime.connected.value) return;
  final completer = Completer<void>();
  void listener() {
    if (realtime.connected.value && !completer.isCompleted) completer.complete();
  }

  realtime.connected.addListener(listener);
  await completer.future.timeout(const Duration(seconds: 10));
  realtime.connected.removeListener(listener);
  // The SUBSCRIBE frame is sent right after CONNECTED; give the server a moment to register it.
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

void main() {
  test('login, wallet, consultation, realtime chat, grants and completion', () async {
    final patient = _Session();
    final doctor = _Session();

    // Auth
    final patientUser = await patient.auth.login('patient@example.com', 'patient123');
    expect(patientUser.role, Role.patient);
    final doctorUser = await doctor.auth.login('ravi@clinic.com', 'doctor123');
    expect(doctorUser.role, Role.doctor);

    await expectLater(
      patient.auth.login('patient@example.com', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    // Wallet: buy the points needed for a points consultation.
    await patient.backend.buyPoints(100, 'CARD');
    final wallet = await patient.backend.wallet();
    expect(wallet.points, greaterThanOrEqualTo(100));

    // Doctors list
    final doctors = await patient.backend.doctors();
    final ravi = doctors.firstWhere((d) => d.name == 'Dr. Ravi Kumar');

    // Close any consultation left over from an earlier run.
    for (final c in await patient.backend.consultations()) {
      if (c.doctorId == ravi.id && c.isActive) {
        await patient.backend.completeConsultation(c.id);
      }
    }

    // Realtime: both connect
    doctor.realtime.connect();
    patient.realtime.connect();
    await _connected(doctor.realtime);
    await _connected(patient.realtime);

    // Start a points consultation: the doctor is told immediately.
    final doctorSeesNewChat = _next(
      doctor.realtime.events,
      (e) => e.type == RealtimeEventType.consultationUpdated,
    );
    final consultation = await patient.backend.startConsultation(
      ravi.id,
      PaymentOption.points,
    );
    expect(consultation.type, ConsultationType.points);
    expect(consultation.allowance!.remaining.textWords, 100);
    expect((await doctorSeesNewChat).consultationId, consultation.id);

    // Patient sends a message: the doctor receives it live.
    final doctorGetsMessage = _next(
      doctor.realtime.eventsFor(consultation.id),
      (e) => e.type == RealtimeEventType.messageCreated,
    );
    final sent = await patient.backend.sendText(consultation.id, 'Hello doctor, I have a headache');
    expect(sent.mine, isTrue);
    final received = (await doctorGetsMessage).message;
    expect(received.content, 'Hello doctor, I have a headache');
    expect(received.mine, isFalse);

    // Typing indicator reaches the patient.
    final patientSeesTyping = _next(
      patient.realtime.eventsFor(consultation.id),
      (e) => e.type == RealtimeEventType.typing,
    );
    doctor.realtime.sendTyping(consultation.id, true);
    expect((await patientSeesTyping).data['typing'], isTrue);

    // Doctor reads: the patient gets a read receipt.
    final patientGetsReceipt = _next(
      patient.realtime.eventsFor(consultation.id),
      (e) => e.type == RealtimeEventType.messagesRead,
    );
    await doctor.backend.markRead(consultation.id);
    expect((await patientGetsReceipt).data['readerId'], doctorUser.id);

    // Photo upload and protected download.
    final photo = await patient.backend.sendMedia(
      consultation.id,
      type: MessageType.image,
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]),
      fileName: 'test.jpg',
      contentType: 'image/jpeg',
    );
    expect(photo.type, MessageType.image);
    expect(await doctor.backend.mediaBytes(photo.mediaUrl!), hasLength(7));

    // Allowance: the patient's counter updates live when the doctor grants more voice time.
    final patientSeesGrant = _next(
      patient.realtime.eventsFor(consultation.id),
      (e) =>
          e.type == RealtimeEventType.consultationUpdated &&
          e.consultation.allowance!.allowed.voiceSeconds == 240,
    );
    await doctor.backend.grantAllowance(consultation.id, MessageType.voice);
    final afterGrant = (await patientSeesGrant).consultation.allowance!;
    expect(afterGrant.remaining.photos, 4);
    expect(afterGrant.used.textWords, 6);

    // Catch-up query used after reconnects.
    final missed = await doctor.backend.messages(consultation.id, afterRaw: sent.sentAtRaw);
    expect(missed.map((m) => m.id), [photo.id]);

    // Completion is pushed to the patient; then the patient reviews.
    final patientSeesEnd = _next(
      patient.realtime.eventsFor(consultation.id),
      (e) =>
          e.type == RealtimeEventType.consultationUpdated &&
          e.consultation.status == ConsultationStatus.completed,
    );
    await doctor.backend.completeConsultation(consultation.id);
    await patientSeesEnd;
    await patient.backend.review(consultation.id, 5, 'Very helpful');
    expect((await patient.backend.consultation(consultation.id)).reviewed, isTrue);

    // Token refresh keeps the session working.
    expect(await patient.api.refreshTokens(), isTrue);
    expect((await patient.backend.wallet()).points, greaterThanOrEqualTo(0));

    patient.realtime.disconnect();
    doctor.realtime.disconnect();
    await patient.auth.logout();
    await doctor.auth.logout();
  }, skip: _live ? false : 'Set --dart-define=LIVE_BACKEND=true with the backend running');
}
