import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'fakes/social_storage.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/support_email_service.dart';
import 'package:flyprox_app/widgets/common/support_email_dialog.dart';

void main() {
  for (final kind in SupportEmailKind.values) {
    test(
      '$kind prepares a correctly encoded draft to the approved address',
      () {
        final email = SupportEmail(
          kind: kind,
          details: 'A & B? 50% + café\nNext line',
          reason: 'Other',
          targetId: 'account-42',
          username: 'alex_123',
        );
        expect(email.emailUri.path, 'support@flyprox.com');
        expect(email.emailUri.scheme, 'mailto');
        expect(
          email.emailUri.queryParameters['body'],
          contains('A & B? 50% + café\nNext line'),
        );
        expect(email.emailUri.queryParameters['subject'], kind.subject);
        expect(email.body, contains('Account reference: account-42'));
      },
    );
  }

  test('email launcher errors are returned as unavailable', () async {
    final service = SupportEmailService(
      openEmail: (_) async => throw StateError('unavailable'),
    );
    expect(
      await service.openDraft(
        const SupportEmail(kind: SupportEmailKind.support),
      ),
      isFalse,
    );
  });

  Future<void> mount(
    WidgetTester tester,
    SupportEmailService service, {
    SupportEmailKind kind = SupportEmailKind.feedback,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportEmailServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSupportEmail(
                  context,
                  kind: kind,
                  targetId: 'account-42',
                  username: 'alex_123',
                ),
                child: const Text('Compose'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'missing email app preserves the message and copies a complete fallback',
    (tester) async {
      String? copied;
      final opened = <Uri>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(
        tester,
        SupportEmailService(
          openEmail: (uri) async {
            opened.add(uri);
            return false;
          },
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Please fix the timer & sound.',
      );
      await tester.tap(find.text('Open email'));
      await tester.pumpAndSettle();
      expect(
        opened.single.queryParameters['body'],
        contains('Please fix the timer & sound.'),
      );
      expect(
        find.textContaining('Couldn’t open an email app.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy message'));
      await tester.pumpAndSettle();
      expect(copied, contains('To: support@flyprox.com'));
      expect(copied, contains('Please fix the timer & sound.'));
      expect(find.text('Report received'), findsNothing);
    },
  );

  testWidgets(
    'account report requires a reason; opening never claims it was sent',
    (tester) async {
      final pending = Completer<bool>();
      final opened = <Uri>[];
      await mount(
        tester,
        SupportEmailService(
          openEmail: (uri) {
            opened.add(uri);
            return pending.future;
          },
        ),
        kind: SupportEmailKind.account,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bullying or harassment').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open email'));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(
        opened.single.queryParameters['body'],
        contains('Reason: Bullying or harassment'),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Email draft opened. Send it from your email app when ready.',
        ),
        findsOneWidget,
      );
      expect(find.text('Report sent'), findsNothing);
    },
  );

  testWidgets(
    'Settings exposes separate support, problem and feedback drafts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage()..token = null;
      await storage.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (final kind in [
        SupportEmailKind.support,
        SupportEmailKind.problem,
        SupportEmailKind.feedback,
      ]) {
        await tester.scrollUntilVisible(find.text(kind.title), 200);
        await tester.tap(find.text(kind.title));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SupportEmailDialog>(find.byType(SupportEmailDialog))
              .kind,
          kind,
        );
        expect(find.text('Open email'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    '320px screen with large text scrolls and cancel opens no email',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opens = 0;
      await mount(
        tester,
        SupportEmailService(
          openEmail: (_) async {
            opens++;
            return true;
          },
        ),
        kind: SupportEmailKind.account,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.byType(SupportEmailDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
