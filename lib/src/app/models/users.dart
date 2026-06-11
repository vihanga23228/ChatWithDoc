class PatientUser {
  final String name;
  final String email;
  final String password;
  final String healthHistory;
  final String drugAllergies;

  PatientUser({
    required this.name,
    required this.email,
    required this.password,
    required this.healthHistory,
    required this.drugAllergies,
  });
}

class ConsultantUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String slmcNumber;
  final String specialization;
  final String hospital;
  final int experienceYears;
  final String degree;
  final String university;
  final int graduationYear;
  final double consultationFee;
  final String about;
  final List<String> languages;
  final String status;
  final double walletBalance;
  final String? avatarUrl;
  final double rating;
  final int totalReviews;

  ConsultantUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.slmcNumber,
    required this.specialization,
    required this.hospital,
    required this.experienceYears,
    required this.degree,
    required this.university,
    required this.graduationYear,
    required this.consultationFee,
    required this.about,
    required this.languages,
    required this.status,
    required this.walletBalance,
    this.avatarUrl,
    this.rating = 4.8,
    this.totalReviews = 120,
  });
}
