import 'package:flutter_test/flutter_test.dart';

import 'package:chat_with_doc/src/app/models/models.dart';
import 'package:chat_with_doc/src/app/utils/format.dart';

void main() {
  test('parses a consultation from the backend JSON', () {
    final consultation = Consultation.fromJson({
      'id': 'c1',
      'type': 'POINTS',
      'status': 'ACTIVE',
      'fee': 0,
      'pointsCost': 100,
      'allowance': {
        'allowed': {'textWords': 100, 'photos': 5, 'voiceSeconds': 180, 'videoSeconds': 60},
        'used': {'textWords': 10, 'photos': 0, 'voiceSeconds': 0, 'videoSeconds': 0},
        'remaining': {'textWords': 90, 'photos': 5, 'voiceSeconds': 180, 'videoSeconds': 60},
      },
      'patient': {'id': 'p1', 'name': 'Sample Patient', 'avatarUrl': null},
      'doctor': {
        'id': 'd1',
        'userId': 'u1',
        'name': 'Dr. Mira Sen',
        'avatarUrl': null,
        'specialization': 'Cardiology',
      },
      'startedAt': '2026-09-24T10:00:00Z',
      'endedAt': null,
      'lastActivityAt': '2026-09-24T10:05:00.123456Z',
      'lastMessagePreview': 'Hello',
      'unreadCount': 2,
      'reviewed': false,
    });

    expect(consultation.type, ConsultationType.points);
    expect(consultation.isActive, isTrue);
    expect(consultation.allowance!.remaining.textWords, 90);
    expect(consultation.doctorName, 'Dr. Mira Sen');
    expect(consultation.unreadCount, 2);
  });

  test('parses a media message', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'consultationId': 'c1',
      'senderId': 'p1',
      'senderName': 'Sample Patient',
      'senderRole': 'PATIENT',
      'type': 'VOICE',
      'content': null,
      'mediaUrl': '/api/consultations/c1/messages/m1/media',
      'mediaContentType': 'audio/aac',
      'durationSeconds': 45,
      'sentAt': '2026-09-24T10:05:00.123456Z',
      'readAt': null,
      'mine': true,
    });

    expect(message.type, MessageType.voice);
    expect(message.sentAtRaw, '2026-09-24T10:05:00.123456Z');
    expect(message.markRead(DateTime.now()).readAt, isNotNull);
  });

  test('formats values for display', () {
    expect(formatMoney(1500), 'Rs 1,500.00');
    expect(formatDuration(75), '1:15');
    expect(countWords('  I have   chest pain '), 4);
    expect(initialsOf('Dr. Mira Sen'), 'MS');
  });
}
