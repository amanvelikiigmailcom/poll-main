import 'dart:convert';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/question_bank_service.dart';

Map<String, dynamic> question(int i) => {
  'id': 'server_$i',
  'textEn': 'Server question $i',
  'textRu': 'Вопрос $i',
  'emoji': '⭐',
  'category': ['normal', 'humor', 'sympathy'][i % 3],
  'isIntro': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'downloads all 10000 questions and restores the whole bank offline',
    () async {
      final service = QuestionBankService();
      final rows = List.generate(10000, question);
      var calls = 0;
      await service.refresh(
        fetchPage: (cursor) async {
          calls++;
          final start = int.parse(cursor ?? '0');
          final end = (start + 250).clamp(0, rows.length);
          return {
            'questions': rows.sublist(start, end),
            'nextCursor': end < rows.length ? '$end' : null,
          };
        },
      );
      expect(service.seeds(intro: false).length, 10000);
      expect(calls, 40);
      final restored = QuestionBankService();
      await restored.load();
      expect(restored.seeds(intro: false).last.id, 'server_9999');
    },
  );

  test('guest rounds and resume use server text, without an account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      QuestionBankService.cacheKey,
      jsonEncode(List.generate(30, question)),
    );
    await QuestionBankService.instance.load();
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
      playerName: 'Me',
      friends: ['A', 'B', 'C', 'D'],
    );
    final round = await game.generateRound(languageCode: 'en');
    expect(round.length, 12);
    expect(
      round.every((q) => q.question.startsWith('Server question')),
      isTrue,
    );
    for (final q in round) {
      expect(q.optionNames, unorderedEquals(['A', 'B', 'C', 'D']));
    }
    final restored = await game.restoreRound(
      ids: round.map((q) => q.id).toList(),
      languageCode: 'en',
    );
    for (final q in restored!) {
      expect(q.optionNames, unorderedEquals(['A', 'B', 'C', 'D']));
    }
    expect(
      restored.map((q) => q.question).toList(),
      round.map((q) => q.question).toList(),
    );
  });

  test('partial failure preserves last complete bank', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      QuestionBankService.cacheKey,
      jsonEncode(List.generate(12, question)),
    );
    final service = QuestionBankService();
    await service.load();
    await service.refresh(
      fetchPage: (cursor) async {
        if (cursor != null) throw Exception('offline halfway');
        return {
          'questions': [question(100)],
          'nextCursor': 'next',
        };
      },
    );
    expect(service.seeds(intro: false).length, 12);
    final restored = QuestionBankService();
    await restored.load();
    expect(restored.seeds(intro: false).first.id, 'server_0');
  });
}
