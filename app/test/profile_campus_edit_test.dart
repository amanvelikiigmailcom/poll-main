import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/profile/profile_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'fakes/social_storage.dart';

void main() {
  testWidgets(
    'profile shows campus once and has one edit entry for all profile fields',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalGameService.instance.saveUsername('old_name');
      final storage = SessionStorage();
      await storage.init();
      final api = ApiService(storage);
      final campusWrites = <Map<String, dynamic>>[];
      const oldCampus = {
        'id': 'US-CCD-1',
        'name': 'Central High',
        'city': 'Austin',
        'region': 'Texas',
        'country': 'US',
      };
      const newCampus = {
        'id': 'US-CCD-2',
        'name': 'West Campus',
        'city': 'Dallas',
        'region': 'Texas',
        'country': 'US',
      };
      var campus = oldCampus;
      var currentHandle = 'old_name';
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            Map<String, dynamic> reply = {};
            var status = 200;
            switch (request.path) {
              case '/api/social/me':
                reply = {
                  'username': currentHandle,
                  'firstName': 'Alex',
                  'lastName': 'Smith',
                  'votesReceived': 2,
                };
              case '/api/social/handle':
                final handle = request.data['username'] as String;
                if (handle == 'taken') {
                  status = 409;
                  reply = {
                    'message': 'This username is taken. Choose another.',
                  };
                } else {
                  currentHandle = handle.toLowerCase();
                  reply = {'username': handle.toLowerCase()};
                }
              case '/api/schools':
                reply = {
                  'schools': [newCampus],
                  'available': true,
                };
              case '/api/onboarding':
                if (request.method == 'PUT') {
                  expect(
                    request.headers['Authorization'],
                    'Bearer first-account',
                  );
                  campusWrites.add(
                    Map<String, dynamic>.from(request.data as Map),
                  );
                  campus = newCampus;
                }
                reply = {
                  'status': 'selected',
                  'country': 'US',
                  'school': campus,
                  'campusChangeUsed': campusWrites.isNotEmpty,
                  'graduationYear': DateTime.now().year,
                };
            }
            final response = Response<Map<String, dynamic>>(
              requestOptions: request,
              data: reply,
              statusCode: status,
            );
            if (status != 200) {
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: request,
                  response: response,
                ),
              );
            } else {
              handler.resolve(response);
            }
          },
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: AppRoutes.editProfile,
            builder: (_, _) =>
                const Scaffold(body: Text('Profile editor destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            apiServiceProvider.overrideWithValue(api),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      expect(find.text('@old_name'), findsOneWidget);
      expect(find.textContaining('Central High'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Edit username'), findsNothing);
      expect(campusWrites, isEmpty);
      await tap('Edit profile');
      expect(find.text('Profile editor destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'profile keeps a 32-character username on one line without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      const handle = 'abcdefghij1234567890abcdefghij12';
      final storage = SessionStorage();
      await storage.init();
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              data: request.path == '/api/social/me'
                  ? {
                      'username': handle,
                      'firstName': 'Alex',
                      'lastName': 'Smith',
                      'votesReceived': 0,
                    }
                  : <String, dynamic>{},
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            apiServiceProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@$handle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
