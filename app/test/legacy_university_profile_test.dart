import 'fakes/eligible_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Keep the active editor's data-preservation regression even though the
  // retired, test-only university picker and its directory are no longer bundled.
  testWidgets(
    'server editor does not expose or overwrite the legacy local university',
    (tester) async {
      final game = LocalGameService.instance;
      await game.savePlayerAndFriends(
        playerName: 'Player',
        friends: ['Alex', 'Sam', 'Jordan'],
      );
      await game.saveFullName('Player', 'Smith');
      await game.saveUsername('player_123');
      await game.saveUniversity('Harvard University');
      final storage = StorageService();
      await storage.init();
      testAppRouter.go(AppRoutes.profile);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp.router(routerConfig: testAppRouter),
        ),
      );
      await tester.pumpAndSettle();
      testAppRouter.push(AppRoutes.editProfile);
      await tester.pumpAndSettle();
      expect(find.text('Sign in to edit your profile.'), findsOneWidget);
      expect(find.byKey(const Key('university-picker-field')), findsNothing);
      expect(find.text('Harvard University'), findsNothing);
      expect(await game.getUniversity(), 'Harvard University');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.profile,
      );
      expect(await game.getUniversity(), 'Harvard University');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
