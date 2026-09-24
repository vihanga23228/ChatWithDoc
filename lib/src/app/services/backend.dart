import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// Typed wrappers around the REST endpoints (everything except authentication).
class Backend {
  final ApiClient _api;

  Backend(this._api);

  // ---- Doctors ----

  Future<List<Doctor>> doctors({String? specialization}) async {
    final json = await _api.get(
      '/api/doctors',
      query: specialization == null ? null : {'specialization': specialization},
    );
    return (json as List).map((e) => Doctor.fromJson(e)).toList();
  }

  Future<List<Review>> doctorReviews(String doctorId) async {
    final json = await _api.get('/api/doctors/$doctorId/reviews');
    return (json as List).map((e) => Review.fromJson(e)).toList();
  }

  Future<DoctorProfile> myDoctorProfile() async =>
      DoctorProfile.fromJson(await _api.get('/api/doctors/me'));

  // ---- Admin ----

  Future<List<DoctorProfile>> doctorsByStatus(DoctorStatus status) async {
    final json = await _api.get(
      '/api/admin/doctors',
      query: {'status': status.name.toUpperCase()},
    );
    return (json as List).map((e) => DoctorProfile.fromJson(e)).toList();
  }

  Future<void> approveDoctor(String doctorId) =>
      _api.post('/api/admin/doctors/$doctorId/approve');

  Future<void> rejectDoctor(String doctorId, String reason) =>
      _api.post('/api/admin/doctors/$doctorId/reject', {'reason': reason});

  // ---- Patients ----

  Future<PatientProfile> myPatientProfile() async =>
      PatientProfile.fromJson(await _api.get('/api/patients/me'));

  // ---- Wallet ----

  Future<Wallet> wallet() async => Wallet.fromJson(await _api.get('/api/wallet'));

  Future<List<WalletTransaction>> walletTransactions() async {
    final json = await _api.get('/api/wallet/transactions');
    return (json as List).map((e) => WalletTransaction.fromJson(e)).toList();
  }

  Future<Wallet> topUp(double amount) async =>
      Wallet.fromJson(await _api.post('/api/wallet/top-up', {'amount': amount}));

  /// [paymentMethod] is `CARD` or `WALLET`.
  Future<Wallet> buyPoints(int points, String paymentMethod) async =>
      Wallet.fromJson(
        await _api.post('/api/wallet/points', {
          'points': points,
          'paymentMethod': paymentMethod,
        }),
      );

  // ---- Consultations ----

  Future<List<Consultation>> consultations() async {
    final json = await _api.get('/api/consultations');
    return (json as List).map((e) => Consultation.fromJson(e)).toList();
  }

  Future<Consultation> consultation(String id) async =>
      Consultation.fromJson(await _api.get('/api/consultations/$id'));

  Future<Consultation> startConsultation(
    String doctorId,
    PaymentOption option,
  ) async => Consultation.fromJson(
    await _api.post('/api/consultations', {
      'doctorId': doctorId,
      'paymentOption': option.name.toUpperCase(),
    }),
  );

  Future<Consultation> completeConsultation(String id) async =>
      Consultation.fromJson(await _api.post('/api/consultations/$id/complete'));

  Future<PatientProfile> consultationPatient(String id) async =>
      PatientProfile.fromJson(await _api.get('/api/consultations/$id/patient'));

  /// Doctor gives the patient extra allowance. [amount] defaults on the server
  /// (TEXT +50 words, VOICE +60 s, IMAGE +1 photo, VIDEO +30 s).
  Future<Consultation> grantAllowance(
    String id,
    MessageType type, {
    int? amount,
    String? note,
  }) async => Consultation.fromJson(
    await _api.post('/api/consultations/$id/grants', {
      'type': type.name.toUpperCase(),
      'amount': ?amount,
      'note': ?note,
    }),
  );

  Future<void> review(String id, int rating, String? comment) =>
      _api.post('/api/consultations/$id/review', {
        'rating': rating,
        'comment': ?comment,
      });

  // ---- Messages ----

  /// All messages, or only those after [afterRaw] (a `sentAt` string from the server) when catching up.
  Future<List<ChatMessage>> messages(String consultationId, {String? afterRaw}) async {
    final json = await _api.get(
      '/api/consultations/$consultationId/messages',
      query: afterRaw == null ? null : {'after': afterRaw},
    );
    return (json as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<ChatMessage> sendText(String consultationId, String content) async =>
      ChatMessage.fromJson(
        await _api.post('/api/consultations/$consultationId/messages', {
          'content': content,
        }),
      );

  Future<ChatMessage> sendMedia(
    String consultationId, {
    required MessageType type,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    int? durationSeconds,
  }) async => ChatMessage.fromJson(
    await _api.postMultipart(
      '/api/consultations/$consultationId/messages/media',
      fields: {
        'type': type.name.toUpperCase(),
        if (durationSeconds != null) 'durationSeconds': '$durationSeconds',
      },
      fileBytes: bytes,
      fileName: fileName,
      contentType: contentType,
    ),
  );

  Future<void> markRead(String consultationId) =>
      _api.post('/api/consultations/$consultationId/messages/read');

  Future<Uint8List> mediaBytes(String mediaUrl) => _api.getBytes(mediaUrl);
}
