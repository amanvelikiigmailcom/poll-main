import 'package:flutter/services.dart';

abstract final class AppInfoService {
  static const channel = MethodChannel('flyprox/app_info');
  static Future<String> versionLabel() async {
    try {
      final info = await channel.invokeMapMethod<String, String>('getVersion');
      final version = info?['version'] ?? '';
      final number = info?['buildNumber'] ?? '';
      if (version.isNotEmpty && number.isNotEmpty) {
        return '$version (build $number)';
      }
    } catch (_) {
      /* Web/tests/unsupported platform: never invent a build. */
    }
    return 'Version unavailable';
  }
}
