import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flyprox_app/services/story_share_service.dart';

const _channelName = 'flyprox/story_share';
const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final createdDirs = <String>[];
  MethodCall? lastCall;
  Object? channelResult;
  Object? channelError;

  setUp(() {
    lastCall = null;
    channelResult = 'shared';
    channelError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_channelName), (call) async {
          lastCall = call;
          if (channelError != null) throw channelError!;
          return channelResult;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_channelName), null);
    for (final path in createdDirs) {
      try {
        await Directory(path).delete(recursive: true);
      } catch (_) {}
    }
    createdDirs.clear();
  });

  Future<Directory> tempDir() async {
    final dir = await Directory.systemTemp.createTemp('flyprox_share_test');
    createdDirs.add(dir.path);
    return dir;
  }

  late List<(XFile, String)> shared;
  StoryShareService service() {
    shared = [];
    return StoryShareService(
      tempDir: tempDir,
      shareFiles: (file, text, _) async {
        shared.add((file, text));
      },
    );
  }

  testWidgets('capture renders the boundary as PNG bytes', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox(width: 40, height: 30),
          ),
        ),
      ),
    );
    // Engine image capture needs real async; without runAsync the tester
    // never completes toImage().
    final png = await tester.runAsync(() => StoryShareService().capture(key));
    expect(png, isNotNull);
    expect(png!.take(8).toList(), _pngMagic);
  });

  test('capture of an unmounted boundary returns null', () async {
    expect(await StoryShareService().capture(GlobalKey()), isNull);
  });

  test('instagram direct handoff skips the share sheet', () async {
    final outcome = await service().share(
      png: Uint8List.fromList([1, 2, 3]),
      target: StoryShareTarget.instagram,
      caption: 'caption',
    );
    expect(outcome, StoryShareOutcome.shared);
    expect(lastCall?.method, 'shareInstagramStory');
    final args = lastCall!.arguments as Map;
    expect((args['png'] as Uint8List).toList(), [1, 2, 3]);
    expect(shared, isEmpty);
  });

  test(
    'instagram unavailable falls back to a PNG file on the share sheet',
    () async {
      channelResult = 'unavailable';
      final png = Uint8List.fromList(List.generate(32, (i) => i));
      final outcome = await service().share(
        png: png,
        target: StoryShareTarget.instagram,
        caption: 'My Flyprox result',
      );
      expect(outcome, StoryShareOutcome.shared);
      expect(shared, hasLength(1));
      final (file, text) = shared.single;
      expect(text, 'My Flyprox result');
      expect(file.mimeType, 'image/png');
      expect(file.name, matches(RegExp(r'^flyprox-result-\d+\.png$')));
      expect(await File(file.path).readAsBytes(), png);
    },
  );

  test('instagram channel error falls back instead of failing', () async {
    channelError = PlatformException(code: 'boom');
    final outcome = await service().share(
      png: Uint8List.fromList([9]),
      target: StoryShareTarget.instagram,
      caption: 'caption',
    );
    expect(outcome, StoryShareOutcome.shared);
    expect(shared, hasLength(1));
  });

  test('snapchat goes straight to the share sheet', () async {
    final outcome = await service().share(
      png: Uint8List.fromList([7]),
      target: StoryShareTarget.snapchat,
      caption: 'caption',
    );
    expect(outcome, StoryShareOutcome.shared);
    expect(lastCall, isNull);
    expect(shared, hasLength(1));
  });

  test('share sheet failure reports failed', () async {
    final failing = StoryShareService(
      tempDir: tempDir,
      shareFiles: (_, _, _) => throw StateError('no sheet'),
    );
    final outcome = await failing.share(
      png: Uint8List.fromList([7]),
      target: StoryShareTarget.snapchat,
      caption: 'caption',
    );
    expect(outcome, StoryShareOutcome.failed);
  });

  test('empty bytes fail without touching the channel', () async {
    final outcome = await service().share(
      png: Uint8List(0),
      target: StoryShareTarget.instagram,
      caption: 'caption',
    );
    expect(outcome, StoryShareOutcome.failed);
    expect(lastCall, isNull);
    expect(shared, isEmpty);
  });
}
