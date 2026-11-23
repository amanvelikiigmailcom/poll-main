import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'content_service.dart';
import 'local_game_service.dart';
import 'storage_service.dart';

class OnboardingDetailsService extends ChangeNotifier {
  OnboardingDetailsService(this.api, this.storage) {
    storage.addListener(_changed);
  }
  final ApiService api;
  final StorageService storage;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    storage.removeListener(_changed);
    super.dispose();
  }

  Future<String> _key() async {
    final token = await storage.getToken();
    // Session scoping prevents a new token briefly reusing the previous
    // account's cached phone/profile while login persistence is still running.
    final identity = token?.isNotEmpty == true ? 'session:$token' : 'guest';
    return 'onboarding_details_v1_${sha256.convert(utf8.encode(identity))}';
  }

  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _key());
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _persist(Map<String, dynamic> value, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
    _changed();
  }

  Future<void> draft(Map<String, dynamic> patch) async {
    final key = await _key();
    final next = _writes.then((_) async {
      if (key != await _key()) return;
      await _persist({...await read(), ...patch}, key);
    });
    _writes = next.catchError((Object _) {});
    await next;
  }

  Future<void> restore() async {
    final token = await storage.getToken();
    if (token?.isNotEmpty != true) return;
    final key = await _key();
    try {
      final response = await api.get<Map<String, dynamic>>('/api/onboarding');
      if (token != await storage.getToken() || key != await _key()) return;
      final data = response.data;
      if (data == null ||
          ![
            'pending',
            'selected',
            'skipped',
            'requested',
          ].contains(data['status'])) {
        return;
      }
      final prior = await read();
      // Retain unsaved input after errors and account-scoped progress locally.
      await _persist({
        ...data,
        ...prior,
        'school': data['school'],
        'status': data['status'],
        'country': data['country'],
        'graduationYear': data['graduationYear'],
        'stage':
            prior['stage'] ??
            (data['profileComplete'] == true ? 'school' : 'profile'),
      }, key);
    } catch (_) {
      /* Saved drafts remain usable offline; saves still require server acknowledgement. */
    }
  }

  Future<String> country() async =>
      (await read())['country'] as String? ?? 'US';
  Future<void> setCountry(String country) async {
    final data = await read();
    if (data['country'] == country) return;
    await draft({
      'country': country,
      'school': null,
      'graduationYear': null,
      'status': 'pending',
    });
  }

  Future<void> _save(
    Map<String, dynamic> request,
    Map<String, dynamic> local,
  ) async {
    final token = await storage.getToken();
    final key = await _key();
    if (token?.isNotEmpty == true) {
      final response = await api.put<Map<String, dynamic>>(
        '/api/onboarding',
        data: request,
      );
      if (await storage.getToken() != token || key != await _key()) {
        throw const ApiException('Account changed. Please try again.');
      }
      local = {...local, ...?response.data};
    }
    if (key != await _key()) {
      throw const ApiException('Account changed. Please try again.');
    }
    await _persist({...await read(), ...local}, key);
  }

  Future<void> saveProfile(String first, String last, String gender) async {
    final ownerToken = await storage.getToken();
    final error =
        LocalGameService.validateProfileName(first, 'first name') ??
        LocalGameService.validateProfileName(last, 'last name');
    if (error != null || !['female', 'male', 'nonbinary'].contains(gender)) {
      throw const ApiException('Enter your name and choose a gender.');
    }
    await draft({
      'firstName': first.trim(),
      'lastName': last.trim(),
      'gender': gender,
    });
    final countryCode = await country();
    await _save(
      {
        'step': 'profile',
        'country': countryCode,
        'firstName': first.trim(),
        'lastName': last.trim(),
        'gender': gender,
      },
      {
        'firstName': first.trim(),
        'lastName': last.trim(),
        'gender': gender,
        'country': countryCode,
        'stage': 'school',
        'status': 'pending',
      },
    );
    if (ownerToken != await storage.getToken()) {
      throw const ApiException('Account changed. Please try again.');
    }
    await LocalGameService.instance.saveFullName(first, last);
  }

  Future<void> selectSchool(Map<String, dynamic> school, int year) async {
    if (!validYear(year)) {
      throw const ApiException('Choose a valid graduation year.');
    }
    final countryCode = await country();
    await _save(
      {
        'step': 'school',
        'country': countryCode,
        'schoolId': school['id'],
        'graduationYear': year,
      },
      {
        'school': school,
        'graduationYear': year,
        'status': 'selected',
        'stage': 'contacts',
      },
    );
  }

  Future<void> skipSchool() async {
    if (!ContentService.instance.flag('school_skip_enabled')) {
      throw const ApiException('Skipping school is disabled.');
    }
    await _save(
      {'step': 'skip', 'country': await country()},
      {
        'school': null,
        'graduationYear': null,
        'status': 'skipped',
        'stage': 'contacts',
      },
    );
  }

  Future<void> requestSchool({
    required String name,
    required String city,
    required String region,
    required int year,
  }) async {
    if (!validYear(year)) {
      throw const ApiException('Enter a valid graduation year.');
    }
    await _save(
      {
        'step': 'request',
        'country': await country(),
        'requestedSchool': name.trim(),
        'requestedCity': city.trim(),
        'requestedRegion': region.trim(),
        'graduationYear': year,
      },
      {
        'missingSchool': name.trim(),
        'missingCity': city.trim(),
        'missingRegion': region.trim(),
        'graduationYear': year,
        'status': 'requested',
        'school': null,
      },
    );
  }

  Future<void> finish() async {
    if ((await read())['stage'] != null) await draft({'stage': 'done'});
  }

  Future<bool> votingAllowed() async {
    final data = await read();
    return data['stage'] == null || data['status'] == 'selected';
  }

  Future<Map<String, dynamic>> search(String q, {String cursor = ''}) async {
    final countryCode = await country();
    final response = await api.get<Map<String, dynamic>>(
      '/api/schools',
      queryParameters: {'country': countryCode, 'q': q, 'cursor': cursor},
    );
    return response.data ?? {};
  }

  static bool validYear(int year) =>
      year >= DateTime.now().year - 80 && year <= DateTime.now().year + 15;
  static Uri schoolEmail({
    required String email,
    required String name,
    required String country,
    required String city,
    required String region,
    required String year,
  }) => Uri(
    scheme: 'mailto',
    path: email,
    query:
        'subject=${Uri.encodeComponent('Please add my campus to Flyprox')}&body=${Uri.encodeComponent('Hello Flyprox,\n\nPlease add my campus:\nCampus: ${name.trim()}\nCountry: $country\nCity: ${city.trim()}\nState / region: ${region.trim()}\nGraduation year: $year\n\nThank you!')}',
  );
}
