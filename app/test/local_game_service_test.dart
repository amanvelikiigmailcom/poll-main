import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/data/intro_questions.dart';
import 'package:flyprox_app/services/local_game_service.dart';

Future<void> seedPlayer() async {
  await LocalGameService.instance.savePlayerAndFriends(
    username: 'aman_07',
    playerName: 'Аман',
    friends: ['Али', 'Маша', 'Даня', 'Саша', 'Ира'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('validateUsername enforces latin rules', () {
    expect(LocalGameService.validateUsername(''), isNotNull);
    expect(LocalGameService.validateUsername('ab'), isNotNull);
    expect(LocalGameService.validateUsername('аман'), isNotNull);
    expect(LocalGameService.validateUsername('aman_07'), isNull);
  });

  test(
    'hasEnoughNames requires player + 4 participants without a username',
    () async {
      final svc = LocalGameService.instance;
      expect(await svc.hasEnoughNames(), isFalse);

      await svc.savePlayerName('Аман');
      expect(await svc.hasEnoughNames(), isFalse);

      await svc.saveNames(['Али', 'Маша', 'Даня']);
      expect(await svc.hasEnoughNames(), isFalse);

      await svc.saveNames(['Али', 'Маша', 'Даня', 'Саша']);
      expect(await svc.hasEnoughNames(), isTrue);
      expect(await svc.getUsername(), isNull);
    },
  );

  test('automatic profile name persists and migrates old defaults', () async {
    final svc = LocalGameService.instance;
    final name = await svc.ensurePlayerName();
    expect(name, matches(RegExp(r'^user[0-9]{6}$')));
    expect(await svc.ensurePlayerName(), name);
    expect(await svc.getPlayerName(), name);
    for (final legacy in ['Michael', 'You']) {
      await svc.savePlayerName(legacy);
      final migrated = await svc.getPlayerName();
      expect(migrated, matches(RegExp(r'^user[0-9]{6}$')));
      expect(await svc.getPlayerName(), migrated);
    }
    await svc.saveUsername('Michael');
    await svc.savePlayerName('Michael');
    expect(await svc.getPlayerName(), 'Michael');
    await svc.savePlayerName('Custom name');
    expect(await svc.ensurePlayerName(), 'Custom name');
  });

  test('intro pool holds exactly 24 neutral questions in fixed order', () {
    expect(introQuestionSeeds.length, 2 * LocalGameService.roundLength);
    final ids = introQuestionSeeds.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    for (var i = 0; i < ids.length; i++) {
      expect(ids[i], 'intro${i + 1}');
    }
    for (final s in introQuestionSeeds) {
      expect(s.category, isNot('sympathy'));
      expect(s.textRu.trim(), isNotEmpty);
      expect(s.textEn.trim(), isNotEmpty);
      expect(s.emoji.trim(), isNotEmpty);
    }
  });

  test(
    'first two rounds play the neutral intro in order, third uses the pool',
    () async {
      final svc = LocalGameService.instance;
      await seedPlayer();

      final round1 = await svc.generateRound(languageCode: 'ru');
      expect(round1.length, LocalGameService.roundLength);
      expect(
        round1.map((q) => q.id).toList(),
        List.generate(12, (i) => 'intro${i + 1}'),
      );
      for (final q in round1) {
        expect(q.category, isNot('sympathy'));
        expect(q.optionNames.length, 4);
        expect(q.optionNames, isNot(contains('Аман')));
        expect(q.optionNames.toSet(), hasLength(4));
        expect([
          'Али',
          'Маша',
          'Даня',
          'Саша',
          'Ира',
        ], containsAll(q.optionNames));
      }
      await svc.completeRound();

      final round2 = await svc.generateRound(languageCode: 'ru');
      expect(
        round2.map((q) => q.id).toList(),
        List.generate(12, (i) => 'intro${i + 13}'),
      );
      await svc.completeRound();

      // Round 3+: previous behavior (4 sympathy, 4 normal, 4 humor).
      final round3 = await svc.generateRound(languageCode: 'ru');
      expect(round3.length, LocalGameService.roundLength);
      expect(round3.take(4).every((q) => q.category == 'sympathy'), isTrue);
      expect(
        round3.skip(4).take(4).every((q) => q.category == 'normal'),
        isTrue,
      );
      expect(
        round3.skip(8).take(4).every((q) => q.category == 'humor'),
        isTrue,
      );
      for (final q in round3) {
        expect(q.optionNames.length, 4);
        expect(q.optionNames, isNot(contains('Аман')));
        expect(q.optionNames.toSet(), hasLength(4));
        expect([
          'Али',
          'Маша',
          'Даня',
          'Саша',
          'Ира',
        ], containsAll(q.optionNames));
      }
    },
  );

  test('completed rounds persist across restarts until reset', () async {
    final svc = LocalGameService.instance;
    await seedPlayer();
    expect(await svc.getCompletedRounds(), 0);

    await svc.generateRound(languageCode: 'en');
    await svc.completeRound();
    expect(await svc.getCompletedRounds(), 1);

    // "Restart": same persisted prefs, next round continues the intro.
    final next = await svc.generateRound(languageCode: 'en');
    expect(next.first.id, 'intro13');

    await svc.clearAll();
    expect(await svc.getCompletedRounds(), 0);
    expect(await svc.loadRoundProgress(), isNull);
    expect(await svc.generateRound(languageCode: 'en'), isEmpty);

    await seedPlayer();
    final round1 = await svc.generateRound(languageCode: 'en');
    expect(round1.first.id, 'intro1');
  });

  test(
    'round progress round-trips and restore rebuilds the same round',
    () async {
      final svc = LocalGameService.instance;
      await seedPlayer();

      final round1 = await svc.generateRound(languageCode: 'en');
      final ids = round1.map((q) => q.id).toList();
      await svc.saveRoundProgress(round: 0, questionIndex: 5, questionIds: ids);

      final saved = await svc.loadRoundProgress();
      expect(saved, isNotNull);
      expect(saved!.round, 0);
      expect(saved.questionIndex, 5);
      expect(saved.questionIds, ids);

      final restored = await svc.restoreRound(ids: ids, languageCode: 'en');
      expect(restored, isNotNull);
      for (final q in restored!) {
        expect(q.optionNames, isNot(contains('Аман')));
        expect(q.optionNames, hasLength(4));
      }
      expect(restored.map((q) => q.id).toList(), ids);
      expect(
        restored.map((q) => q.question).toList(),
        round1.map((q) => q.question).toList(),
      );

      expect(await svc.restoreRound(ids: ['unknown-id']), isNull);

      await svc.completeRound(); // clears progress
      expect(await svc.loadRoundProgress(), isNull);
    },
  );
}
