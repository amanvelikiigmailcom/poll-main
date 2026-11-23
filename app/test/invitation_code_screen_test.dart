import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/auth/invitation_code_screen.dart';
import 'package:flyprox_app/services/invite_code_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'clipboard is read only on tap and accepted code survives navigation',
    (tester) async {
      var reads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              reads++;
              return {'text': 'https://api.flyprox.com/i/ABC234'};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final router = GoRouter(
        initialLocation: '/code',
        routes: [
          GoRoute(
            path: '/code',
            builder: (_, __) => const InvitationCodeScreen(),
          ),
          GoRoute(
            path: AppRoutes.phone,
            builder: (_, __) => const Scaffold(body: Text('Phone login')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(reads, 0);
      await tester.tap(find.text('Paste invitation code'));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('invitation-code')))
            .controller!
            .text,
        'ABC234',
      );
      await tester.ensureVisible(find.text('Continue with code'));
      await tester.tap(find.text('Continue with code'));
      await tester.pumpAndSettle();
      expect(find.text('Phone login'), findsOneWidget);
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(await InviteCodeStore.accepted(), true);
      expect(await InviteCodeStore.source(), 'pasted');
    },
  );
  testWidgets('invalid code stays on screen; skip remains available', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/code',
      routes: [
        GoRoute(
          path: '/code',
          builder: (_, __) => const InvitationCodeScreen(),
        ),
        GoRoute(
          path: AppRoutes.phone,
          builder: (_, __) => const Scaffold(body: Text('Phone login')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invitation-code')), 'O0I123');
    await tester.ensureVisible(find.text('Continue with code'));
    await tester.tap(find.text('Continue with code'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the six-character code from your invitation.'),
      findsOneWidget,
    );
    expect(await InviteCodeStore.code(), isNull);
    await tester.ensureVisible(find.text('Skip, I wasn’t invited'));
    await tester.tap(find.text('Skip, I wasn’t invited'));
    await tester.pumpAndSettle();
    expect(find.text('Phone login'), findsOneWidget);
  });
  testWidgets(
    'a link received while the code screen is open fills an empty field',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InvitationCodeScreen())),
      );
      await tester.pumpAndSettle();
      await InviteCodeStore.save('ABC234', 'link');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('invitation-code')))
            .controller!
            .text,
        'ABC234',
      );
      expect(await InviteCodeStore.accepted(), false);
    },
  );
}
