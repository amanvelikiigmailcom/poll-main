import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'contact_picker_service.dart';

/// One friend matched on the server: the local contact label plus the name
/// they registered with.
class ContactMatch {
  final String label;
  final String displayName;

  const ContactMatch({required this.label, required this.displayName});
}

/// Uploads salted hashes of user-picked contacts and reads back matches.
/// Raw phone numbers never leave the device.
class ContactSyncService {
  /// Must equal the backend's CONTACT_HASH_SALT (flyprox_backend rules.js).
  static const String hashSalt = 'flyprox-contacts-v1';
  static const String _matchesKey = 'contact_sync_matches';
  static const String _labelsKey = 'contact_labels_by_hash_v1';

  static Future<Map<String,String>> localLabels() async {
    final raw = (await SharedPreferences.getInstance()).getString(_labelsKey);
    if (raw == null) return {};
    try { return Map<String,String>.from(jsonDecode(raw) as Map); } catch (_) { return {}; }
  }

  final ApiService _api;

  ContactSyncService(this._api);

  /// sha256 of `"flyprox-contacts-v1:"` plus the E.164 number; must equal
  /// the backend's phoneHash.
  static String hashPhone(String e164) {
    final bytes = utf8.encode('$hashSalt:${e164.trim()}');
    return sha256.convert(bytes).toString();
  }

  /// Normalizes [raw] to E.164, using [defaultRegion] for local formats.
  /// Returns null when the number is not parseable or fails validation.
  static String? normalizePhone(
    String raw, {
    IsoCode defaultRegion = IsoCode.US,
  }) {
    final attempts = <IsoCode?>[null, defaultRegion];
    for (final region in attempts) {
      try {
        final parsed = region == null
            ? PhoneNumber.parse(raw.trim())
            : PhoneNumber.parse(raw.trim(), callerCountry: region);
        if (!parsed.isValid()) continue;
        final e164 = parsed.international;
        if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(e164)) return e164;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Uploads [entries] and returns server matches. Never throws: network or
  /// server errors yield an empty list.
  Future<List<ContactMatch>> syncContacts(
    List<PickedContact> entries, {
    IsoCode defaultRegion = IsoCode.US,
  }) async {
    final payload = <Map<String, String>>[];
    final labelByHash = <String, String>{};
    for (final e in entries) {
      final raw = e.phone;
      if (raw == null || raw.trim().isEmpty) continue;
      final e164 = normalizePhone(raw, defaultRegion: defaultRegion);
      if (e164 == null) continue;
      final hash = hashPhone(e164);
      if (labelByHash.containsKey(hash)) continue;
      labelByHash[hash] = e.name;
      payload.add({'hash': hash});
    }
    if (payload.isEmpty) return [];
    final labels = await localLabels()..addAll(labelByHash);
    await (await SharedPreferences.getInstance()).setString(_labelsKey,jsonEncode(labels));
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/contacts',
        data: {'contacts': payload, 'append': true},
      );
      final matches = <ContactMatch>[];
      final list = response.data?['matches'];
      if (list is List) {
        for (final m in list) {
          if (m is! Map) continue;
          final hash = m['hash'] as String?;
          final display = (m['displayName'] as String?)?.trim() ?? '';
          final label = hash == null ? null : labelByHash[hash];
          if (label == null || display.isEmpty) continue;
          matches.add(ContactMatch(label: label, displayName: display));
        }
      }
      await _saveMatches(matches);
      return matches;
    } catch (_) {
      return [];
    }
  }

  /// Matches from the last successful sync (empty when never synced).
  Future<List<ContactMatch>> lastMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_matchesKey) ?? [];
    final out = <ContactMatch>[];
    for (final line in raw) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      out.add(
        ContactMatch(
          label: line.substring(0, tab),
          displayName: line.substring(tab + 1),
        ),
      );
    }
    return out;
  }

  Future<void> _saveMatches(List<ContactMatch> matches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _matchesKey,
      matches.map((m) => '${m.label}\t${m.displayName}').toList(),
    );
  }

  /// Drops cached matches (logout / game reset).
  Future<void> clearMatches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchesKey);
    await prefs.remove(_labelsKey);
  }
}
