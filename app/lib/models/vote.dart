import 'package:equatable/equatable.dart';

import 'quiz.dart';

/// Records a completed vote cast by the current user.
class Vote extends Equatable {
  const Vote({
    required this.id,
    required this.quizId,
    required this.winnerId,
    required this.winnerName,
    this.winnerAvatar,
    required this.winnerGrade,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String quizId;
  final String winnerId;
  final String winnerName;
  final String? winnerAvatar;

  /// School grade of the winner (8–12).
  final int winnerGrade;
  final QuizCategory category;
  final DateTime createdAt;

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] as String,
      quizId: json['quizId'] as String,
      winnerId: json['winnerId'] as String,
      winnerName: json['winnerName'] as String,
      winnerAvatar: json['winnerAvatar'] as String?,
      winnerGrade: json['winnerGrade'] as int? ?? 8,
      category: _categoryFromString(json['category'] as String? ?? 'normal'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quizId': quizId,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'winnerAvatar': winnerAvatar,
        'winnerGrade': winnerGrade,
        'category': _categoryToString(category),
        'createdAt': createdAt.toIso8601String(),
      };

  Vote copyWith({
    String? id,
    String? quizId,
    String? winnerId,
    String? winnerName,
    String? winnerAvatar,
    int? winnerGrade,
    QuizCategory? category,
    DateTime? createdAt,
  }) {
    return Vote(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      winnerAvatar: winnerAvatar ?? this.winnerAvatar,
      winnerGrade: winnerGrade ?? this.winnerGrade,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static QuizCategory _categoryFromString(String value) {
    switch (value) {
      case 'humor':
        return QuizCategory.humor;
      case 'sympathy':
        return QuizCategory.sympathy;
      default:
        return QuizCategory.normal;
    }
  }

  static String _categoryToString(QuizCategory category) {
    switch (category) {
      case QuizCategory.humor:
        return 'humor';
      case QuizCategory.sympathy:
        return 'sympathy';
      case QuizCategory.normal:
        return 'normal';
    }
  }

  @override
  List<Object?> get props => [
        id,
        quizId,
        winnerId,
        winnerName,
        winnerAvatar,
        winnerGrade,
        category,
        createdAt,
      ];
}
