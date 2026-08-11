import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/local_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('hasEnoughNames requires player + 3 friends', () async {
    final svc = LocalGameService.instance;
    expect(await svc.hasEnoughNames(), isFalse);

    await svc.savePlayerName('Аман');
    expect(await svc.hasEnoughNames(), isFalse);

    await svc.saveNames(['Али', 'Маша', 'Даня']);
    expect(await svc.hasEnoughNames(), isTrue);
  });

  test('generateRound always includes player among 4 options', () async {
    final svc = LocalGameService.instance;
    await svc.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша', 'Ира'],
    );

    final round = await svc.generateRound(languageCode: 'ru');
    expect(round.length, LocalGameService.roundLength);

    for (final q in round) {
      expect(q.optionNames.length, 4);
      expect(q.optionNames, contains('Аман'));
      // 3 others, no duplicate of player
      expect(
        q.optionNames.where((n) => n == 'Аман').length,
        1,
      );
    }

    // Categories order: 4 sympathy, 4 normal, 4 humor
    expect(round.take(4).every((q) => q.category == 'sympathy'), isTrue);
    expect(round.skip(4).take(4).every((q) => q.category == 'normal'), isTrue);
    expect(round.skip(8).take(4).every((q) => q.category == 'humor'), isTrue);
  });
}
