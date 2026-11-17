import 'package:equatable/equatable.dart';

/// Category of a quiz question.
enum QuizCategory { humor, normal, sympathy }

/// A single candidate option shown inside a quiz question.
class QuizOption extends Equatable {
  const QuizOption({
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

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
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

  QuizOption copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
    int? grade,
  }) {
    return QuizOption(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      grade: grade ?? this.grade,
    );
  }

  @override
  List<Object?> get props => [userId, name, avatarUrl, grade];
}

/// A single quiz question with four candidate [options].
class Quiz extends Equatable {
  const Quiz({
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
  final QuizCategory category;

  /// Always contains exactly 4 [QuizOption] entries.
  final List<QuizOption> options;

  /// Whether the current user has already voted on this quiz.
  final bool isAnswered;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      question: json['question'] as String,
      emoji: json['emoji'] as String? ?? '⭐',
      category: _categoryFromString(json['category'] as String? ?? 'normal'),
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
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

  Quiz copyWith({
    String? id,
    String? question,
    String? emoji,
    QuizCategory? category,
    List<QuizOption>? options,
    bool? isAnswered,
  }) {
    return Quiz(
      id: id ?? this.id,
      question: question ?? this.question,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      options: options ?? this.options,
      isAnswered: isAnswered ?? this.isAnswered,
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
  List<Object?> get props =>
      [id, question, emoji, category, options, isAnswered];
}
