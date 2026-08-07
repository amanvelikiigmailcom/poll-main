import 'package:equatable/equatable.dart';

/// A school that students can register under.
class School extends Equatable {
  const School({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    this.studentsCount = 0,
  });

  final String id;
  final String name;
  final String cityId;
  final String cityName;

  /// Number of registered students at this school.
  final int studentsCount;

  /// Whether enough students are registered to start voting rounds
  /// (threshold is 5).
  bool get hasEnoughStudents => studentsCount >= 5;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as String,
      name: json['name'] as String,
      cityId: json['cityId'] as String,
      cityName: json['cityName'] as String,
      studentsCount: json['studentsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cityId': cityId,
        'cityName': cityName,
        'studentsCount': studentsCount,
      };

  School copyWith({
    String? id,
    String? name,
    String? cityId,
    String? cityName,
    int? studentsCount,
  }) {
    return School(
      id: id ?? this.id,
      name: name ?? this.name,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      studentsCount: studentsCount ?? this.studentsCount,
    );
  }

  @override
  List<Object?> get props => [id, name, cityId, cityName, studentsCount];
}
