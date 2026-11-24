import 'fakes/eligible_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/university_catalog.dart';
import 'package:flyprox_app/widgets/common/university_picker_field.dart';

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await UniversityCatalog.load();
  });

  test('official directory covers all states with unique institution IDs',
      () async {
    final schools = await UniversityCatalog.load();
    expect(schools.length, greaterThan(3500));
    expect(schools.map((s) => s.id).toSet().length, schools.length);
    final states = schools.map((s) => s.state).toSet();
    expect(
        states,
        containsAll(
            'AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY PR GU'
                .split(' ')));
    expect(schools.where((s) => s.name == 'Harvard University'), hasLength(1));
    expect(
        schools
            .where((s) => s.matches('ucla'))
            .any((s) => s.name == 'University of California-Los Angeles'),
        isTrue);
    expect(schools.where((s) => s.matches('stanford california')), isNotEmpty);
    expect(schools.where((s) => s.matches('harvard cambridge')), isNotEmpty);
  });

  testWidgets('search, select, cancel and clear university', (tester) async {
    final controller =
        TextEditingController(text: 'Previously entered university');
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: UniversityPickerField(
                controller: controller,
                onChanged: (value) => selected = value))));
    await tester.tap(find.byKey(const Key('university-picker-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('university-search')), 'no-such-university-zzzz');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'No universities found. Try a different name, city or state.'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('university-search')), 'Stanford');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stanford University'));
    await tester.pumpAndSettle();
    expect(selected, 'Stanford University');
    expect(controller.text, 'Stanford University');
    await tester.tap(find.byKey(const Key('university-picker-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Stanford University');
    await tester.tap(find.byKey(const Key('university-picker-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No university selected'));
    await tester.pumpAndSettle();
    expect(selected, '');
    expect(controller.text, '');
  });

  testWidgets('server editor does not expose or overwrite the legacy local university',
      (tester) async {
    final game = LocalGameService.instance;
    await game.savePlayerAndFriends(
        playerName: 'Player', friends: ['Alex', 'Sam', 'Jordan']);
    await game.saveFullName('Player', 'Smith');
    await game.saveUsername('player_123');
    await game.saveUniversity('Harvard University');
    final storage = StorageService();
    await storage.init();
    testAppRouter.go(AppRoutes.profile);
    await tester.pumpWidget(ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp.router(routerConfig: testAppRouter),
    ));
    await tester.pumpAndSettle();
    testAppRouter.push(AppRoutes.editProfile);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to edit your profile.'), findsOneWidget);
    expect(find.byKey(const Key('university-picker-field')), findsNothing);
    expect(find.text('Harvard University'), findsNothing);
    expect(await game.getUniversity(), 'Harvard University');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(testAppRouter.routeInformationProvider.value.uri.path, AppRoutes.profile);
    expect(await game.getUniversity(), 'Harvard University');
    await tester.pumpWidget(const SizedBox());
  });
}
