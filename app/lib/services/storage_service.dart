import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _onboardingKey = 'onboarding_done';
  static const String _phoneKey = 'registered_phone';

  final FlutterSecureStorage _secureStorage;
  late SharedPreferences _prefs;

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
  }

  // ── Auth token (secure) ───────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    notifyListeners();
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    notifyListeners();
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

  static const String _reviewerKey = 'reviewer_seen_v1';

  /// Firebase test numbers used by the App Store reviewer (OTP 123456).
  static const Set<String> reviewerTestPhones = {'+16505551234'};

  static bool isReviewerPhone(String? phone) =>
      phone != null && reviewerTestPhones.contains(phone.trim());

  /// Remembers that the reviewer signed in on this install.
  /// [clearAll] wipes it together with the rest of local state.
  Future<void> markReviewerSeen() async {
    await _prefs.setBool(_reviewerKey, true);
  }

  bool isReviewerSeen() {
    try {
      return _prefs.getBool(_reviewerKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Skip buttons stay visible only for the reviewer session.
  bool get reviewerSkipsAllowed {
    try {
      return isReviewerPhone(getPhone()) || isReviewerSeen();
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
    await _secureStorage.deleteAll();
    await _prefs.clear();
    notifyListeners();
  }
}
