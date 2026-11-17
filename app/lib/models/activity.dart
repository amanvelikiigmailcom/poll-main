import 'package:equatable/equatable.dart';

/// An activity feed entry representing a vote event visible
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
    required this.quizQuestion,
    required this.createdAt,
  });

  final String id;

  /// Null unless the current user has premium access to voter reveals.
  final String? voterId;

  /// Grade of the voter (8–12).
  final int voterGrade;

  /// Display name of the quiz winner for this activity entry.
  final String winnerName;

  /// The quiz question text shown in the feed.
  final String quizQuestion;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      voterId: json['voterId'] as String?,
      voterGrade: json['voterGrade'] as int? ?? 8,
      winnerName: json['winnerName'] as String,
      quizQuestion: json['quizQuestion'] as String,
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
        'quizQuestion': quizQuestion,
        'createdAt': createdAt.toIso8601String(),
      };

  Activity copyWith({
    String? id,
    String? voterId,
    int? voterGrade,
    String? winnerName,
    String? quizQuestion,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      voterId: voterId ?? this.voterId,
      voterGrade: voterGrade ?? this.voterGrade,
      winnerName: winnerName ?? this.winnerName,
      quizQuestion: quizQuestion ?? this.quizQuestion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, voterId, voterGrade, winnerName, quizQuestion, createdAt];
}
