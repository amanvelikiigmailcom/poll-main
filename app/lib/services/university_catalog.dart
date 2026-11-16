import 'dart:convert';
import 'package:flutter/services.dart';

class UsUniversity {
  const UsUniversity(
      {required this.id,
      required this.name,
      required this.city,
      required this.state,
      required this.aliases});

  final String id;
  final String name;
  final String city;
  final String state;
  final String aliases;

  factory UsUniversity.fromJson(Map<String, dynamic> json) => UsUniversity(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        state: json['state'] as String,
        aliases: json['aliases'] as String? ?? '',
      );

  bool matches(String query) {
    final text = '$name $city $state $aliases'.toLowerCase();
    return query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}

class UniversityCatalog {
  static List<UsUniversity>? _loaded;
  static Future<List<UsUniversity>>? _cached;

  static Future<List<UsUniversity>> load() {
    final loaded = _loaded;
    if (loaded != null) return Future.value(loaded);
    return _cached ??= _load();
  }

  static Future<List<UsUniversity>> _load() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/us_universities.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final institutions = List<UsUniversity>.unmodifiable((data['institutions']
              as List)
          .map((row) => UsUniversity.fromJson(row as Map<String, dynamic>)));
      _loaded = institutions;
      return institutions;
    } catch (_) {
      _cached = null;
      rethrow;
    }
  }
}
