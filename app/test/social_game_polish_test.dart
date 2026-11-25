import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/models/received_vote.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/settings/settings_screen.dart';
import 'package:flyprox_app/screens/social/like_share_screen.dart';
import 'package:flyprox_app/screens/social/social_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';
import 'package:flyprox_app/widgets/common/app_shell.dart';
import 'fakes/social_storage.dart';
import 'fakes/test_app.dart';

ThemeData _theme() {
  final theme = AppTheme.lightTheme;
  if (Platform.environment['POLISH_SCREENSHOTS'] != '1') return theme;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamily: 'PolishPreview',
      fontFamilyFallback: ['EmojiPreview'],
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'PolishPreview',
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          theme.textButtonTheme.style?.textStyle
              ?.resolve({})
              ?.copyWith(fontFamily: 'PolishPreview'),
        ),
      ),
    ),
  );
}

// Deterministic fixtures, not a screenshot of a signed-in production account.
class _Social extends SocialService {
  _Social(super.api, super.storage);
  final hidden = <String>{};
  final reports = <String>[];
  final searches = <String>[];
  final people = [
    {
      'id': 'one',
      'firstName': 'Nursultan',
      'lastName': 'Karimov',
      'username': 'seednursultan7135',
      'relationship': 'incoming',
      'graduationYear': 2030,
    },
    {
      'id': 'two',
      'firstName': 'Dias',
      'lastName': 'Saparov',
      'username': 'seeddiasf312',
      'relationship': 'outgoing',
      'graduationYear': 2030,
    },
    {
      'id': 'three',
      'firstName': 'Aigerim',
      'lastName': 'Askarova',
      'username': 'aigerim_2030',
      'relationship': 'none',
      'graduationYear': 2030,
    },
  ];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async => path == '/me' ? {'username': 'aman', 'votesReceived': 12} : {};
  @override
  Future<Map<String, dynamic>> suggestions() async => {
    'campus': people.where((p) => !hidden.contains(p['id'])).toList(),
    'friendsOfFriends': [],
  };
  @override
  Future<Map<String, dynamic>> list(String kind, {String? cursor}) async => {
    'users': kind == 'hidden'
        ? people.where((p) => hidden.contains(p['id'])).toList()
        : [],
  };
  @override
  Future<Map<String, dynamic>> search(String username, {String? cursor}) async {
    searches.add(username);
    return {
      'users': [people.first],
    };
  }

  @override
  Future<Map<String, dynamic>> act(String id, String action) async {
    if (action == 'hide') hidden.add(id);
    if (action == 'show') hidden.remove(id);
    return {};
  }

  @override
  Future<Map<String, dynamic>> report(String id, String reason) async {
    reports.add('$id:$reason');
    return {'reported': true};
  }
}

