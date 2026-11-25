import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/invite_code_store.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/widgets/common/invitation_links.dart';

import 'fakes/fake_secure_storage.dart';
import 'fakes/http_adapter.dart';

void main() {
  setUp(() {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
  });

  Future<
    ({StreamController<Uri> links, GoRouter router, TestHttpAdapter adapter})
  >
  mount(WidgetTester tester, String location) async {
    final storage = StorageService();
    await storage.init();
    final api = ApiService(storage);
    final adapter = TestHttpAdapter(
      (request) async => ResponseBody.fromString('{}', 200),
    );
    api.dio.httpClientAdapter = adapter;
    final links = StreamController<Uri>.broadcast();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final path in [
          '/otp',
          '/vote',
          '/age',
          AppRoutes.phone,
          AppRoutes.invitationCode,
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: TextField(key: ValueKey(path))),
          ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await links.close();
      router.dispose();
      api.dio.close(force: true);
      storage.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => InvitationLinks(
            linkStream: links.stream,
            router: router,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (links: links, router: router, adapter: adapter);
  }

  for (final path in ['/otp', '/vote', '/age']) {
    testWidgets('warm link preserves $path and its in-progress input', (
      tester,
    ) async {
      final env = await mount(tester, path);
      await tester.enterText(find.byType(TextField), 'unfinished');
      env.links.add(Uri.parse('https://api.flyprox.com/i/ABC234'));
      await tester.pumpAndSettle();
      expect(env.router.routeInformationProvider.value.uri.path, path);
      expect(find.text('unfinished'), findsOneWidget);
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(await InviteCodeStore.accepted(), isFalse);
      expect(env.adapter.requests.map((r) => r.path), ['/i/ABC234/events']);
      expect(env.adapter.requests.single.data, {'type': 'app_open_with_code'});
    });
  }

  testWidgets(
    'link on phone screen opens attribution, never claims automatically',
    (tester) async {
      final env = await mount(tester, AppRoutes.phone);
      env.links.add(Uri.parse('https://api.flyprox.com/i/ABC234'));
      await tester.pumpAndSettle();
      expect(
        env.router.routeInformationProvider.value.uri.path,
        AppRoutes.invitationCode,
      );
      expect(await InviteCodeStore.accepted(), isFalse);
      expect(
        env.adapter.requests.any((r) => r.path.endsWith('/claim')),
        isFalse,
      );
      env.links.add(Uri.parse('https://api.flyprox.com/i/DEF678'));
      await tester.pumpAndSettle();
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(env.adapter.requests, hasLength(1));
    },
  );

  testWidgets('foreign and malformed links never persist or navigate', (
    tester,
  ) async {
    final env = await mount(tester, AppRoutes.phone);
    for (final raw in [
      'https://evil.example/i/ABC234',
      'https://api.flyprox.com.evil.example/i/ABC234',
      'http://api.flyprox.com/i/ABC234',
      'https://api.flyprox.com/i/O0I123',
      'https://api.flyprox.com/i/ABC234/extra',
    ]) {
      env.links.add(Uri.parse(raw));
      await tester.pumpAndSettle();
    }
    expect(env.router.routeInformationProvider.value.uri.path, AppRoutes.phone);
    expect(await InviteCodeStore.code(), isNull);
    expect(env.adapter.requests, isEmpty);
  });

  testWidgets('offline observation does not lose an invitation', (
    tester,
  ) async {
    final env = await mount(tester, '/otp');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextField)),
    );
    final api = container.read(apiServiceProvider);
    api.dio.httpClientAdapter = TestHttpAdapter((request) async {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    });
    env.links.add(Uri.parse('https://api.flyprox.com/i/ABC234'));
    await tester.pumpAndSettle();
    expect(await InviteCodeStore.code(), 'ABC234');
    expect(env.router.routeInformationProvider.value.uri.path, '/otp');
  });
}
