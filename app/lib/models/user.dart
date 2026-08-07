import 'package:equatable/equatable.dart';

/// Gender options for a user profile.
enum Gender { male, female, other }

/// Premium subscription tier.
enum PremiumType { none, pro, max }

/// Core user model representing a registered OISTER student.
class User extends Equatable {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    this.username,
    required this.gender,
    required this.age,
    required this.grade,
    this.gradeClass,
    this.schoolId,
    this.schoolName,
    this.cityId,
    this.cityName,
    this.avatarUrl,
    this.starsCount = 0,
    this.friendsCount = 0,
    this.votesReceived = 0,
    this.isPremium = false,
    this.premiumType = PremiumType.none,
    this.premiumExpiry,
    this.isVerified = false,
    this.referralCode,
    this.isProfileComplete = false,
    required this.createdAt,
  });

  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String? username;

  /// 'male', 'female', or 'other'.
  final Gender gender;

  /// Age must be between 14 and 19 inclusive.
  final int age;

  /// School grade: 8–12.
  final int grade;

  /// Optional class letter, e.g. 'A', 'B'.
  final String? gradeClass;
  final String? schoolId;
  final String? schoolName;
  final String? cityId;
  final String? cityName;
  final String? avatarUrl;
  final int starsCount;
  final int friendsCount;
  final int votesReceived;
  final bool isPremium;
  final PremiumType premiumType;
  final DateTime? premiumExpiry;
  final bool isVerified;
  final String? referralCode;
  final bool isProfileComplete;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get displayGrade =>
      gradeClass != null ? '$grade$gradeClass' : '$grade класс';

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String?,
      gender: _genderFromString(json['gender'] as String? ?? 'male'),
      age: json['age'] as int? ?? 14,
      grade: json['grade'] as int? ?? 8,
      gradeClass: json['gradeClass'] as String?,
      schoolId: json['schoolId'] as String?,
      schoolName: json['schoolName'] as String?,
      cityId: json['cityId'] as String?,
      cityName: json['cityName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      starsCount: json['starsCount'] as int? ?? 0,
      friendsCount: json['friendsCount'] as int? ?? 0,
      votesReceived: json['votesReceived'] as int? ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      premiumType:
          _premiumTypeFromString(json['premiumType'] as String?),
      premiumExpiry: json['premiumExpiry'] != null
          ? DateTime.tryParse(json['premiumExpiry'] as String)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      referralCode: json['referralCode'] as String?,
      isProfileComplete: json['isProfileComplete'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'gender': _genderToString(gender),
        'age': age,
        'grade': grade,
        'gradeClass': gradeClass,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'cityId': cityId,
        'cityName': cityName,
        'avatarUrl': avatarUrl,
        'starsCount': starsCount,
        'friendsCount': friendsCount,
        'votesReceived': votesReceived,
        'isPremium': isPremium,
        'premiumType': _premiumTypeToString(premiumType),
        'premiumExpiry': premiumExpiry?.toIso8601String(),
        'isVerified': isVerified,
        'referralCode': referralCode,
        'isProfileComplete': isProfileComplete,
        'createdAt': createdAt.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  User copyWith({
    String? id,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? username,
    Gender? gender,
    int? age,
    int? grade,
    String? gradeClass,
    String? schoolId,
    String? schoolName,
    String? cityId,
    String? cityName,
    String? avatarUrl,
    int? starsCount,
    int? friendsCount,
    int? votesReceived,
    bool? isPremium,
    PremiumType? premiumType,
    DateTime? premiumExpiry,
    bool? isVerified,
    String? referralCode,
    bool? isProfileComplete,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      grade: grade ?? this.grade,
      gradeClass: gradeClass ?? this.gradeClass,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      starsCount: starsCount ?? this.starsCount,
      friendsCount: friendsCount ?? this.friendsCount,
      votesReceived: votesReceived ?? this.votesReceived,
      isPremium: isPremium ?? this.isPremium,
      premiumType: premiumType ?? this.premiumType,
      premiumExpiry: premiumExpiry ?? this.premiumExpiry,
      isVerified: isVerified ?? this.isVerified,
      referralCode: referralCode ?? this.referralCode,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Gender _genderFromString(String value) {
    switch (value) {
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.male;
    }
  }

  static String _genderToString(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
      case Gender.other:
        return 'other';
    }
  }

  static PremiumType _premiumTypeFromString(String? value) {
    switch (value) {
      case 'pro':
        return PremiumType.pro;
      case 'max':
        return PremiumType.max;
      default:
        return PremiumType.none;
    }
  }

  static String _premiumTypeToString(PremiumType type) {
    switch (type) {
      case PremiumType.pro:
        return 'pro';
      case PremiumType.max:
        return 'max';
      case PremiumType.none:
        return 'none';
    }
  }

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        firstName,
        lastName,
        username,
        gender,
        age,
        grade,
        gradeClass,
        schoolId,
        schoolName,
        cityId,
        cityName,
        avatarUrl,
        starsCount,
        friendsCount,
        votesReceived,
        isPremium,
        premiumType,
        premiumExpiry,
        isVerified,
        referralCode,
        isProfileComplete,
        createdAt,
      ];
}
