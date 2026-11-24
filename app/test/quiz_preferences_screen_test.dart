import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/settings/settings_quiz_screen.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/quiz_preferences_service.dart';
import 'fakes/social_storage.dart';
import 'quiz_preferences_service_test.dart' show quizPreferencesPayload;

class FakeQuizPreferences extends QuizPreferencesService {
  FakeQuizPreferences(super.api, super.storage);
  String value = 'all';
  int writes = 0;
  bool failLoad = false;
  bool failSave = false;
  bool loseReply = false;
  Completer<void>? pending;
  @override
  Future<QuizPreferencesData> load(String token) async {
    if (failLoad) throw const ApiException('Load failed');
    return QuizPreferencesData.fromJson(quizPreferencesPayload(value));
  }

  @override
  Future<QuizPreferencesData> save(String token, String selected) async {
    writes++;
    await pending?.future;
    if (failSave) throw const ApiException('Save failed');
    value = selected;
    if (loseReply) throw const ApiException('Reply lost');
    return QuizPreferencesData.fromJson(quizPreferencesPayload(value));
  }
}

void main() {
  Future<({FakeQuizPreferences service, SessionStorage storage})> mount(
    WidgetTester tester, {
    bool guest = false,
    bool fail = false,
    double scale = 1,
    bool fromSettings = false,
  }) async {
    final storage = SessionStorage()..token = guest ? null : 'owner';
    final service = FakeQuizPreferences(ApiService(storage), storage)
      ..failLoad = fail;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          quizPreferencesServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: fromSettings
              ? const SettingsScreen()
              : Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showQuizPreferences(context),
                      child: const Text('Open preferences'),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (fromSettings) {
      await tester.scrollUntilVisible(find.text('Quiz preferences'), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz preferences'));
    } else {
      await tester.tap(find.text('Open preferences'));
    }
    await tester.pumpAndSettle();
    return (service: service, storage: storage);
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(RadioListTile<String>, label),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String>, label));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings GAME entry opens server-backed Quiz preferences', (
    tester,
  ) async {
    await mount(tester, fromSettings: true);
    expect(find.text('Who appears in your quizzes?'), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('server default, four options, single choice, save and reopen', (
    tester,
  ) async {
    final f = await mount(tester);
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Girls'), findsNothing);
    await choose(tester, 'Girls');
    expect(find.byType(RadioListTile<String>), findsNWidgets(4));
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'female',
    );
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(f.service.value, 'female');
    expect(f.service.writes, 1);
    expect(find.text('Quiz preferences'), findsNothing);
    await tester.tap(find.text('Open preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Girls'), findsOneWidget);
    await choose(tester, 'Everyone');
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(f.service.value, 'all');
  });

  testWidgets('Back and swipe close without saving temporary selection', (
    tester,
  ) async {
    final f = await mount(tester);
    await choose(tester, 'Boys');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(f.service.writes, 0);
    expect(f.service.value, 'all');
    await tester.tap(find.text('Open preferences'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(Divider), const Offset(0, 180), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Quiz preferences'), findsNothing);
    expect(f.service.writes, 0);
  });

  testWidgets(
    'load failure has Retry and no invented default; guest cannot save',
    (tester) async {
      final f = await mount(tester, fail: true);
      expect(find.text('Load failed'), findsOneWidget);
      expect(find.text('Everyone'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Select'))
            .onPressed,
        isNull,
      );
      f.service.failLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Everyone'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await mount(tester, guest: true);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Everyone'), findsNothing);
    },
  );

  testWidgets(
    'save failure retains draft; lost successful reply is reconciled',
    (tester) async {
      final f = await mount(tester);
      await choose(tester, 'Non-binary');
      f.service.failSave = true;
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('Save failed'), findsOneWidget);
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'nonbinary',
      );
      f.service.failSave = false;
      f.service.loseReply = true;
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(f.service.value, 'nonbinary');
      expect(find.text('Quiz preferences'), findsNothing);
    },
  );

  testWidgets(
    'saving blocks dismissal and repeated writes; account switch clears form',
    (tester) async {
      final f = await mount(tester);
      f.service.pending = Completer<void>();
      await choose(tester, 'Girls');
      await tester.tap(find.text('Select'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Saving…'));
      expect(f.service.writes, 1);
      await f.storage.clearToken();
      await tester.pump();
      expect(find.text('Everyone'), findsNothing);
      expect(find.textContaining('Account changed'), findsOneWidget);
      f.service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Quiz preferences'), findsOneWidget);
      expect(find.text('Girls'), findsNothing);
    },
  );

  testWidgets('small phone and large text remain scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, scale: 2);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.expand_more),
      100,
      scrollable: find
          .descendant(
            of: find.byType(SettingsQuizScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(RadioListTile<String>, 'Non-binary'),
    );
    expect(tester.takeException(), isNull);
  });
}
