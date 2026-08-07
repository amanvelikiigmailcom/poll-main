import 'package:equatable/equatable.dart';

/// Category of a poll question.
enum PollCategory { humor, normal, sympathy }

/// A single candidate option shown inside a poll question.
class PollOption extends Equatable {
  const PollOption({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.grade,
  });

  final String userId;
  final String name;
  final String? avatarUrl;

  /// School grade (8–12).
  final int grade;

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'avatarUrl': avatarUrl,
        'grade': grade,
      };

  PollOption copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
    int? grade,
  }) {
    return PollOption(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      grade: grade ?? this.grade,
    );
  }

  @override
  List<Object?> get props => [userId, name, avatarUrl, grade];
}

/// A single poll question with four candidate [options].
class Poll extends Equatable {
  const Poll({
    required this.id,
    required this.question,
    required this.emoji,
    required this.category,
    required this.options,
    this.isAnswered = false,
  });

  final String id;
  final String question;

  /// Decorative emoji accompanying the question.
  final String emoji;
  final PollCategory category;

  /// Always contains exactly 4 [PollOption] entries.
  final List<PollOption> options;

  /// Whether the current user has already voted on this poll.
  final bool isAnswered;

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      question: json['question'] as String,
      emoji: json['emoji'] as String? ?? '⭐',
      category: _categoryFromString(json['category'] as String? ?? 'normal'),
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      isAnswered: json['isAnswered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'emoji': emoji,
        'category': _categoryToString(category),
        'options': options.map((o) => o.toJson()).toList(),
        'isAnswered': isAnswered,
      };

  Poll copyWith({
    String? id,
    String? question,
    String? emoji,
    PollCategory? category,
    List<PollOption>? options,
    bool? isAnswered,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      options: options ?? this.options,
      isAnswered: isAnswered ?? this.isAnswered,
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
  List<Object?> get props =>
      [id, question, emoji, category, options, isAnswered];
}
