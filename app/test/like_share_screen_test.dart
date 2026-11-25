import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/models/received_vote.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/like_share_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'package:flyprox_app/services/story_share_service.dart';
import 'fakes/social_storage.dart';

Map<String, dynamic> _data() => {
  'id': 'v1',
  'question': 'Who makes everyone smile?',
  'voterGender': 'female',
  'graduationYear': 2029,
  'name': 'SECRET VOTER',
  'voterId': 'SECRET_ID',
  'participants': [
    {'name': 'Aman', 'graduationYear': 2030},
    {'name': 'Alina', 'graduationYear': 2028},
  ],
};

class _Social extends SocialService {
  _Social(super.api, super.storage);
  int calls = 0;
  final paths = <String>[];
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    calls++;
    paths.add(path);
    expect(path, startsWith('/likes/'));
    if (fail) throw StateError('Blocked or unavailable');
    final id = Uri.decodeComponent(path.split('/').last);
    return pending?.future ??
        {
          ..._data(),
          'id': id,
          if (id == 'v2') 'question': 'Who gives great advice?',
        };
  }
}

class _Share extends StoryShareService {
  final targets = <StoryShareTarget>[];
  bool noImage = false;
  @override
  Future<Uint8List?> capture(GlobalKey key) async =>
      noImage ? null : Uint8List.fromList([1, 2]);
  @override
  Future<StoryShareOutcome> share({
    required Uint8List png,
    required StoryShareTarget target,
    Rect? origin,
  }) async {
    targets.add(target);
    return StoryShareOutcome.opened;
  }
}

Future<(_Social, SessionStorage, _Share)> _mount(
  WidgetTester tester, {
  bool fail = false,
}) async {
  final storage = SessionStorage();
  final social = _Social(ApiService(storage), storage)..fail = fail;
  final share = _Share();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        socialServiceProvider.overrideWithValue(social),
      ],
      child: MaterialApp(
        home: LikeShareScreen(voteId: 'v1', storyShare: share),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (social, storage, share);
}

void main() {
  testWidgets(
    'received Like preview uses backend question, cohort and candidates, never hidden identity',
    (tester) async {
      await _mount(tester);
      expect(find.text('Someone picked me'), findsOneWidget);
      expect(find.text('Who makes everyone smile?'), findsOneWidget);
      expect(find.text('From a girl · Class of 2029'), findsOneWidget);
      expect(find.text('Aman · 2030'), findsOneWidget);
      expect(find.text('Alina · 2028'), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      for (final label in ['Instagram', 'Snapchat', 'TikTok']) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  for (final target in StoryShareTarget.values) {
    testWidgets('$target reauthorizes the received vote before image handoff', (
      tester,
    ) async {
      final (social, _, share) = await _mount(tester);
      final button = find.text(switch (target) {
        StoryShareTarget.instagram => 'Instagram',
        StoryShareTarget.snapchat => 'Snapchat',
        StoryShareTarget.tiktok => 'TikTok',
      });
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(social.calls, 2);
      expect(share.targets, [target]);
    });
  }
  testWidgets(
    'server failure never falls back to stale route data; retry works',
    (tester) async {
      final (social, _, _) = await _mount(tester, fail: true);
      expect(find.text('Someone picked me'), findsNothing);
      social.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Someone picked me'), findsOneWidget);
    },
  );
  testWidgets('new block or revoked access prevents sharing', (tester) async {
    final (social, _, share) = await _mount(tester);
    social.fail = true;
    await tester.ensureVisible(find.text('Instagram'));
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(share.targets, isEmpty);
    expect(find.text('Someone picked me'), findsNothing);
  });
  testWidgets('repeated taps while reauthorizing produce a single handoff', (
    tester,
  ) async {
    final (social, _, share) = await _mount(tester);
    social.pending = Completer();
    final button = find.text('Instagram');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(social.calls, 2);
    social.pending!.complete(_data());
    await tester.pumpAndSettle();
    expect(share.targets, [StoryShareTarget.instagram]);
  });

  testWidgets('missing capture prevents a social handoff and offers retry', (
    tester,
  ) async {
    final (_, _, share) = await _mount(tester);
    share.noImage = true;
    await tester.ensureVisible(find.text('Instagram'));
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(share.targets, isEmpty);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets(
    'account change clears the preview and ignores an in-flight share recheck',
    (tester) async {
      final (social, storage, share) = await _mount(tester);
      social.pending = Completer();
      await tester.ensureVisible(find.text('Instagram'));
      await tester.tap(find.text('Instagram'));
      await tester.pump();
      await storage.clearToken();
      social.pending!.complete(_data());
      await tester.pumpAndSettle();
      expect(find.text('Someone picked me'), findsNothing);
      expect(share.targets, isEmpty);
    },
  );
  testWidgets(
    'story capture is 1080x1920 and excludes the UI controls and hidden identity',
    (tester) async {
      final vote = ReceivedVote.fromJson(_data());
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FittedBox(
              child: RepaintBoundary(
                key: key,
                child: LikeStoryCard(vote: vote),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final png = await tester.runAsync(() => StoryShareService().capture(key));
      expect(png, isNotNull);
      final header = ByteData.sublistView(png!);
      expect(header.getUint32(16), 1080);
      expect(header.getUint32(20), 1920);
      expect(find.text('Instagram'), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
    },
  );
  testWidgets('small phones and long questions produce no layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: FittedBox(
            child: LikeStoryCard(
              vote: ReceivedVote.fromJson({
                ..._data(),
                'question': List.filled(30, 'A very long question').join(' '),
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a new vote ID refreshes the preview rather than sharing the previous result',
    (tester) async {
      final (social, storage, share) = await _mount(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            socialServiceProvider.overrideWithValue(social),
          ],
          child: MaterialApp(
            home: LikeShareScreen(voteId: 'v2', storyShare: share),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(social.paths, ['/likes/v1', '/likes/v2']);
      expect(find.text('Who gives great advice?'), findsOneWidget);
      expect(find.text('Who makes everyone smile?'), findsNothing);
    },
  );

  testWidgets('the public story fits all twelve server-snapshot participants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: FittedBox(
            child: LikeStoryCard(
              vote: ReceivedVote.fromJson({
                ..._data(),
                'participants': List.generate(
                  12,
                  (i) => {
                    'name': 'Classmate $i',
                    'graduationYear': 2026 + i % 6,
                  },
                ),
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      expect(find.text('Classmate $i · ${2026 + i % 6}'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
