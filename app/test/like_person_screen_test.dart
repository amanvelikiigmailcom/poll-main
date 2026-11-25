import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/screens/social/like_person_screen.dart';
import 'package:flyprox_app/services/story_share_service.dart';
import 'fakes/premium.dart';

const _question = 'Who makes everyone smile?';

Map<String, dynamic> _data({
  String name = 'Rival One',
  bool isPick = true,
  int? graduationYear = 2027,
}) => {
  'name': name,
  'question': _question,
  'isPick': isPick,
  if (graduationYear != null) 'graduationYear': graduationYear,
};

GoRouter _router({Map<String, dynamic>? data, StoryShareService? storyShare}) {
  final router = GoRouter(
    initialLocation: '/person',
    routes: [
      GoRoute(
        path: '/person',
        builder: (_, _) => LikePersonScreen(data: data, storyShare: storyShare),
      ),
      GoRoute(path: '/premium', builder: (_, _) => const Text('Premium stub')),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

/// Screen tests stub the whole share call: engine capture and file I/O
/// both wedge the tester here, and both real paths are covered by
/// story_share_test.dart. This file covers UI wiring only.
class _StubShare extends StoryShareService {
  _StubShare(this.png, {this.outcome = StoryShareOutcome.shared});

  final Uint8List png;
  final StoryShareOutcome outcome;
  final calls = <({Uint8List png, StoryShareTarget target, String caption})>[];

  @override
  Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 2}) async =>
      png;

  @override
  Future<StoryShareOutcome> share({
    required Uint8List png,
    required StoryShareTarget target,
    required String caption,
    Rect? sharePositionOrigin,
  }) async {
    calls.add((png: png, target: target, caption: caption));
    return outcome;
  }
}

Future<void> _mount(
  WidgetTester tester, {
  Map<String, dynamic>? data,
  StoryShareService? storyShare,
}) async {
  await tester.pumpWidget(
    withPremium(
      MaterialApp.router(
        routerConfig: _router(data: data ?? _data(), storyShare: storyShare),
      ),
    ),
  );
}

void main() {
  testWidgets('person shows question, year, share and reveal actions', (
    tester,
  ) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Participant'), findsOneWidget);
    expect(find.text('Rival One'), findsOneWidget);
    expect(find.text('Class of 2027'), findsOneWidget);
    expect(find.text(_question), findsOneWidget);
    expect(find.text('Your pick'), findsOneWidget);
    expect(find.text('Share the result'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Snapchat'), findsOneWidget);
    expect(find.text('TikTok'), findsNothing);
    expect(find.text('Find out who voted for you'), findsOneWidget);
  });

  testWidgets('reveal opens the paywall without revealing the voter', (
    tester,
  ) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    final reveal = find.text('Find out who voted for you');
    await tester.ensureVisible(reveal);
    await tester.pumpAndSettle();
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(find.text('Premium stub'), findsOneWidget);
    expect(find.text('Participant'), findsNothing);
  });

  testWidgets('plain participant hides pick badge and class year', (
    tester,
  ) async {
    await _mount(tester, data: _data(isPick: false, graduationYear: null));
    await tester.pumpAndSettle();
    expect(find.text('Rival One'), findsOneWidget);
    expect(find.text('Your pick'), findsNothing);
    expect(find.textContaining('Class of'), findsNothing);
  });

  testWidgets('missing data shows the not-found state', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(data: null)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Person not found.'), findsOneWidget);
  });

  testWidgets('instagram shares the result screenshot to stories', (
    tester,
  ) async {
    final shot = Uint8List.fromList([1, 2, 3, 4]);
    final storyShare = _StubShare(shot);
    await _mount(tester, storyShare: storyShare);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Instagram'));
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(storyShare.calls, hasLength(1));
    final call = storyShare.calls.single;
    expect(call.png, shot);
    expect(call.target, StoryShareTarget.instagram);
    expect(call.caption, 'My Flyprox result: $_question');
    expect(find.text('Couldn’t open Instagram'), findsNothing);
  });

  testWidgets('snapchat shares the screenshot through the share sheet', (
    tester,
  ) async {
    final shot = Uint8List.fromList([5, 6, 7, 8]);
    final storyShare = _StubShare(shot);
    await _mount(tester, storyShare: storyShare);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Snapchat'));
    await tester.tap(find.text('Snapchat'));
    await tester.pumpAndSettle();
    expect(storyShare.calls, hasLength(1));
    final call = storyShare.calls.single;
    expect(call.png, shot);
    expect(call.target, StoryShareTarget.snapchat);
    expect(call.caption, 'My Flyprox result: $_question');
    expect(find.text('Couldn’t open Snapchat'), findsNothing);
  });

  testWidgets('failed share keeps the user on the screen with a notice', (
    tester,
  ) async {
    final storyShare = _StubShare(
      Uint8List.fromList([9]),
      outcome: StoryShareOutcome.failed,
    );
    await _mount(tester, storyShare: storyShare);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Instagram'));
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open Instagram'), findsOneWidget);
    expect(find.text('Participant'), findsOneWidget);
  });
}
