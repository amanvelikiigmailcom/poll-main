import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/notification_preferences_service.dart';
import 'package:flyprox_app/screens/settings/notifications_settings_screen.dart';
import 'fakes/fake_secure_storage.dart';

void main() {
  setUp(() {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> mount(
    WidgetTester tester, {
    bool fail = false,
    double scale = 1,
  }) async {
    final storage = StorageService();
    await storage.init();
    await storage.saveToken('owner');
    final api = ApiService(storage);
    var settings = {for (final key in notificationCategories.keys) key: true};
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          if (r.method == 'PUT' && fail) {
            h.reject(
              DioException(
                requestOptions: r,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: r,
                  statusCode: 503,
                  data: {'message': 'Unavailable'},
                ),
              ),
            );
            return;
          }
          if (r.method == 'PUT') {
            settings = Map<String, bool>.from(r.data['preferences'] as Map);
          }
          h.resolve(
            Response(requestOptions: r, data: {'preferences': settings}),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          notificationPreferencesProvider.overrideWith(
            (ref) => NotificationPreferencesService(
              api,
              storage,
              timezone: () async => 'UTC',
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const NotificationsSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real preferences render and are saved only after server acknowledgement',
    (tester) async {
      await mount(tester);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('notification-votes')))
            .value,
        true,
      );
      await tester.tap(find.byKey(const Key('notification-votes')));
      await tester.scrollUntilVisible(
        find.text('Save'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Notification settings saved'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('notification-votes')))
            .value,
        false,
      );
    },
  );
  testWidgets(
    'failed save keeps the edited choice and does not display success',
    (tester) async {
      await mount(tester, fail: true);
      await tester.tap(find.byKey(const Key('notification-votes')));
      await tester.scrollUntilVisible(
        find.text('Save'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Notification settings saved'), findsNothing);
      expect(
        find.textContaining('Your changes are still here'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('notification-votes')))
            .value,
        false,
      );
    },
  );
  testWidgets('preferences fit 320px with large text and remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, scale: 2);
    await tester.scrollUntilVisible(
      find.text('Save'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
