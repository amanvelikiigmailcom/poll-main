import 'package:crypto/crypto.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'local_game_service.dart';

class StorageService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _onboardingKey = 'onboarding_done';
  static const String _phoneKey = 'registered_phone';

  final FlutterSecureStorage _secureStorage;
  late SharedPreferences _prefs;
  String? _activeToken;
  int _authenticationGeneration = 0;
  Future<void> _credentialWrites = Future<void>.value();

  /// Shared by both login paths. Logout or a newer attempt cancels older work.
  int beginAuthentication() => ++_authenticationGeneration;

  bool isAuthenticationCurrent(int generation) =>
      generation == _authenticationGeneration;

  Future<T> _withCredentialLock<T>(Future<T> Function() action) {
    final result = _credentialWrites.then((_) => action());
    _credentialWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  /// Commits only the latest login, serially with logout and credential writes.
  /// Metadata is staged first; a failed/cancelled secure write is rolled back.
  Future<bool> saveAuthenticatedSession(
    int generation, {
    required String token,
    String? phone,
    String? accountId,
    bool reviewerAccess = false,
  }) => _withCredentialLock(() async {
    if (!isAuthenticationCurrent(generation)) return false;
    final oldToken = await getToken();
    final oldPhone = getPhone();
    final oldUser = _prefs.getString(_userKey);
    if (!isAuthenticationCurrent(generation)) return false;
    final reviewerKey =
        'reviewer_access_v2_${sha256.convert(utf8.encode(token))}';
    final oldReviewer = _prefs.getBool(reviewerKey);
    Future<void> restoreMetadata() async {
      if (oldPhone == null) {
        await _prefs.remove(_phoneKey);
      } else {
        await _prefs.setString(_phoneKey, oldPhone);
      }
      if (oldUser != null) await _prefs.setString(_userKey, oldUser);
      if (oldReviewer == null) {
        await _prefs.remove(reviewerKey);
      } else {
        await _prefs.setBool(reviewerKey, oldReviewer);
      }
    }

    try {
      await _prefs.remove(_userKey);
      await _prefs.remove(_phoneKey);
      if (phone != null && phone.trim().isNotEmpty) {
        await _prefs.setString(_phoneKey, phone.trim());
      }
      await _prefs.setBool(reviewerKey, reviewerAccess);
      if (!isAuthenticationCurrent(generation)) {
        await restoreMetadata();
        return false;
      }
      await _secureStorage.write(key: _tokenKey, value: token);
      if (!isAuthenticationCurrent(generation)) {
        if (oldToken == null) {
          await _secureStorage.delete(key: _tokenKey);
        } else {
          await _secureStorage.write(key: _tokenKey, value: oldToken);
        }
        await restoreMetadata();
        return false;
      }
      _activeToken = token;
      if (accountId != null && accountId.isNotEmpty) {
        final legacy = oldUser == null
            ? null
            : (jsonDecode(oldUser) as Map)['id'] as String?;
        await LocalGameService.instance.activateAccount(
          accountId,
          legacyOwner: legacy,
        );
      }
      notifyListeners();
      return true;
    } catch (_) {
      await restoreMetadata();
      rethrow;
    }
  });

  /// Clear the session immediately, before waiting for best-effort remote logout.
  Future<String?> clearSession() {
    beginAuthentication();
    return _withCredentialLock(() async {
      final token = await getToken();
      await _secureStorage.delete(key: _tokenKey);
      _activeToken = null;
      if (_prefs.containsKey('local_game_scope_owner_v1')) {
        await LocalGameService.instance.activateAccount('guest');
      }
      await clearUser();
      await clearPhone();
      notifyListeners();
      return token;
    });
  }

  StorageService()
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          migrateOnAlgorithmChange: true,
          migrateWithBackup: true,
          resetOnError: false,
        ),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      _activeToken = await getToken();
    } catch (_) {
      _activeToken = null;
    }
  }

  // ── Auth token (secure) ───────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    beginAuthentication();
    await _withCredentialLock(() async {
      await _secureStorage.write(key: _tokenKey, value: token);
      _activeToken = token;
      notifyListeners();
    });
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    beginAuthentication();
    await _withCredentialLock(() async {
      await _secureStorage.delete(key: _tokenKey);
      _activeToken = null;
      notifyListeners();
    });
  }

  // ── User (SharedPreferences, non-sensitive) ───────────────────────────────

  Future<void> saveUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  User? getUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<void> saveOnboardingDone() async {
    await _prefs.setBool(_onboardingKey, true);
  }

  bool isOnboardingDone() {
    return _prefs.getBool(_onboardingKey) ?? false;
  }

  // ── Phone ─────────────────────────────────────────────────────────────────

  Future<void> savePhone(String phone) async {
    await _prefs.setString(_phoneKey, phone);
  }

  Future<void> clearPhone() async => _prefs.remove(_phoneKey);

  String? getPhone() {
    return _prefs.getString(_phoneKey);
  }

  // ── Reviewer ──────────────────────────────────────────────────────────────

  String? get _reviewerSessionKey => _activeToken == null
      ? null
      : 'reviewer_access_v2_${sha256.convert(utf8.encode(_activeToken!))}';

  /// Capability from a verified backend response, scoped to this exact session.
  Future<void> saveReviewerAccess(bool allowed) async {
    final key = _reviewerSessionKey;
    if (key == null) return;
    await _prefs.setBool(key, allowed);
    notifyListeners();
  }

  bool get reviewerSkipsAllowed {
    try {
      final key = _reviewerSessionKey;
      return key != null && (_prefs.getBool(key) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Random app-installation identifier for sign-in notices. No hardware fingerprint.
  Future<String> notificationInstallationId() async {
    const key = 'notification_installation_id_v1';
    final existing = await _secureStorage.read(key: key);
    if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final value = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _secureStorage.write(key: key, value: value);
    return value;
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    beginAuthentication();
    await _withCredentialLock(() async {
      await _secureStorage.deleteAll();
      _activeToken = null;
      await _prefs.clear();
      notifyListeners();
    });
  }
}
