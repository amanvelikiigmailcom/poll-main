import 'package:flyprox_app/services/age_gate_service.dart';

/// In-memory age-gate store: proves the service logic without touching the
/// real keychain (its platform channel has no native side in tests).
class InMemoryAgeGateStore implements AgeGateStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

/// Store that always fails: proves the service falls back to asking again.
class ThrowingAgeGateStore implements AgeGateStore {
  @override
  Future<String?> read(String key) => throw StateError('no keychain');

  @override
  Future<void> write(String key, String value) =>
      throw StateError('no keychain');
}
