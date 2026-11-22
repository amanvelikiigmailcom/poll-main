import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/app_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flyprox/app_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('reads actual installed bundle version and build', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getVersion');
      return {'version': '1.0.2', 'buildNumber': '42'};
    });
    expect(await AppInfoService.versionLabel(), '1.0.2 (build 42)');
  });
  test('missing platform metadata never invents an old build', () async {
    expect(await AppInfoService.versionLabel(), 'Version unavailable');
  });
}
