import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/voting/star_received_screen.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/services/local_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.setOption('sound', false);
    await GameSettings.instance.setOption('haptics', false);
    await GameSettings.instance.setOption('reduce_motion', false);
  });
  testWidgets(
    'collect animates once without crediting the balance a second time',
    (tester) async {
      final before = await LocalGameService.instance.getStars();
      await tester.pumpWidget(
        const MaterialApp(home: StarReceivedScreen(starsAwarded: 1000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collect 1000 stars'), findsOneWidget);
      expect(find.text('Collection'), findsNothing);
      await tester.tap(find.byKey(const Key('collect-stars')));
      await tester.pump();
      expect(find.text('Collecting…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collect-stars')));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(await LocalGameService.instance.getStars(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reduced-motion collect completes immediately at 320px and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await GameSettings.instance.setOption('reduce_motion', true);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const StarReceivedScreen(starsAwarded: 2000),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collect-stars')));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Collecting…'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
