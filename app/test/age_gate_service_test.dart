import 'package:flutter_test/flutter_test.dart';

import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';
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
    expect(store.values['onboarding_age_gate_status_v1'], 'verified');
    expect(store.values['onboarding_age_gate_checked_at_v1'], isNotNull);

    // Simulate an app restart: drop the in-memory status, reload from store.
    svc.statusListenable.value = AgeGateStatus.unknown;
    await svc.load();
    expect(svc.status, AgeGateStatus.verified);
  });

  test(
    'block applies this run and a fresh launch restarts onboarding',
    () async {
      final svc = AgeGateService.instance;
      await svc.blockMinor();
      expect(svc.status, AgeGateStatus.blocked);

      svc.statusListenable.value = AgeGateStatus.unknown;
      await svc.load();
      expect(svc.status, AgeGateStatus.unknown);
      expect(svc.replayIntroOnLaunch, isTrue);
    },
  );

  test('passes boundary: 12 fails, 13 passes', () {
    expect(AgeGateService.passes(12), isFalse);
    expect(AgeGateService.passes(13), isTrue);
    expect(AgeGateService.passes(18), isTrue);
  });

  test('storage failure falls back to unknown instead of throwing', () async {
    final svc = AgeGateService.instance..debugStore(ThrowingAgeGateStore());
    await svc.load();
    expect(svc.status, AgeGateStatus.unknown);
  });

  test('failed write still keeps the session consistent', () async {
    final svc = AgeGateService.instance..debugStore(ThrowingAgeGateStore());
    await svc.verifyAdult();
    expect(svc.status, AgeGateStatus.verified);
  });
  test('old Premium pass cannot skip the new onboarding question', () async {
    store.values['age_gate_status'] = 'verified';
    store.values['age_gate_checked_at'] = '2026-11-21T00:00:00Z';
    await AgeGateService.instance.load();
    expect(AgeGateService.instance.status, AgeGateStatus.unknown);
  });

  test(
    'a legacy refusal starts a fresh intro instead of importing a pass',
    () async {
      store.values['age_gate_status'] = 'blocked';
      await AgeGateService.instance.load();
      expect(AgeGateService.instance.status, AgeGateStatus.unknown);
      expect(AgeGateService.instance.replayIntroOnLaunch, isTrue);
    },
  );
  test('new onboarding pass takes precedence over a legacy refusal', () async {
    store.values['age_gate_status'] = 'blocked';
    await AgeGateService.instance.verifyAdult();
    AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
    await AgeGateService.instance.load();
    expect(AgeGateService.instance.status, AgeGateStatus.verified);
    expect(AgeGateService.instance.replayIntroOnLaunch, isFalse);
  });

  test('cold load clears the previous run phone-step completion', () async {
    OnboardingFlow.instance.completePhoneStep();
    expect(OnboardingFlow.instance.phoneComplete, isTrue);
    await AgeGateService.instance.load();
    expect(OnboardingFlow.instance.phoneComplete, isFalse);
    expect(AgeGateService.instance.status, AgeGateStatus.unknown);
  });
}
