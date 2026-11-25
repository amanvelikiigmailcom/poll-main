import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Where a result screenshot should be shared.
enum StoryShareTarget { instagram, snapchat }

/// What happened after a share attempt.
enum StoryShareOutcome { shared, failed }

/// Shares a result screenshot to stories.
///
/// Instagram opens its story composer directly through the native
/// `instagram-stories://share` handoff (screenshot on the pasteboard).
/// Snapchat exposes no public direct-story API, so it goes through the
/// system share sheet with the image attached, where Snapchat is one of
/// the targets. The share sheet is also the fallback when Instagram is
/// missing or the native handoff fails.
class StoryShareService {
  StoryShareService({
    MethodChannel? channel,
    Future<Directory> Function()? tempDir,
    Future<void> Function(XFile file, String text, Rect? origin)? shareFiles,
  }) : _channel = channel ?? const MethodChannel('flyprox/story_share'),
       _tempDir = tempDir ?? _systemTemp,
       _shareFiles = shareFiles ?? _platformShare;

  final MethodChannel _channel;
  final Future<Directory> Function() _tempDir;
  final Future<void> Function(XFile file, String text, Rect? origin)
  _shareFiles;

  static Future<Directory> _systemTemp() =>
      Directory.systemTemp.createTemp('flyprox_share');

  static Future<void> _platformShare(
    XFile file,
    String text,
    Rect? origin,
  ) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [file], text: text, sharePositionOrigin: origin),
    );
    if (result.status == ShareResultStatus.unavailable) {
      throw StateError('Share unavailable');
    }
  }

  /// Captures the [RepaintBoundary] behind [key] as PNG bytes.
  /// Returns null when the boundary is not mounted.
  Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 2}) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio.clamp(1, 3));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// Shares [png] to [target] with [caption], falling back to the system
  /// share sheet when the direct handoff is unavailable.
  Future<StoryShareOutcome> share({
    required Uint8List png,
    required StoryShareTarget target,
    required String caption,
    Rect? sharePositionOrigin,
  }) async {
    if (png.isEmpty) return StoryShareOutcome.failed;
    if (target == StoryShareTarget.instagram) {
      try {
        final result = await _channel.invokeMethod<String>(
          'shareInstagramStory',
          {'png': png},
        );
        if (result == 'shared') return StoryShareOutcome.shared;
      } catch (_) {
        // Fall through to the share sheet below.
      }
    }
    try {
      final dir = await _tempDir();
      final file = File(
        '${dir.path}/flyprox-result-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      await _shareFiles(
        XFile(file.path, mimeType: 'image/png', name: 'flyprox-result.png'),
        caption,
        sharePositionOrigin,
      );
      return StoryShareOutcome.shared;
    } catch (_) {
      return StoryShareOutcome.failed;
    }
  }
}
