import 'package:equatable/equatable.dart';

/// A city that students can select during registration.
class City extends Equatable {
  const City({
    required this.id,
    required this.name,
    required this.region,
  });

  final String id;
  final String name;

  /// Administrative region or state the city belongs to.
  final String region;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
      };

  City copyWith({
    String? id,
    String? name,
    String? region,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
    );
  }

  @override
  List<Object?> get props => [id, name, region];
}
