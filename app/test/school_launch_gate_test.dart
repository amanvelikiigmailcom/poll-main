import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/registration/school_setup_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/test_app.dart';

const campus = {
  'id': 'US-CCD-1',
  'name': 'Closed Campus',
  'country': 'US',
  'region': 'CALIFORNIA',
  'city': 'Los Angeles',
  'enrollmentAvailable': false,
};
void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'closed campus selection reaches persistent waiting after the server saves it',
    (tester) async {
      final storage = StorageService();
      await storage.init();
      await storage.saveToken('ordinary');
      final api = ApiService(storage);
      var saves = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'PUT') saves++;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': 'waiting',
                  'country': 'US',
                  'school': campus,
                  'graduationYear': 2030,
                  'votingAllowed': false,
                  'campusAvailable': false,
                },
              ),
            );
          },
        ),
      );
      final service = OnboardingDetailsService(api, storage);
        await service.draft({
        'status': 'pending',
        'stage': 'school',
        'country': 'US',
        'school': campus,
        'graduationYear': 2030,
      });
      final router = GoRouter(
        initialLocation: AppRoutes.schoolSetup,
        routes: [
          GoRoute(
            path: AppRoutes.schoolSetup,
            builder: (_, _) => const SchoolSetupScreen(),
          ),
          GoRoute(
            path: AppRoutes.schoolWaiting,
            builder: (_, _) => const SchoolWaitingScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            apiServiceProvider.overrideWithValue(api),
            onboardingDetailsProvider.overrideWith((ref) => service),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skip for now'), findsNothing);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Your campus isn’t available yet'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Check availability'), findsOneWidget);
      expect(await service.votingAllowed(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'waiting account is redirected from Home and a direct voting link',
    (tester) async {
      final storage = StorageService();
      await storage.init();
      final api = ApiService(storage);
      final service = OnboardingDetailsService(api, storage);
        await service.draft({
        'status': 'waiting',
        'stage': 'waiting',
        'country': 'US',
        'school': campus,
        'graduationYear': 2030,
      });
      testAppRouter.go(AppRoutes.home);
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
      expect(testAppRouter.state.uri.path, AppRoutes.schoolWaiting);
      testAppRouter.go(AppRoutes.vote);
      await tester.pumpAndSettle();
      expect(testAppRouter.state.uri.path, AppRoutes.schoolWaiting);
      expect(find.text('Your campus isn’t available yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
