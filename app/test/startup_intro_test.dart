import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/widgets/common/startup_intro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
  });

  testWidgets('absent optional video never blocks launch', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
        MaterialApp(home: StartupIntro(onComplete: () => completed++)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Skip finishes once even when a fallback timer later fires',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(
        MaterialApp(home: StartupIntro(onComplete: () => completed++)));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion uses the short static fallback', (tester) async {
    await GameSettings.instance.setOption('reduce_motion', true);
    var completed = 0;
    await tester.pumpWidget(
        MaterialApp(home: StartupIntro(onComplete: () => completed++)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(completed, 1);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
