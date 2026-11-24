import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/home/home_screen.dart';
import 'package:flyprox_app/screens/profile/profile_screen.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';
import 'fakes/social_storage.dart';
import 'fakes/test_app.dart';

void main() {
  setUp(setUpTestApp);
  for (final scale in [1.0, 2.0]) {
    for (final page in ['home', 'profile', 'settings']) {
      testWidgets('$page fits narrow screens at text scale $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final capture = Platform.environment['POLISH_SCREENSHOTS'] == '1';
        if (capture) {
          await tester.runAsync(() async {
            final loader = FontLoader('PolishPreview');
            loader.addFont(
              File(
                '/System/Library/Fonts/Supplemental/Arial.ttf',
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
            await loader.load();
          });
        }

        tester.view.physicalSize = Size(
          capture ? 390 : 320,
          capture ? 844 : 568,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await LocalGameService.instance.savePlayerAndFriends(
          playerName: 'Alex',
          friends: ['Sam', 'Jordan', 'Taylor', 'Morgan'],
        );
        final storage = SessionStorage();
        await storage.init();
        final api = ApiService(storage);
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final data = switch (request.path) {
                '/api/social/me' => <String, dynamic>{
                  'username': 'alex_smith',
                  'firstName': 'Alex',
                  'lastName': 'Smith',
                  'votesReceived': 12,
                },
                '/api/onboarding' => <String, dynamic>{
                  'status': 'selected',
                  'country': 'US',
                  'graduationYear': 2030,
                  'school': {
                    'id': 'campus',
                    'name': 'Central High School',
                    'city': 'Austin',
                    'region': 'Texas',
                  },
                },
                '/api/social/summary' => <String, dynamic>{
                  'friendsCount': 8,
                  'incomingCount': 2,
                },
                _ => <String, dynamic>{},
              };
              handler.resolve(Response(requestOptions: request, data: data));
            },
          ),
        );
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            apiServiceProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await container.read(onboardingDetailsProvider).draft({
          'stage': 'done',
          'status': 'selected',
        });
        final router = GoRouter(
          initialLocation: '/$page',
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp.router(
                theme: capture
                    ? AppTheme.lightTheme.copyWith(
                        textTheme: AppTheme.lightTheme.textTheme.apply(
                          fontFamily: 'PolishPreview',
                        ),
                      )
                    : AppTheme.lightTheme,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (capture && scale == 1) {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/flyprox-polish-$page.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (page == 'home') {
          expect(find.text('People'), findsNothing);
          await tester.scrollUntilVisible(find.text('Collection'), 250);
          expect(tester.takeException(), isNull);
        } else if (page == 'profile') {
          expect(find.text('Edit profile'), findsOneWidget);
          expect(find.textContaining('Central High School'), findsOneWidget);
          expect(find.text('Edit'), findsNothing);
          await tester.ensureVisible(find.text('Share Flyprox'));
          expect(tester.takeException(), isNull);
        } else {
          await tester.scrollUntilVisible(find.text('View my local data'), 300);
          await tester.pumpAndSettle();
          await tester.tap(find.text('View my local data'));
          await tester.pumpAndSettle();
          expect(find.text('Your local data'), findsOneWidget);
          expect(find.text('Copy JSON'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Delete account'), 300);
          await tester.pumpAndSettle();
          expect(find.text('Delete account').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
