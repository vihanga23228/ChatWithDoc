// Data classes mirroring the backend's JSON responses (see ChatWithDoc-Backend/README.md).

enum Role { patient, doctor, admin }

Role _role(String value) => Role.values.byName(value.toLowerCase());

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;

class AppUser {
  final String id;
  final String name;
  final String email;
  final Role role;
  final String? phone;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    role: _role(json['role']),
    phone: json['phone'],
    avatarUrl: json['avatarUrl'],
  );
}

/// A doctor as patients see them (public profile).
class Doctor {
  final String id;
  final String name;
  final String? avatarUrl;
  final String slmcNumber;
  final String specialization;
  final String? hospital;
  final int experienceYears;
  final String? degree;
  final String? university;
  final int? graduationYear;
  final double consultationFee;
  final String? about;
  final List<String> languages;
  final double rating;
  final int totalReviews;

  const Doctor({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.slmcNumber,
    required this.specialization,
    this.hospital,
    required this.experienceYears,
    this.degree,
    this.university,
    this.graduationYear,
    required this.consultationFee,
    this.about,
    required this.languages,
    required this.rating,
    required this.totalReviews,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'],
    name: json['name'],
    avatarUrl: json['avatarUrl'],
    slmcNumber: json['slmcNumber'],
    specialization: json['specialization'],
    hospital: json['hospital'],
    experienceYears: json['experienceYears'] ?? 0,
    degree: json['degree'],
    university: json['university'],
    graduationYear: json['graduationYear'],
    consultationFee: _double(json['consultationFee']),
    about: json['about'],
    languages: List<String>.from(json['languages'] ?? const []),
    rating: _double(json['rating']),
    totalReviews: json['totalReviews'] ?? 0,
  );
}

enum DoctorStatus { pending, approved, rejected }

/// The logged-in doctor's own profile, including approval status and wallet.
class DoctorProfile {
  final String id;
  final String name;
  final String email;
  final String slmcNumber;
  final String specialization;
  final DoctorStatus status;
  final String? rejectionReason;
  final double walletBalance;
  final int points;
  final double rating;
  final int totalReviews;
  final double consultationFee;

  const DoctorProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.slmcNumber,
    required this.specialization,
    required this.status,
    this.rejectionReason,
    required this.walletBalance,
    required this.points,
    required this.rating,
    required this.totalReviews,
    required this.consultationFee,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) => DoctorProfile(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    slmcNumber: json['slmcNumber'],
    specialization: json['specialization'],
    status: DoctorStatus.values.byName(
      (json['status'] as String).toLowerCase(),
    ),
    rejectionReason: json['rejectionReason'],
    walletBalance: _double(json['walletBalance']),
    points: json['points'] ?? 0,
    rating: _double(json['rating']),
    totalReviews: json['totalReviews'] ?? 0,
    consultationFee: _double(json['consultationFee']),
  );
}

class PatientProfile {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? healthHistory;
  final String? drugAllergies;

  /// Only present when the patient views their own profile.
  final double? walletBalance;
  final int? points;

