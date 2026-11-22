import 'package:flutter_test/flutter_test.dart';

import 'package:flyprox_app/services/age_gate_service.dart';
import 'fakes/fake_age_gate_store.dart';

void main() {
  late InMemoryAgeGateStore store;

  setUp(() {
    store = InMemoryAgeGateStore();
    AgeGateService.instance.debugStore(store);
  });

  tearDown(() => AgeGateService.instance.resetForTest());

  test('starts unknown when nothing is stored', () async {
    final svc = AgeGateService.instance;
    await svc.load();
    expect(svc.status, AgeGateStatus.unknown);
  });

  test('verify persists and survives a reload', () async {
    final svc = AgeGateService.instance;
    await svc.verifyAdult();
    expect(svc.status, AgeGateStatus.verified);
    expect(store.values['age_gate_status'], 'verified');
    expect(store.values['age_gate_checked_at'], isNotNull);

    // Simulate an app restart: drop the in-memory status, reload from store.
    svc.statusListenable.value = AgeGateStatus.unknown;
    await svc.load();
    expect(svc.status, AgeGateStatus.verified);
  });

  test('block applies this run and a fresh launch restarts onboarding', () async {
    final svc = AgeGateService.instance;
    await svc.blockMinor();
    expect(svc.status, AgeGateStatus.blocked);

    svc.statusListenable.value = AgeGateStatus.unknown;
    await svc.load();
    expect(svc.status, AgeGateStatus.unknown);
    expect(svc.replayIntroOnLaunch, isTrue);
  });

  test('passes boundary: 12 fails, 13 passes', () {
    expect(AgeGateService.passes(12), isFalse);
    expect(AgeGateService.passes(13), isTrue);
    expect(AgeGateService.passes(18), isTrue);
  });

  test('storage failure falls back to unknown instead of throwing', () async {
    final svc = AgeGateService.instance
      ..debugStore(ThrowingAgeGateStore());
    await svc.load();
    expect(svc.status, AgeGateStatus.unknown);
  });

  test('failed write still keeps the session consistent', () async {
    final svc = AgeGateService.instance
      ..debugStore(ThrowingAgeGateStore());
    await svc.verifyAdult();
    expect(svc.status, AgeGateStatus.verified);
  });
}
