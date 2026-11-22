import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/quiz_questions.dart';

/// Server is the editable source of truth; the last complete bank works offline.
/// Never replace a good cache with a partially downloaded bank.
class QuestionBankService {
  QuestionBankService();
  static final instance = QuestionBankService();
  static const cacheKey = 'server_question_bank_v1';
  List<QuizQuestionSeed> _main = const [];
  List<QuizQuestionSeed> _intro = const [];
  Future<void>? _refreshing;

  List<QuizQuestionSeed> seeds({required bool intro}) => intro ? _intro : _main;

  void _install(List<Map<String, dynamic>> rows) {
    List<QuizQuestionSeed> bank(bool intro) => List.unmodifiable(
      rows
          .where((r) => r['isIntro'] == intro)
          .map(
            (r) => QuizQuestionSeed(
              id: r['id'],
              textEn: r['textEn'],
              textRu: r['textRu'],
              category: r['category'],
              emoji: r['emoji'] ?? '',
            ),
          ),
    );
    _main = bank(false);
    _intro = bank(true);
  }

  bool _valid(Map<String, dynamic> r) =>
      r['id'] is String &&
      (r['id'] as String).isNotEmpty &&
      r['textEn'] is String &&
      (r['textEn'] as String).isNotEmpty &&
      r['textRu'] is String &&
      r['isIntro'] is bool &&
      const ['sympathy', 'normal', 'humor'].contains(r['category']) &&
      (r['emoji'] == null || r['emoji'] is String);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return;
      final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (rows.isNotEmpty && rows.every(_valid)) _install(rows);
    } catch (_) {
      /* Corrupt cache: keep bundled offline fallback. */
    }
  }

  /// Anonymous request: no account token or contact data in public bank requests.
  Future<void> refresh({
    Future<Map<String, dynamic>> Function(String? cursor)? fetchPage,
  }) {
    return _refreshing ??= _download(
      fetchPage,
    ).whenComplete(() => _refreshing = null);
  }

  Future<void> _download(
    Future<Map<String, dynamic>> Function(String?)? fetch,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.flyprox.com',
        ),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    try {
      final rows = <Map<String, dynamic>>[];
      final ids = <String>{};
      final cursors = <String>{};
      String? cursor;
      do {
        final body = fetch != null
            ? await fetch(cursor)
            : (await dio.get<Map<String, dynamic>>(
                '/api/questions',
                queryParameters: {
                  'limit': 250,
                  if (cursor != null) 'cursor': cursor,
                },
              )).data!;
        for (final row
            in (body['questions'] as List).cast<Map<String, dynamic>>()) {
          if (!_valid(row) || !ids.add(row['id'] as String)) {
            throw const FormatException('Invalid question bank page');
          }
          rows.add(row);
        }
        cursor = body['nextCursor'] as String?;
        if (cursor != null && !cursors.add(cursor)) {
          throw const FormatException('Question cursor did not advance');
        }
      } while (cursor != null);
      // A valid bank must be able to generate a full balanced round.
      if (const ['sympathy', 'normal', 'humor'].any(
        (c) =>
            rows
                .where((r) => r['isIntro'] == false && r['category'] == c)
                .length <
            4,
      )) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(rows));
      _install(rows);
    } catch (_) {
      /* Offline/partial response: previous complete bank survives. */
    } finally {
      dio.close(force: true);
    }
  }
}
