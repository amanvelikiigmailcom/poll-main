import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/local_game_service.dart';

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

  test('hasEnoughNames requires username + player + 3 friends', () async {
    final svc = LocalGameService.instance;
    expect(await svc.hasEnoughNames(), isFalse);

    await svc.saveUsername('aman_07');
    expect(await svc.hasEnoughNames(), isFalse);

    await svc.savePlayerName('Аман');
    expect(await svc.hasEnoughNames(), isFalse);

    await svc.saveNames(['Али', 'Маша', 'Даня']);
    expect(await svc.hasEnoughNames(), isTrue);
  });

  test('generateRound always includes player among 4 options', () async {
    final svc = LocalGameService.instance;
    await svc.savePlayerAndFriends(
      username: 'aman_07',
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня', 'Саша', 'Ира'],
    );

    final round = await svc.generateRound(languageCode: 'ru');
    expect(round.length, LocalGameService.roundLength);

    for (final q in round) {
      expect(q.optionNames.length, 4);
      expect(q.optionNames, contains('Аман'));
      expect(q.optionNames.where((n) => n == 'Аман').length, 1);
    }

    expect(round.take(4).every((q) => q.category == 'sympathy'), isTrue);
    expect(round.skip(4).take(4).every((q) => q.category == 'normal'), isTrue);
    expect(round.skip(8).take(4).every((q) => q.category == 'humor'), isTrue);
  });
}
