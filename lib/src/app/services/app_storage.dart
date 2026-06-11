import '../models/users.dart';

class ChatSession {
  final String consultantId;
  final String consultantName;
  final String consultantSpecialization;
  final String? consultantAvatar;
  final List<ChatMessage> messages;
  final DateTime startedAt;
  DateTime lastMessageTime;

  ChatSession({
    required this.consultantId,
    required this.consultantName,
    required this.consultantSpecialization,
    this.consultantAvatar,
    required this.messages,
    required this.startedAt,
    required this.lastMessageTime,
  });

  String getLastMessage() {
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.text.length > 50
        ? messages.last.text.substring(0, 50) + '...'
        : messages.last.text;
  }
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.fromUser,
    required this.timestamp,
  });
}

class AppStorage {
  static final List<PatientUser> patients = [];
  static final List<ConsultantUser> consultants = [
    ConsultantUser(
      id: 'c1',
      name: 'Dr. Mira Sen',
      email: 'mira@clinic.com',
      password: 'doctor123',
      phone: '+94 77 123 4567',
      slmcNumber: 'SLMC-2019-12345',
      specialization: 'Cardiology',
      hospital: 'Colombo National Hospital',
      experienceYears: 10,
      degree: 'MBBS',
      university: 'University of Colombo',
      graduationYear: 2014,
      consultationFee: 45,
      about:
          'Heart specialist with 10 years of experience. Dedicated to providing compassionate, patient-centered care.',
      languages: ['English', 'Sinhala'],
      status: 'approved',
      walletBalance: 125,
      avatarUrl: 'https://i.pravatar.cc/150?img=56',
      rating: 4.8,
      totalReviews: 245,
    ),
    ConsultantUser(
      id: 'c2',
      name: 'Dr. Ravi Kumar',
      email: 'ravi@clinic.com',
      password: 'doctor123',
      phone: '+94 77 234 5678',
      slmcNumber: 'SLMC-2018-98765',
      specialization: 'General Practice',
      hospital: 'HealthCare Clinic',
      experienceYears: 12,
      degree: 'MBBS',
      university: 'University of Peradeniya',
      graduationYear: 2012,
      consultationFee: 35,
      about:
          'Experienced GP helping patients improve overall health. Specializes in preventive care and chronic disease management.',
      languages: ['English', 'Tamil'],
      status: 'approved',
      walletBalance: 98,
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      rating: 4.7,
      totalReviews: 189,
    ),
  ];

  static final Map<String, List<ChatSession>> patientChatHistories = {};
  static PatientUser? currentPatient;
  static ConsultantUser? currentConsultant;

  static T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final element in list) {
      if (test(element)) return element;
    }
    return null;
  }

  static PatientUser? findPatient(String email) {
    return _firstWhereOrNull(patients, (patient) => patient.email == email);
  }

  static ConsultantUser? findConsultant(String email) {
    return _firstWhereOrNull(
      consultants,
      (consultant) => consultant.email == email,
    );
  }

  static void registerPatient(PatientUser patient) {
    patients.add(patient);
    currentPatient = patient;
    patientChatHistories[patient.email] = [];
  }

  static void registerConsultant(ConsultantUser consultant) {
    consultants.add(consultant);
    currentConsultant = consultant;
  }

  static PatientUser? loginPatient(String email, String password) {
    final patient = findPatient(email);
    if (patient != null && patient.password == password) {
      currentPatient = patient;
      if (!patientChatHistories.containsKey(email)) {
        patientChatHistories[email] = [];
      }
      return patient;
    }
    return null;
  }

  static ConsultantUser? loginConsultant(String email, String password) {
    final consultant = findConsultant(email);
    if (consultant != null && consultant.password == password) {
      currentConsultant = consultant;
      return consultant;
    }
    return null;
  }

  // Chat history methods
  static void addChatMessage(
    String patientEmail,
    String consultantId,
    String consultantName,
    String consultantSpecialization,
    String? consultantAvatar,
    String messageText,
    bool fromUser,
  ) {
    if (!patientChatHistories.containsKey(patientEmail)) {
      patientChatHistories[patientEmail] = [];
    }

    final sessions = patientChatHistories[patientEmail]!;
    final existingSession = _firstWhereOrNull(
      sessions,
      (session) => session.consultantId == consultantId,
    );

    final now = DateTime.now();
    final message = ChatMessage(
      text: messageText,
      fromUser: fromUser,
      timestamp: now,
    );

    if (existingSession != null) {
      existingSession.messages.add(message);
      existingSession.lastMessageTime = now;
    } else {
      final newSession = ChatSession(
        consultantId: consultantId,
        consultantName: consultantName,
        consultantSpecialization: consultantSpecialization,
        consultantAvatar: consultantAvatar,
        messages: [message],
        startedAt: now,
        lastMessageTime: now,
      );
      sessions.add(newSession);
    }
  }

  static List<ChatSession> getPatientChatHistory(String patientEmail) {
    return patientChatHistories[patientEmail] ?? [];
  }

  static ChatSession? getChatSession(String patientEmail, String consultantId) {
    final sessions = patientChatHistories[patientEmail] ?? [];
    return _firstWhereOrNull(
      sessions,
      (session) => session.consultantId == consultantId,
    );
  }
}
