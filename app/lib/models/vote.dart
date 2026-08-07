import 'package:equatable/equatable.dart';

import 'poll.dart';

/// Records a completed vote cast by the current user.
class Vote extends Equatable {
  const Vote({
    required this.id,
    required this.pollId,
    required this.winnerId,
    required this.winnerName,
    this.winnerAvatar,
    required this.winnerGrade,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String pollId;
  final String winnerId;
  final String winnerName;
  final String? winnerAvatar;

  /// School grade of the winner (8–12).
  final int winnerGrade;
  final PollCategory category;
  final DateTime createdAt;

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] as String,
      pollId: json['pollId'] as String,
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
        'pollId': pollId,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'winnerAvatar': winnerAvatar,
        'winnerGrade': winnerGrade,
        'category': _categoryToString(category),
        'createdAt': createdAt.toIso8601String(),
      };

  Vote copyWith({
    String? id,
    String? pollId,
    String? winnerId,
    String? winnerName,
    String? winnerAvatar,
    int? winnerGrade,
    PollCategory? category,
    DateTime? createdAt,
  }) {
    return Vote(
      id: id ?? this.id,
      pollId: pollId ?? this.pollId,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      winnerAvatar: winnerAvatar ?? this.winnerAvatar,
      winnerGrade: winnerGrade ?? this.winnerGrade,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static PollCategory _categoryFromString(String value) {
    switch (value) {
      case 'humor':
        return PollCategory.humor;
      case 'sympathy':
        return PollCategory.sympathy;
      default:
        return PollCategory.normal;
    }
  }

  static String _categoryToString(PollCategory category) {
    switch (category) {
      case PollCategory.humor:
        return 'humor';
      case PollCategory.sympathy:
        return 'sympathy';
      case PollCategory.normal:
        return 'normal';
    }
  }

  @override
  List<Object?> get props => [
        id,
        pollId,
        winnerId,
        winnerName,
        winnerAvatar,
        winnerGrade,
        category,
        createdAt,
      ];
}
