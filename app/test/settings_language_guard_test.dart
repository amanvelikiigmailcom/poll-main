import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/services/game_settings.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/social_storage.dart';

/// The language screen exists but is intentionally unreachable: saved
/// languages change nothing (the app is pinned to English) and Settings
/// must not offer an entry to it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings.instance.load();
    await SubscriptionService.instance.resetForTest();
    gateway = FakeGateway();
    SubscriptionService.instance.debugGateway(gateway);
  });
  tearDown(() async {
    await SubscriptionService.instance.resetForTest();
    await gateway.events.close();
  });

  Future<void> mountSettings(WidgetTester tester) async {
    final storage = SessionStorage()..token = null;
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SettingsScreen())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings offers no language entry', (tester) async {
    await mountSettings(tester);
    final list = find.byType(ListView).first;
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    await tester.drag(list, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
  });
}
