import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _onboardingKey = 'onboarding_done';
  static const String _phoneKey = 'registered_phone';

  final FlutterSecureStorage _secureStorage;
  late SharedPreferences _prefs;

  StorageService()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Auth token (secure) ───────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
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

  String? getPhone() {
    return _prefs.getString(_phoneKey);
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}
