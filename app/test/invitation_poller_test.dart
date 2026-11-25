import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/invitation_poller.dart';

void main() {
  testWidgets('idle invitation checks back off 15, 30, 60 seconds', (
    tester,
  ) async {
    var calls = 0;
    final poller = InvitationPoller(
      check: () async => calls++,
      isVisible: () => true,
    );
    poller.start();
    await tester.pump(const Duration(seconds: 14));
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 29));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 3);
    poller.dispose();
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 3);
  });

  testWidgets(
    'hidden or paused screens do not issue polls; invitations reset to 5 seconds',
    (tester) async {
      var calls = 0, visible = false;
      final poller = InvitationPoller(
        check: () async => calls++,
        isVisible: () => visible,
      );
      poller.start();
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 0);
      visible = true;
      poller.start(afterInvitation: true);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1);
      poller.pause();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 1);
      poller.start();
      await tester.pump(const Duration(seconds: 15));
      expect(calls, 2);
      poller.dispose();
    },
  );

  testWidgets(
    'slow checks never overlap and an obsolete completion cannot restart polling',
    (tester) async {
      var calls = 0;
      final gate = Completer<void>();
      final poller = InvitationPoller(
        check: () async {
          calls++;
          await gate.future;
        },
        isVisible: () => true,
      );
      poller.start();
      await tester.pump(const Duration(seconds: 15));
      poller.start(afterInvitation: true);
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 1);
      poller.pause();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 1);
      poller.dispose();
    },
  );

  testWidgets(
    'a failed check backs off instead of becoming an unhandled error',
    (tester) async {
      var calls = 0;
      final poller = InvitationPoller(
        check: () async {
          calls++;
          throw StateError('offline');
        },
        isVisible: () => true,
      );
      poller.start();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      expect(tester.takeException(), isNull);
      poller.dispose();
    },
  );
}
