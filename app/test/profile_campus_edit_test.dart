import 'package:dio/dio.dart';
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
    'profile validates username and confirms one campus change before saving',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalGameService.instance.saveUsername('old_name');
      final storage = SessionStorage();
      await storage.init();
      final api = ApiService(storage);
      final campusWrites = <Map<String, dynamic>>[];
      final handleWrites = <String>[];
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
                handleWrites.add(handle);
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

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tap('@old_name');
      expect(find.text('Edit username'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'bad name');
      await tap('Save username');
      expect(handleWrites, isEmpty);
      await tester.enterText(find.byType(TextFormField), 'taken');
      await tap('Save username');
      expect(
        find.text('This username is taken. Choose another.'),
        findsOneWidget,
      );
      expect(find.text('taken'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'New_Name');
      await tap('Save username');
      expect(find.text('@new_name'), findsOneWidget);

      expect(find.textContaining('Central High'), findsOneWidget);
      await tap('Edit');
      expect(find.textContaining('only once'), findsOneWidget);
      await tap('Cancel');
      expect(campusWrites, isEmpty);
      await tap('Edit');
      await tap('Find a new campus');
      expect(find.text('Skip for now'), findsNothing);
      await tester.enterText(find.byKey(const Key('school-search')), 'West');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tap('West Campus');
      await tap('Save campus');
      expect(
        find.textContaining('From Central High\nTo West Campus'),
        findsOneWidget,
      );
      expect(campusWrites, isEmpty);
      await tap('Confirm change');
      expect(campusWrites.single['confirmChange'], isTrue);
      expect(campusWrites.single['expectedCampusId'], 'US-CCD-1');
      expect(campusWrites.single['schoolId'], 'US-CCD-2');
      expect(find.textContaining('West Campus'), findsOneWidget);
      expect(find.textContaining('Campus change used'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    },
  );
}
