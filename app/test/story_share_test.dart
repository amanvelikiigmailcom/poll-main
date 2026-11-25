import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flyprox_app/services/story_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/like_story');
  final png = Uint8List.fromList([137, 80, 78, 71]);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  for (final target in [
    StoryShareTarget.instagram,
    StoryShareTarget.snapchat,
  ]) {
    test(
      '$target sends actual PNG to the native editor, never a caption/website only',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'shareStory');
              expect(call.arguments['target'], target.name);
              expect(call.arguments['png'], png);
              return 'opened';
            });
        final service = StoryShareService(
          channel: channel,
          share: (_) async => throw StateError('Unexpected fallback'),
        );
        expect(
          await service.share(png: png, target: target),
          StoryShareOutcome.opened,
        );
      },
    );
  }
  for (final target in StoryShareTarget.values) {
    test(
      '$target falls back with an attached PNG, no private text and no false publication claim',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => 'unavailable');
        final service = StoryShareService(
          channel: channel,
          share: (params) async {
            expect(params.text, isNull);
            expect(await params.files!.single.readAsBytes(), png);
            expect(params.files!.single.mimeType, 'image/png');
            return const ShareResult('test', ShareResultStatus.success);
          },
        );
        expect(
          await service.share(png: png, target: target),
          StoryShareOutcome.shareMenu,
        );
      },
    );
  }
  test(
    'cancelled, unavailable, failed and empty shares do not report success',
    () async {
      for (final entry in [
        (ShareResultStatus.dismissed, StoryShareOutcome.dismissed),
        (ShareResultStatus.unavailable, StoryShareOutcome.failed),
      ]) {
        final service = StoryShareService(
          share: (_) async => ShareResult('', entry.$1),
        );
        expect(
          await service.share(png: png, target: StoryShareTarget.tiktok),
          entry.$2,
        );
      }
      final failed = StoryShareService(
        share: (_) async => throw StateError('Failure'),
      );
      expect(
        await failed.share(png: png, target: StoryShareTarget.tiktok),
        StoryShareOutcome.failed,
      );
      expect(
        await failed.share(png: Uint8List(0), target: StoryShareTarget.tiktok),
        StoryShareOutcome.failed,
      );
    },
  );
}
