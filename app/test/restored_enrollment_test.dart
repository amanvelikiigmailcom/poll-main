import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/test_app.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_phone_auth_driver.dart';

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  for (final scenario in [('CALIFORNIA', 2030), ('TEXAS', 2025)]) {
    testWidgets(
      'existing ${scenario.$1}/${scenario.$2} account retains enrollment after sign-in',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ContentService.instance.debugClear();
        final storage = StorageService();
        await storage.init();
        final api = ApiService(storage);
        final driver = FakePhoneAuthDriver();
        final phone = PhoneAuthService(
          api: api,
          storage: storage,
          driver: driver,
        );
        final service = OnboardingDetailsService(api, storage);
        final requests = <RequestOptions>[];
        final enrollment = <String, dynamic>{
          'firstName': 'Alex',
          'lastName': 'Smith',
          'gender': 'male',
          'profileComplete': true,
          'country': 'US',
          'status': 'selected',
          'graduationYear': scenario.$2,
          'school': {
            'id': 'US-CCD-existing',
            'name': 'Existing High',
            'city': 'Fresno',
            'region': scenario.$1,
            'country': 'US',
          },
          'campusChangeUsed': false,
          'votingAllowed': true,
        };
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (req, h) {
              requests.add(req);
              if (req.path == '/api/auth/firebase') {
                h.resolve(
                  Response(
                    requestOptions: req,
                    data: <String, dynamic>{
                      'token': 'reinstalled-fixture-session',
                      'isNewUser': false,
                    },
                  ),
                );
                return;
              }
              if (req.path == '/api/social/me') {
                h.resolve(
                  Response(
                    requestOptions: req,
                    data: {'username': 'original_handle'},
                  ),
                );
                return;
              }
              if (req.path == '/api/onboarding') {
                if (req.method == 'PUT' &&
                    req.data['step'] == 'school' &&
                    req.data['graduationYear'] !=
                        enrollment['graduationYear']) {
                  h.reject(
                    DioException(
                      requestOptions: req,
                      type: DioExceptionType.badResponse,
                      response: Response(
                        requestOptions: req,
                        statusCode: 409,
                        data: <String, dynamic>{
                          'message':
                              'Change your campus and graduation year in Edit profile.',
                        },
                      ),
                    ),
                  );
                  return;
                }
                h.resolve(Response(requestOptions: req, data: enrollment));
                return;
              }
              h.resolve(
                Response(requestOptions: req, data: <String, dynamic>{}),
              );
            },
          ),
        );
        testAppRouter.go(
          AppRoutes.otp,
          extra: {
            'phone': '+16505550137',
            'verificationId': 'vid-1',
            'country': 'US',
          },
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              apiServiceProvider.overrideWithValue(api),
              phoneAuthServiceProvider.overrideWithValue(phone),
              onboardingDetailsProvider.overrideWith((ref) => service),
            ],
            child: MaterialApp.router(routerConfig: testAppRouter),
          ),
        );
        for (var tick = 0; tick < 8; tick++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final pin = tester.widget<Pinput>(find.byType(Pinput)).controller!;
        pin.text = '012345';
        for (var tick = 0; tick < 8; tick++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (driver.confirmCalls == 0) {
          await tester.ensureVisible(find.text('Verify'));
          await tester.tap(find.text('Verify'));
          for (var tick = 0; tick < 8; tick++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        expect(driver.confirmCalls, 1);
        expect(OnboardingFlow.instance.phoneComplete, isTrue);
        expect(find.text('About you'), findsNothing);
        expect(find.text('Choose your campus'), findsNothing);
        expect(find.byKey(const Key('onboarding-username')), findsNothing);
        expect((await service.read())['status'], 'selected');
        expect((await service.read())['graduationYear'], scenario.$2);
        expect(
          requests.where(
            (r) => r.path == '/api/onboarding' && r.method == 'PUT',
          ),
          isEmpty,
        );
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.home,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test(
    'server enrollment confirmation is session-scoped and cannot be seeded by a draft',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveToken('account-a');
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                data: <String, dynamic>{
                  'status': 'selected',
                  'country': 'US',
                  'graduationYear': 2025,
                  'school': {'id': 'existing-campus'},
                },
              ),
            );
          },
        ),
      );
      final service = OnboardingDetailsService(api, storage);
      addTearDown(service.dispose);
      await service.draft({
        'status': 'selected',
        'school': {'id': 'forged-campus'},
        'graduationYear': 2025,
      });
      expect(
        await service.isConfirmedCampus('forged-campus', year: 2025),
        isFalse,
      );
      await service.restore();
      expect(
        await service.isConfirmedCampus('existing-campus', year: 2025),
        isTrue,
      );
      expect(
        await service.isConfirmedCampus('existing-campus', year: 2026),
        isFalse,
      );
      await storage.saveToken('account-b');
      expect(
        await service.isConfirmedCampus('existing-campus', year: 2025),
        isFalse,
      );
    },
  );
}
