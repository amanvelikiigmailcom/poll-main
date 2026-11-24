import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';

class QuizPreferenceOption {
  const QuizPreferenceOption(this.value, this.label);
  final String value;
  final String label;
}

class QuizPreferencesData {
  const QuizPreferencesData(this.genderFilter, this.options);
  final String genderFilter;
  final List<QuizPreferenceOption> options;

  factory QuizPreferencesData.fromJson(Map<String, dynamic> json) {
    const expected = {'all', 'female', 'male', 'nonbinary'};
    final raw = json['options'];
    if (raw is! List ||
        raw.length != expected.length ||
        json['prioritizeGraduationYear'] != true ||
        json['appliesTo'] != 'next_round') {
      throw const ApiException(
        'Incomplete quiz preferences. Please try again.',
      );
    }
    final options = <QuizPreferenceOption>[];
    for (final item in raw) {
      if (item is! Map ||
          !expected.contains(item['value']) ||
          item['label'] is! String ||
          (item['label'] as String).trim().isEmpty) {
        throw const ApiException(
          'Incomplete quiz preferences. Please try again.',
        );
      }
      options.add(
        QuizPreferenceOption(item['value'] as String, item['label'] as String),
      );
    }
    if (options.map((option) => option.value).toSet().length !=
            expected.length ||
        !expected.contains(json['genderFilter'])) {
      throw const ApiException(
        'Incomplete quiz preferences. Please try again.',
      );
    }
    return QuizPreferencesData(json['genderFilter'] as String, options);
  }
}

/// No device fallback: every value belongs to the opening authenticated session.
class QuizPreferencesService {
  QuizPreferencesService(this.api, this.storage);
  final ApiService api;
  final StorageService storage;

  Future<QuizPreferencesData> load(String token) => _request(token);
  Future<QuizPreferencesData> save(String token, String value) =>
      _request(token, value: value);

  Future<QuizPreferencesData> _request(String token, {String? value}) async {
    Future<void> checkSession() async {
      if (token.isEmpty || token != await storage.getToken()) {
        throw const ApiException('Account changed. Reopen Quiz preferences.');
      }
    }

    await checkSession();
    try {
      final response = await api.dio.request<dynamic>(
        '/api/quiz-preferences',
        data: value == null ? null : {'genderFilter': value},
        options: Options(
          method: value == null ? 'GET' : 'PUT',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      await checkSession();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException(
          'Incomplete quiz preferences. Please try again.',
        );
      }
      return QuizPreferencesData.fromJson(data);
    } on DioException catch (error) {
      await checkSession();
      final body = error.response?.data;
      throw ApiException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Couldn’t connect. Please try again.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
