import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';

/// Non-age route tests arrange a player who already passed onboarding's gate.
void markEligiblePlayer() {
  OnboardingFlow.instance.restart();
  AgeGateService.instance.replayIntroOnLaunch = false;
  AgeGateService.instance.statusListenable.value = AgeGateStatus.verified;
}
