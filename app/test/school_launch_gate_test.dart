import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/config/school_launch.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/test_app.dart';

Map<String, dynamic> school({
  String id = 'US-CCD-1',
  String name = 'Central High',
  String city = 'Austin',
  String region = 'TEXAS',
  String country = 'US',
}) => {
  'id': id,
  'name': name,
  'city': city,
  'region': region,
  'country': country,
};

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
  });
  tearDown(() => ContentService.instance.debugClear());

  group('SchoolLaunch.isOpen', () {
    test('opens exactly one region per directory country', () {
      expect(SchoolLaunch.isOpen(school(region: 'TEXAS')), isTrue);
      expect(
        SchoolLaunch.isOpen(school(region: 'West Midlands', country: 'GB')),
        isTrue,
      );
      expect(SchoolLaunch.isOpen(school(region: 'ONTARIO', country: 'CA')), isTrue);
      expect(SchoolLaunch.isOpen(school(region: 'Auckland', country: 'NZ')), isTrue);
      expect(SchoolLaunch.isOpen(school(region: 'Central', country: 'SG')), isTrue);
      expect(
        SchoolLaunch.isOpen(school(region: 'Hong Kong Island', country: 'HK')),
        isTrue,
      );
    });

    test('accepts US private-school codes and ignores case or padding', () {
      expect(SchoolLaunch.isOpen(school(region: 'TX')), isTrue);
      expect(SchoolLaunch.isOpen(school(region: '  texas ')), isTrue);
      expect(SchoolLaunch.isOpen(school(region: 'Tx')), isTrue);
      expect(
        SchoolLaunch.isOpen(school(region: 'west midlands', country: 'GB')),
        isTrue,
      );
    });

    test('closes every other region', () {
      expect(SchoolLaunch.isOpen(school(region: 'CALIFORNIA')), isFalse);
      expect(SchoolLaunch.isOpen(school(region: 'CA')), isFalse);
      expect(SchoolLaunch.isOpen(school(region: 'Manchester', country: 'GB')), isFalse);
      expect(SchoolLaunch.isOpen(school(region: 'Quebec', country: 'CA')), isFalse);
      expect(SchoolLaunch.isOpen(school(region: '', country: 'GB')), isFalse);
    });

    test('gates by the row country and fails open on unknown countries', () {
      expect(
        SchoolLaunch.isOpen(school(region: 'ONTARIO', country: 'CA')),
        isTrue,
      );
      expect(SchoolLaunch.isOpen(school(region: 'ONTARIO')), isFalse);
      expect(SchoolLaunch.isOpen(school(region: 'Anywhere', country: 'XX')), isTrue);
    });

    test('team test campus stays open outside launch regions', () {
      final byId = school(
        id: 'US-CCD-010033001264',
        name: 'New Horizon Alternative School',
        city: 'Bessemer',
        region: 'ALABAMA',
      );
      expect(SchoolLaunch.isTestSchool(byId), isTrue);
      expect(SchoolLaunch.isOpen(byId), isTrue);
      final byName = school(
        id: 'US-CCD-changed-after-reimport',
        name: 'new horizon alternative school',
        city: 'Bessemer',
        region: 'AL',
      );
      expect(SchoolLaunch.isTestSchool(byName), isTrue);
      expect(SchoolLaunch.isOpen(byName), isTrue);
    });

    test('other Alabama campuses stay closed', () {
      expect(
        SchoolLaunch.isOpen(
          school(name: 'Bessemer High', city: 'Bessemer', region: 'ALABAMA'),
        ),
        isFalse,
      );
      expect(
        SchoolLaunch.isOpen(
          school(
            name: 'New Horizon Alternative School',
            city: 'Anaheim',
            region: 'CALIFORNIA',
          ),
        ),
        isFalse,
      );
    });

    test('closed message names the school, open region and support email', () {
      final message = SchoolLaunch.closedMessage(
        country: 'US',
        schoolName: 'West High',
        email: 'support@flyprox.com',
      );
      expect(message, contains('West High'));
      expect(message, contains('Texas'));
      expect(message, contains('support@flyprox.com'));
    });
  });

  Future<void> mount(
    WidgetTester tester, {
    required List<Map<String, dynamic>> results,
    Map<String, dynamic>? preseed,
  }) async {
    final storage = StorageService();
    await storage.init();
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (req, handler) => handler.resolve(
          Response(
            requestOptions: req,
            data: req.path == '/api/schools'
                ? {'schools': results, 'available': true, 'nextCursor': ''}
                : <String, dynamic>{},
          ),
        ),
      ),
    );
    final service = OnboardingDetailsService(api, storage);
    if (preseed != null) await service.draft(preseed);
    testAppRouter.go(AppRoutes.profileDetails);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          onboardingDetailsProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp.router(routerConfig: testAppRouter),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> profile(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('onboarding-first-name')),
      'Aman',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-last-name')),
      'Smith',
    );
    await tester.ensureVisible(find.text('Non-binary'));
    await tester.tap(find.text('Non-binary'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byKey(const Key('school-search')), term);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'closed-region campus shows the support dialog and stays unselected',
    (tester) async {
      await mount(
        tester,
        results: [school(name: 'West High', region: 'CALIFORNIA')],
      );
      await profile(tester);
      await search(tester, 'West');
      await tester.ensureVisible(find.text('West High'));
      await tester.tap(find.text('West High'));
      await tester.pumpAndSettle();
      expect(find.text('Campus not available yet'), findsOneWidget);
      expect(find.textContaining('support@flyprox.com'), findsOneWidget);
      expect(find.textContaining('Selected:'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Campus not available yet'), findsNothing);
      expect(find.textContaining('Selected:'), findsNothing);
    },
  );

  testWidgets('open-region campus selects normally', (tester) async {
    await mount(
      tester,
      results: [school(name: 'Central High', region: 'TEXAS')],
    );
    await profile(tester);
    await search(tester, 'Central');
    await tester.ensureVisible(find.text('Central High'));
    await tester.tap(find.text('Central High'));
    await tester.pumpAndSettle();
    expect(find.text('Campus not available yet'), findsNothing);
    expect(find.textContaining('Selected: Central High'), findsOneWidget);
  });

  testWidgets('team test campus selects normally outside launch regions', (
    tester,
  ) async {
    await mount(
      tester,
      results: [
        school(
          id: 'US-CCD-010033001264',
          name: 'New Horizon Alternative School',
          city: 'Bessemer',
          region: 'ALABAMA',
        ),
      ],
    );
    await profile(tester);
    await search(tester, 'Horizon');
    await tester.ensureVisible(find.text('New Horizon Alternative School'));
    await tester.tap(find.text('New Horizon Alternative School'));
    await tester.pumpAndSettle();
    expect(find.text('Campus not available yet'), findsNothing);
    expect(
      find.textContaining('Selected: New Horizon Alternative School'),
      findsOneWidget,
    );
  });

  testWidgets(
    'restored closed-region selection still hits the gate on continue',
    (tester) async {
      final closed = school(name: 'West High', region: 'CALIFORNIA');
      await mount(
        tester,
        results: [closed],
        preseed: {'school': closed, 'graduationYear': 2030, 'country': 'US'},
      );
      await profile(tester);
      expect(find.textContaining('Selected: West High'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Campus not available yet'), findsOneWidget);
      expect(find.textContaining('support@flyprox.com'), findsOneWidget);
      expect(find.text('Add your contacts'), findsNothing);
    },
  );
}
