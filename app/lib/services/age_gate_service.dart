import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Age-gate outcome persisted on this device.
enum AgeGateStatus { unknown, verified, blocked }

/// Key-value seam so tests never touch the real keychain.
abstract class AgeGateStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Production store: the platform keychain, so a blocked or verified status
/// survives reinstalls. Game reset never touches secure storage.
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

/// Neutral age gate in front of the paywall.
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

  static const String _statusKey = 'age_gate_status';
  static const String _checkedAtKey = 'age_gate_checked_at';

  /// Minimum age for paid features. 12 and under are blocked.
  static const int minAge = 13;

  static bool passes(int age) => age >= minAge;

  /// Current status for reactive UI (the `/premium` gate listens to this).
  final ValueNotifier<AgeGateStatus> statusListenable =
      ValueNotifier(AgeGateStatus.unknown);

  AgeGateStatus get status => statusListenable.value;

  /// Loads the persisted status. Call once at startup; never throws.
  Future<void> load() async {
    try {
      statusListenable.value = _parse(await _store.read(_statusKey));
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
  }
}
