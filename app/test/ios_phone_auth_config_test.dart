import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS registers the Firebase phone-auth reCAPTCHA callback', () {
    final firebase = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final appId = RegExp(
      r'<key>GOOGLE_APP_ID</key>\s*<string>([^<]+)</string>',
    ).firstMatch(firebase)!.group(1)!;
    final expected = 'app-${appId.replaceAll(':', '-')}';
    final schemes = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>([\s\S]*?)</array>',
    ).allMatches(info).map((m) => m.group(1)!).join();
    expect(schemes, contains('<string>$expected</string>'),
        reason: 'Firebase phone auth cannot return from reCAPTCHA without this URL scheme');
  });
}