void main() {
  setUp(setUpTestApp);
  Future<(_Social, GoRouter, GlobalKey)> mount(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    final storage = SessionStorage();
    final social = _Social(ApiService(storage), storage);
    final router = GoRouter(
      initialLocation: '/home/search',
      routes: [
        ShellRoute(
          builder: (_, _, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home/search',
              builder: (_, _) => const SocialScreen(page: SocialPage.search),
            ),
            GoRoute(
              path: '/hidden-suggestions',
              builder: (_, _) => const SocialScreen(page: SocialPage.hidden),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          socialServiceProvider.overrideWithValue(social),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: _theme(),
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
    return (social, router, boundary);
  }

  testWidgets(
    'Hide persists across screens; hidden list restores without accepting or declining',
    (tester) async {
      final (social, router, _) = await mount(tester);
      final row = find.byKey(const ValueKey('suggestion-one'));
      final menu = find.descendant(
        of: row,
        matching: find.byType(PopupMenuButton<String>),
      );
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide suggestion'));
      await tester.pumpAndSettle();
      expect(social.hidden, {'one'});
      expect(find.text('Nursultan Karimov'), findsNothing);
      router.go('/hidden-suggestions');
      await tester.pumpAndSettle();
      expect(find.text('Nursultan Karimov'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      expect(social.hidden, isEmpty);
      router.go('/home/search');
      await tester.pumpAndSettle();
      expect(find.text('Nursultan Karimov'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
    },
  );

  testWidgets('restoring a suggestion updates a kept-alive Search tab', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = _Social(ApiService(storage), storage);
    final tab = ValueNotifier(0);
    addTearDown(tab.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          socialServiceProvider.overrideWithValue(social),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (_, index, _) => IndexedStack(
              index: index,
              children: const [
                SocialScreen(page: SocialPage.search),
                SocialScreen(page: SocialPage.hidden),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final menu = find.descendant(
      of: find.byKey(const ValueKey('suggestion-one')),
      matching: find.byType(PopupMenuButton<String>),
    );
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide suggestion'));
    await tester.pumpAndSettle();
    expect(find.text('Nursultan Karimov'), findsNothing);
    tab.value = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    tab.value = 0;
    await tester.pumpAndSettle();
    expect(find.text('Nursultan Karimov'), findsOneWidget);
  });

  testWidgets('full-name search and report reason use actual service actions', (
    tester,
  ) async {
    final (social, _, _) = await mount(tester);
    await tester.enterText(find.byType(TextField), 'Aman Iskakov');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(social.searches, ['Aman Iskakov']);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report account'));
    await tester.pumpAndSettle();
    expect(social.reports, isEmpty);
    await tester.tap(find.text('Spam'));
    await tester.pumpAndSettle();
    expect(social.reports, ['one:spam']);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('named request cards fit 320px at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, scale: scale);
      for (final text in [
        'Nursultan Karimov',
        'Accept',
        'Request sent',
        'Add friend',
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Settings starts with Activity, Friends and Collection before Notifications',
    (tester) async {
      final (_, router, _) = await mount(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      final labels = ['Activity', 'Friends', 'Collection', 'Notifications'];
      final positions = labels
          .map((text) => tester.getTopLeft(find.text(text)).dy)
          .toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    },
  );

  testWidgets(
    'review screenshots of the real widgets with deterministic campus fixtures',
    (tester) async {
      if (Platform.environment['POLISH_SCREENSHOTS'] != '1') return;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final family in ['PolishPreview']) {
          final loader = FontLoader(family);
          for (final file in ['Arial.ttf', 'Arial Bold.ttf']) {
            loader.addFont(
              File(
                '/System/Library/Fonts/Supplemental/$file',
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          }
          await loader.load();
        }
        final emoji = File('/System/Library/Fonts/Apple Color Emoji.ttc');
        if (await emoji.exists()) {
          final loader = FontLoader('EmojiPreview')
            ..addFont(
              emoji.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        }
        for (final entry in {
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          'FlyproxNavRegular': 'assets/fonts/phosphor/flyprox-nav-regular.ttf',
          'FlyproxNavFill': 'assets/fonts/phosphor/flyprox-nav-fill.ttf',
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(rootBundle.load(entry.value));
          await loader.load();
        }
      });
      final (_, router, boundary) = await mount(tester);
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 3);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/opencode/flyprox-$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('search-polish');
      await tester.ensureVisible(find.text('Nursultan Karimov'));
      await capture('search-card-polish');
      router.go('/settings');
      await capture('settings-polish');
      // Fully dispose the scoped router before reusing the capture boundary.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(),
            home: Scaffold(
              body: Center(
                child: FittedBox(
                  child: LikeStoryCard(
                    vote: ReceivedVote.fromJson({
                      'id': 'fixture',
                      'question': 'Who makes everyone smile?',
                      'voterGender': 'female',
                      'graduationYear': 2030,
                      'participants': [
                        for (final name in [
                          'Aman',
                          'Nursultan',
                          'Dias',
                          'Aigerim',
                        ])
                          {'name': name, 'graduationYear': 2030},
                      ],
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await capture('like-result-polish');
      expect(tester.takeException(), isNull);
    },
  );
}
