import 'package:equatable/equatable.dart';

/// An activity feed entry representing an anonymous vote event visible
/// to classmates.
///
/// The [voterId] is intentionally hidden from non-premium users; only the
/// [voterGrade] is exposed to give a hint about who voted.
class Activity extends Equatable {
  const Activity({
    required this.id,
    this.voterId,
    required this.voterGrade,
    required this.winnerName,
    required this.pollQuestion,
    required this.createdAt,
  });

  final String id;

  /// Null unless the current user has premium access to voter reveals.
  final String? voterId;

  /// Grade of the anonymous voter (8–12).
  final int voterGrade;

  /// Display name of the poll winner for this activity entry.
  final String winnerName;

  /// The poll question text shown in the feed.
  final String pollQuestion;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      voterId: json['voterId'] as String?,
      voterGrade: json['voterGrade'] as int? ?? 8,
      winnerName: json['winnerName'] as String,
      pollQuestion: json['pollQuestion'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'voterId': voterId,
        'voterGrade': voterGrade,
        'winnerName': winnerName,
        'pollQuestion': pollQuestion,
        'createdAt': createdAt.toIso8601String(),
      };

  Activity copyWith({
    String? id,
    String? voterId,
    int? voterGrade,
    String? winnerName,
    String? pollQuestion,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      voterId: voterId ?? this.voterId,
      voterGrade: voterGrade ?? this.voterGrade,
      winnerName: winnerName ?? this.winnerName,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, voterId, voterGrade, winnerName, pollQuestion, createdAt];
}