  const PatientProfile({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.healthHistory,
    this.drugAllergies,
    this.walletBalance,
    this.points,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    userId: json['userId'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    healthHistory: json['healthHistory'],
    drugAllergies: json['drugAllergies'],
    walletBalance: (json['walletBalance'] as num?)?.toDouble(),
    points: json['points'],
  );
}

/// Words, photos and seconds of voice/video a patient may send in a POINTS consultation.
class Quota {
  final int textWords;
  final int photos;
  final int voiceSeconds;
  final int videoSeconds;

  const Quota(this.textWords, this.photos, this.voiceSeconds, this.videoSeconds);

  factory Quota.fromJson(Map<String, dynamic> json) => Quota(
    json['textWords'] ?? 0,
    json['photos'] ?? 0,
    json['voiceSeconds'] ?? 0,
    json['videoSeconds'] ?? 0,
  );
}

class Allowance {
  final Quota allowed;
  final Quota used;
  final Quota remaining;

  const Allowance(this.allowed, this.used, this.remaining);

  factory Allowance.fromJson(Map<String, dynamic> json) => Allowance(
    Quota.fromJson(json['allowed']),
    Quota.fromJson(json['used']),
    Quota.fromJson(json['remaining']),
  );
}

enum ConsultationType { paid, points }

enum ConsultationStatus { active, completed }

class Consultation {
  final String id;
  final ConsultationType type;
  final ConsultationStatus status;
  final double fee;
  final int pointsCost;

  /// Null for PAID consultations (unlimited messages).
  final Allowance? allowance;
  final String patientId;
  final String patientName;
  final String? patientAvatarUrl;
  final String doctorId;
  final String doctorUserId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String doctorSpecialization;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime lastActivityAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool reviewed;

  const Consultation({
    required this.id,
    required this.type,
    required this.status,
    required this.fee,
    required this.pointsCost,
    this.allowance,
    required this.patientId,
    required this.patientName,
    this.patientAvatarUrl,
    required this.doctorId,
    required this.doctorUserId,
    required this.doctorName,
    this.doctorAvatarUrl,
    required this.doctorSpecialization,
    required this.startedAt,
    this.endedAt,
    required this.lastActivityAt,
    this.lastMessagePreview,
    required this.unreadCount,
    required this.reviewed,
  });

  bool get isActive => status == ConsultationStatus.active;

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>;
    final doctor = json['doctor'] as Map<String, dynamic>;
    return Consultation(
      id: json['id'],
      type: ConsultationType.values.byName(
        (json['type'] as String).toLowerCase(),
      ),
      status: ConsultationStatus.values.byName(
        (json['status'] as String).toLowerCase(),
      ),
      fee: _double(json['fee']),
      pointsCost: json['pointsCost'] ?? 0,
      allowance: json['allowance'] == null
          ? null
          : Allowance.fromJson(json['allowance']),
      patientId: patient['id'],
      patientName: patient['name'],
      patientAvatarUrl: patient['avatarUrl'],
      doctorId: doctor['id'],
      doctorUserId: doctor['userId'],
      doctorName: doctor['name'],
      doctorAvatarUrl: doctor['avatarUrl'],
      doctorSpecialization: doctor['specialization'],
      startedAt: _date(json['startedAt'])!,
      endedAt: _date(json['endedAt']),
      lastActivityAt: _date(json['lastActivityAt'])!,
      lastMessagePreview: json['lastMessagePreview'],
      unreadCount: json['unreadCount'] ?? 0,
      reviewed: json['reviewed'] ?? false,
    );
  }
}

enum MessageType { text, image, voice, video }

class ChatMessage {
  final String id;
  final String consultationId;
  final String senderId;
  final String senderName;
  final Role senderRole;
  final MessageType type;
  final String? content;

  /// API path of the media file; must be fetched with the Authorization header.
  final String? mediaUrl;
  final String? mediaContentType;
  final int? durationSeconds;
  final DateTime sentAt;

  /// Server timestamp exactly as received, used for `?after=` catch-up queries.
  final String sentAtRaw;
  final DateTime? readAt;
  final bool mine;

  const ChatMessage({
    required this.id,
    required this.consultationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.type,
    this.content,
    this.mediaUrl,
    this.mediaContentType,
    this.durationSeconds,
    required this.sentAt,
    required this.sentAtRaw,
    this.readAt,
    required this.mine,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    consultationId: json['consultationId'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    senderRole: _role(json['senderRole']),
    type: MessageType.values.byName((json['type'] as String).toLowerCase()),
    content: json['content'],
    mediaUrl: json['mediaUrl'],
    mediaContentType: json['mediaContentType'],
    durationSeconds: json['durationSeconds'],
    sentAt: _date(json['sentAt'])!,
    sentAtRaw: json['sentAt'],
    readAt: _date(json['readAt']),
    mine: json['mine'] ?? false,
  );

  ChatMessage markRead(DateTime at) => ChatMessage(
    id: id,
    consultationId: consultationId,
    senderId: senderId,
    senderName: senderName,
    senderRole: senderRole,
    type: type,
    content: content,
    mediaUrl: mediaUrl,
    mediaContentType: mediaContentType,
    durationSeconds: durationSeconds,
    sentAt: sentAt,
    sentAtRaw: sentAtRaw,
    readAt: readAt ?? at,
    mine: mine,
  );
}

class Wallet {
  final double balance;
  final int points;
  final double pricePerPoint;
  final int consultationPointsCost;

  const Wallet({
    required this.balance,
    required this.points,
    required this.pricePerPoint,
    required this.consultationPointsCost,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    balance: _double(json['balance']),
    points: json['points'] ?? 0,
    pricePerPoint: _double(json['pricePerPoint']),
    consultationPointsCost: json['consultationPointsCost'] ?? 0,
  );
}

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final int points;
  final double balanceAfter;
  final int pointsAfter;
  final String description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.points,
    required this.balanceAfter,
    required this.pointsAfter,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'],
        type: json['type'],
        amount: _double(json['amount']),
        points: json['points'] ?? 0,
        balanceAfter: _double(json['balanceAfter']),
        pointsAfter: json['pointsAfter'] ?? 0,
        description: json['description'],
        createdAt: _date(json['createdAt'])!,
      );
}

class Review {
  final int rating;
  final String? comment;
  final String patientName;
  final DateTime createdAt;

  const Review({
    required this.rating,
    this.comment,
    required this.patientName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    rating: json['rating'],
    comment: json['comment'],
    patientName: json['patientName'],
    createdAt: _date(json['createdAt'])!,
  );
}

/// How a patient pays to start a consultation.
enum PaymentOption { card, wallet, points }
