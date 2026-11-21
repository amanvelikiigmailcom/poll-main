import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/widgets/common/push_listener.dart';
import 'fakes/fake_push_driver.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  testWidgets('existing APNs token syncs at launch and after returning to app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockApiService();
    final driver = FakePushDriver(authorized: true);
    addTearDown(driver.dispose);
    when(() => api.post<void>('/api/devices', data: any(named: 'data')))
        .thenAnswer((_) async => Response<void>(
            requestOptions: RequestOptions(path: '/api/devices')));
    final push = PushService(driver: driver, api: api);

    await tester.pumpWidget(ProviderScope(
      overrides: [pushServiceProvider.overrideWithValue(push)],
      child: const MaterialApp(home: PushListener(child: SizedBox())),
    ));
    await tester.pumpAndSettle();
    verify(() => api.post<void>('/api/devices', data: {
          'token': 'apns-token-1',
          'platform': 'ios',
        })).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    driver.token = 'apns-token-2';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    verify(() => api.post<void>('/api/devices', data: {
          'token': 'apns-token-2',
          'platform': 'ios',
        })).called(1);

    await tester.pumpWidget(const SizedBox());
    clearInteractions(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verifyNever(() => api.post<void>('/api/devices', data: any(named: 'data')));
  });
}
