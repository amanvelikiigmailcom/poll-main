import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/invite_code_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'canonical HTTPS links and manual codes normalize to one code',
    () async {
      for (final raw in [
        ' abc234 ',
        'https://api.flyprox.com/i/abc234',
        'https://api.flyprox.com/i/ABC234?source=message#open',
      ]) {
        await InviteCodeStore.save(raw, 'link');
        expect(await InviteCodeStore.code(), 'ABC234');
        expect(await InviteCodeStore.accepted(), isFalse);
      }
    },
  );

  for (final raw in [
    'https://evil.example/i/ABC234',
    'https://api.flyprox.com.evil.example/i/ABC234',
    'https://evil.example/?next=https://api.flyprox.com/i/ABC234',
    'http://api.flyprox.com/i/ABC234',
    'https://api.flyprox.com/other/ABC234',
    'https://api.flyprox.com/i/ABC234/extra',
    'O0I123',
    '',
    'ABC2345',
  ]) {
    test('invalid input preserves the pending accepted code: $raw', () async {
      await InviteCodeStore.save('DEF678', 'typed');
      await InviteCodeStore.accept();
      await expectLater(
        InviteCodeStore.save(raw, 'link'),
        throwsFormatException,
      );
      expect(await InviteCodeStore.code(), 'DEF678');
      expect(await InviteCodeStore.source(), 'typed');
      expect(await InviteCodeStore.accepted(), isTrue);
    });
  }
}
