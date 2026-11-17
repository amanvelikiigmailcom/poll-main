import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/invite_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Instagram opens the recipient picker with Hi! and no website', () async {
    final launched = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canLaunch') return true;
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return true;
      }
      throw StateError('Unexpected method: ${call.method}');
    });

    expect(await InviteShareService.instance.shareInstagram(), isTrue);
    expect(launched, ['instagram://sharesheet?text=Hi%21']);
    expect(Uri.parse(launched.single).queryParameters, {'text': 'Hi!'});
  });

  test('Instagram launch failure returns false without opening a website',
      () async {
    final launched = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canLaunch') return false;
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return false;
      }
      throw StateError('Unexpected method: ${call.method}');
    });

    expect(await InviteShareService.instance.shareInstagram(), isFalse);
    expect(launched, ['instagram://sharesheet?text=Hi%21']);
  });
}
