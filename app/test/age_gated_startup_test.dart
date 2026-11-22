import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/widgets/common/age_gated_startup.dart';

void main() {
  setUp(
    () =>
        AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown,
  );
  testWidgets(
    'SDK startup waits for an eligible answer; refusal starts nothing',
    (tester) async {
      var calls = 0;
      final ready = Completer<void>();
      await tester.pumpWidget(
        AgeGatedStartup(
          initialize: () {
            calls++;
            return ready.future;
          },
          child: const MaterialApp(home: Text('Intro')),
        ),
      );
      expect(calls, 0);
      AgeGateService.instance.statusListenable.value = AgeGateStatus.blocked;
      await tester.pump();
      expect(calls, 0);
      AgeGateService.instance.statusListenable.value = AgeGateStatus.verified;
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('Intro'), findsOneWidget);
      AgeGateService.instance.statusListenable.value = AgeGateStatus.verified;
      await tester.pump();
      expect(calls, 1);
    },
  );
}
