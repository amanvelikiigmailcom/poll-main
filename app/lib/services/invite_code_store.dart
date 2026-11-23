import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Pending attribution only; never reads the clipboard automatically.
abstract final class InviteCodeStore {
  static final changes = ValueNotifier<int>(0);
  static final pattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$');
  static const _code = 'pending_invitation_code_v1';
  static const _source = 'pending_invitation_source_v1';
  static const _seen = 'invitation_screen_seen_v1';
  static const _accepted = 'invitation_code_accepted_v1';
  static const _attention = 'invitation_code_attention_v1';
  static Future<bool> needsAttention() async =>
      (await SharedPreferences.getInstance()).getBool(_attention) ?? false;
  static Future<void> requireAttention() async =>
      (await SharedPreferences.getInstance()).setBool(_attention, true);
  static String normalize(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'api.flyprox.com' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'i') {
      return uri.pathSegments.last.toUpperCase();
    }
    return raw.trim().toUpperCase();
  }

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_seen) ?? false;
  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_seen, true);
  static Future<String?> code() async =>
      (await SharedPreferences.getInstance()).getString(_code);
  static Future<String> source() async =>
      (await SharedPreferences.getInstance()).getString(_source) ?? 'typed';
  static Future<bool> accepted() async =>
      (await SharedPreferences.getInstance()).getBool(_accepted) ?? false;
  static Future<void> accept() async =>
      (await SharedPreferences.getInstance()).setBool(_accepted, true);
  static Future<void> save(String raw, String source) async {
    final value = normalize(raw);
    if (!pattern.hasMatch(value)) {
      throw const FormatException('Enter a valid six-character code');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_code, value);
    await prefs.setString(_source, source);
    await prefs.setBool(_accepted, false);
    await prefs.remove(_attention);
    changes.value++;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_code);
    await prefs.remove(_source);
    await prefs.remove(_accepted);
    await prefs.remove(_attention);
    changes.value++;
  }
}
