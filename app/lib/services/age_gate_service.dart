import 'package:flutter/foundation.dart';
import 'onboarding_flow.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Age-gate outcome persisted on this device.
enum AgeGateStatus { unknown, verified, blocked }

/// Key-value seam so tests never touch the real keychain.
abstract class AgeGateStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Platform keychain stores the outcome; load() treats a refusal as a request
/// to replay intro on the next launch. Game reset does not clear this store.
class SecureAgeGateStore implements AgeGateStore {
  const SecureAgeGateStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Declared-age gate before entering the application.
///
/// Only the resulting status and its timestamp are stored; the selected age
/// itself is never retained, and nothing leaves the device. All entry points
/// are total: a storage failure falls back to [AgeGateStatus.unknown] (ask
/// again) instead of throwing.
class AgeGateService {
  AgeGateService._({AgeGateStore? store})
    : _store = store ?? const SecureAgeGateStore();

  static final AgeGateService instance = AgeGateService._();

  AgeGateStore _store;

  static const String _statusKey = 'onboarding_age_gate_status_v1';
  static const String _legacyStatusKey = 'age_gate_status';
  static const String _checkedAtKey = 'onboarding_age_gate_checked_at_v1';

  /// Minimum age for using the application. 12 and under are blocked.
  static const int minAge = 13;

  static bool passes(int age) => age >= minAge;

  /// Current status for startup and all protected application routes.
  final ValueNotifier<AgeGateStatus> statusListenable = ValueNotifier(
    AgeGateStatus.unknown,
  );

  AgeGateStatus get status => statusListenable.value;

  bool replayIntroOnLaunch = false;
  void introFinished() => replayIntroOnLaunch = false;

  /// Loads the persisted status. Call once at startup; never throws.
  Future<void> load() async {
    OnboardingFlow.instance.restart();
    try {
      final raw = await _store.read(_statusKey);
      final saved = _parse(raw);
      // Legacy Premium eligibility is not consent to the new onboarding gate.
      // Preserve a previous refusal only to replay intro; never import a pass.
      final legacyBlocked =
          raw == null &&
          _parse(await _store.read(_legacyStatusKey)) == AgeGateStatus.blocked;
      // A refusal blocks this run. A fresh launch replays onboarding and asks
      // again, as requested; contacts/gameplay remain inaccessible until eligible.
      replayIntroOnLaunch = saved == AgeGateStatus.blocked || legacyBlocked;
      statusListenable.value = replayIntroOnLaunch
          ? AgeGateStatus.unknown
          : saved;
    } catch (_) {
      statusListenable.value = AgeGateStatus.unknown;
    }
  }

  Future<void> verifyAdult() => _save(AgeGateStatus.verified);

  Future<void> blockMinor() => _save(AgeGateStatus.blocked);

  Future<void> _save(AgeGateStatus status) async {
    try {
      await _store.write(_statusKey, status.name);
      await _store.write(_checkedAtKey, DateTime.now().toIso8601String());
    } catch (_) {
      // A failed write must not trap the user; the in-memory status still
      // keeps this session consistent.
    }
    statusListenable.value = status;
  }

  static AgeGateStatus _parse(String? raw) {
    for (final s in AgeGateStatus.values) {
      if (s.name == raw) return s;
    }
    return AgeGateStatus.unknown;
  }

  @visibleForTesting
  void debugStore(AgeGateStore store) {
    _store = store;
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _store = const SecureAgeGateStore();
    statusListenable.value = AgeGateStatus.unknown;
    replayIntroOnLaunch = false;
  }
}
