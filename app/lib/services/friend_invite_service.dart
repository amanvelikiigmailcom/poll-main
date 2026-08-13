import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_game_service.dart';

/// Optional Hidavo logins for locally-added friend names.
/// Display names are vote-card labels only; these logins are not auto-join.
class FriendInviteService {
  FriendInviteService._();
  static final FriendInviteService instance = FriendInviteService._();

  static const _key = 'friend_invite_logins';

  Future<Map<String, String>> getLogins() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Returns a stored handle if [raw] matches the local username rules.
  static String? normalizeLogin(String raw) {
    var handle = raw.trim();
    if (handle.startsWith('@')) handle = handle.substring(1);
    handle = handle.trim();
    if (handle.length < LocalGameService.minUsernameLength) return null;
    if (!LocalGameService.usernamePattern.hasMatch(handle)) return null;
    return handle;
  }

  Future<bool> saveLoginForFriend(String displayName, String rawLogin) async {
    final name = displayName.trim();
    final handle = normalizeLogin(rawLogin);
    if (name.isEmpty || handle == null) return false;
    final map = await getLogins();
    map[name] = handle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
    return true;
  }
}
