import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum StoryShareTarget { instagram, snapchat, tiktok }

enum StoryShareOutcome { opened, shareMenu, dismissed, failed }

/// "Opened" means handed to an editor, never proof of publication.
class StoryShareService {
  StoryShareService({
    MethodChannel? channel,
    Future<ShareResult> Function(ShareParams)? share,
  }) : _channel = channel ?? const MethodChannel('flyprox/story_share'),
       _share = share ?? SharePlus.instance.share;

  final MethodChannel _channel;
  final Future<ShareResult> Function(ShareParams) _share;

  Future<Uint8List?> capture(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<StoryShareOutcome> share({
    required Uint8List png,
    required StoryShareTarget target,
    Rect? origin,
  }) async {
    if (png.isEmpty) return StoryShareOutcome.failed;
    if (target != StoryShareTarget.tiktok) {
      try {
        final result = await _channel.invokeMethod<String>('shareStory', {
          'target': target.name,
          'png': png,
        });
        if (result == 'opened') return StoryShareOutcome.opened;
      } on PlatformException {
        // App absent, unconfigured or rejected: use the real image share menu.
      } on MissingPluginException {
        // Unsupported platform / native bridge not installed.
      }
    }
    try {
      final result = await _share(
        ShareParams(
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: 'flyprox-like.png',
            ),
          ],
          fileNameOverrides: ['flyprox-like.png'],
          sharePositionOrigin: origin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.dismissed => StoryShareOutcome.dismissed,
        ShareResultStatus.unavailable => StoryShareOutcome.failed,
        ShareResultStatus.success => StoryShareOutcome.shareMenu,
      };
    } catch (_) {
      return StoryShareOutcome.failed;
    }
  }
}
