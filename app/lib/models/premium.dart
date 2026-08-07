import 'package:equatable/equatable.dart';

/// Premium subscription tier.
enum SubscriptionType { pro, max }

/// Status of a subscription.
enum SubscriptionStatus { active, expired, cancelled }

/// Active (or historic) premium subscription record for a user.
class Subscription extends Equatable {
  const Subscription({
    required this.id,
    required this.type,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final SubscriptionType type;
  final SubscriptionStatus status;
  final DateTime expiresAt;

  bool get isActive => status == SubscriptionStatus.active &&
      expiresAt.isAfter(DateTime.now());

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      type: _typeFromString(json['type'] as String? ?? 'pro'),
      status: _statusFromString(json['status'] as String? ?? 'active'),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': _typeToString(type),
        'status': _statusToString(status),
        'expiresAt': expiresAt.toIso8601String(),
      };

  Subscription copyWith({
    String? id,
    SubscriptionType? type,
    SubscriptionStatus? status,
    DateTime? expiresAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  static SubscriptionType _typeFromString(String value) {
    switch (value) {
      case 'max':
        return SubscriptionType.max;
      default:
        return SubscriptionType.pro;
    }
  }

  static String _typeToString(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.max:
        return 'max';
      case SubscriptionType.pro:
        return 'pro';
    }
  }

  static SubscriptionStatus _statusFromString(String value) {
    switch (value) {
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.active;
    }
  }

  static String _statusToString(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.cancelled:
        return 'cancelled';
      case SubscriptionStatus.active:
        return 'active';
    }
  }

  @override
  List<Object?> get props => [id, type, status, expiresAt];
}

/// Defines what reveal features are available to a premium subscriber.
///
/// - [Pro] gets a limited number of full-name reveals and first-letter hints.
/// - [Max] has unlimited access (represented by -1 in each field).
class PremiumLimits extends Equatable {
  const PremiumLimits({
    required this.fullNameReveals,
    required this.firstLetterReveals,
  });

  /// Total full-name voter reveals allowed per billing period.
  /// -1 means unlimited (Max plan).
  final int fullNameReveals;

  /// Total first-letter reveals allowed per billing period.
  /// -1 means unlimited (Max plan).
  final int firstLetterReveals;

  bool get hasUnlimitedFullName => fullNameReveals == -1;
  bool get hasUnlimitedFirstLetter => firstLetterReveals == -1;

  /// Preset limits for the Pro plan ($7.99/week).
  factory PremiumLimits.pro() {
    return const PremiumLimits(
      fullNameReveals: 3,
      firstLetterReveals: 10,
    );
  }

  /// Preset limits for the Max plan ($27.99/month) — fully unlimited.
  factory PremiumLimits.max() {
    return const PremiumLimits(
      fullNameReveals: -1,
      firstLetterReveals: -1,
    );
  }

  factory PremiumLimits.fromJson(Map<String, dynamic> json) {
    return PremiumLimits(
      fullNameReveals: json['fullNameReveals'] as int? ?? 0,
      firstLetterReveals: json['firstLetterReveals'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullNameReveals': fullNameReveals,
        'firstLetterReveals': firstLetterReveals,
      };

  PremiumLimits copyWith({
    int? fullNameReveals,
    int? firstLetterReveals,
  }) {
    return PremiumLimits(
      fullNameReveals: fullNameReveals ?? this.fullNameReveals,
      firstLetterReveals: firstLetterReveals ?? this.firstLetterReveals,
    );
  }

  @override
  List<Object?> get props => [fullNameReveals, firstLetterReveals];
}
