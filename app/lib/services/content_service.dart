import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Server-driven texts: our own Remote Config (wave 1), never Firebase.
///
/// Defaults are baked in (mirrored by `flyprox_backend/src/content.js`); the
/// server only carries overrides. Every read is synchronous and never throws:
/// with no network the app runs on defaults (or the 12-hour cache).
class ContentService extends ChangeNotifier {
  ContentService._();
  static final ContentService instance = ContentService._();

  static const _cacheKey = 'content_cache_json';
  static const _cacheAtKey = 'content_cache_at_ms';
  static const cacheTtl = Duration(hours: 12);

  /// Wave-1 defaults. Keep in sync with the backend seed.
  static const Map<String, String> defaults = {
    'invite_message': 'Try Flyprox. Fun quizzes about people you know!',
    'paywall_title': 'Premium',
    'paywall_subtitle': 'Get closer to the people who pick you',
    'paywall_product_name': 'Premium Weekly',
    'paywall_term': '{price} / week · 1-week auto-renewing subscription',
    'paywall_features':
        '["2 full-name voter reveals per subscription week","5 first-initial voter reveals per subscription week","Stars ×2 for completed online rounds","Blue Premium membership badge"]',
    'paywall_features_v2':
        '["2 full-name voter reveals per subscription week","5 first-initial voter reveals per subscription week","Stars ×2 for completed online rounds","Blue Premium membership badge"]',
    'paywall_features_v3':
        '["2 full-name voter reveals per subscription week","5 first-initial voter reveals per subscription week","Stars ×2 — 2000 per completed online round","Blue Premium badge while your subscription is active"]',
    'paywall_cta': 'Get Premium · {price}',
    'upsell_timer_button': 'Premium benefits',
    'blocked_title': 'Not available for your age',
    'blocked_body':
        'Flyprox is for ages 13 and up. This game isn’t available for your age yet. Ask a parent or guardian if you have questions.',
    'onboarding_pages':
        '[{"eyebrow":"A NEW WAY TO PLAY","title":"Who’s most\\nlikely to…?","subtitle":"Light up the room? Make everyone laugh?\\nPick the person who fits best."},{"eyebrow":"BETTER WITH YOUR PEOPLE","title":"Make it\\nyour circle.","subtitle":"Choose at least four contacts.\\nOr try our example names."},{"eyebrow":"A LITTLE PLAY. A LITTLE JOY.","title":"Play. Collect.\\nRepeat.","subtitle":"Answer 12 questions, collect your stars,\\nand come back for a fresh round."}]',
    'url_support':
        'https://distinct-lunaria-d0a.notion.site/41ae779d2742815494ebfa72e5db4620',
    'url_terms':
        'https://distinct-lunaria-d0a.notion.site/41ae779d27428104bac7d2e41d83015a',
    'url_privacy':
        'https://distinct-lunaria-d0a.notion.site/41ae779d27428120b9bbfb769e7063f6',
    'url_marketing':
        'https://distinct-lunaria-d0a.notion.site/41ae779d274281a095c3dd25afefafe2',
    'support_email': 'support@flyprox.com',
    'school_skip_enabled': 'true',
    'guest_enabled': 'true',
    'contacts_enabled': 'true',
    'example_names_enabled': 'true',
    'example_names_button': 'Try with example names',
    'example_names_description':
        'Want to try first? Use example names without sharing contacts.',
  };

  Map<String, String> _overrides = {};

  @visibleForTesting
  void debugSetOverrides(Map<String, String> values) {
    _overrides = Map.of(values);
    notifyListeners();
  }

  @visibleForTesting
  void debugClear() {
    _overrides = {};
    notifyListeners();
  }

  /// Reads [key]: server override first, baked-in default otherwise.
  String text(String key) {
    try {
      final override = _overrides[key];
      if (override != null && override.isNotEmpty) return override;
      return defaults[key] ?? '';
    } catch (_) {
      return defaults[key] ?? '';
    }
  }

  /// Parses a flag: only explicit false-values disable; default is enabled.
  bool flag(String key) {
    final value = text(key).trim().toLowerCase();
    return value != 'false' && value != '0' && value != 'no' && value != 'off';
  }

  /// Substitutes `{name}` placeholders in the [key] template.
  String template(String key, [Map<String, String> params = const {}]) {
    var out = text(key);
    try {
      params.forEach((name, value) {
        out = out.replaceAll('{$name}', value);
      });
    } catch (_) {
      return text(key);
    }
    return out;
  }

  List<String>? _tryStringList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Parses a JSON string list; a short override is padded from defaults.
  List<String> stringList(String key) {
    final override = _tryStringList(_overrides[key]);
    final fallback = _tryStringList(defaults[key]) ?? const [];
    if (override == null) return fallback;
    if (override.length >= fallback.length) return override;
    return [...override, ...fallback.sublist(override.length)];
  }

  /// Parses a JSON value override, or null when missing or malformed.
  dynamic json(String key) {
    try {
      return jsonDecode(text(key));
    } catch (_) {
      return null;
    }
  }

  /// Loads the cached overrides unless the 12-hour cache expired.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_cacheAtKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - at >
          cacheTtl.inMilliseconds) {
        return;
      }
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _overrides = decoded.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    } catch (_) {
      _overrides = {};
    }
  }

  /// Fetches `/api/content` (public) and persists it; never throws.
  Future<void> refresh(ApiService api) => _refreshFrom(
    () async => (await api.get<Map<String, dynamic>>('/api/content')).data,
  );

  /// Intro copy can load before the age answer without auth/install IDs or SDKs.
  Future<void> refreshPublic() async {
    final client = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.flyprox.com',
        ),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    try {
      await _refreshFrom(
        () async =>
            (await client.get<Map<String, dynamic>>('/api/content')).data,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _refreshFrom(
    Future<Map<String, dynamic>?> Function() fetch,
  ) async {
    try {
      final body = await fetch();
      final content = body?['content'];
      if (content is! Map) return;
      final next = <String, String>{};
      content.forEach((k, v) {
        if (v is String && v.isNotEmpty) next[k.toString()] = v;
      });
      if (next.isEmpty) return;
      _overrides = next;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(next));
      await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Offline or server error: keep whatever we have.
    }
  }
}
