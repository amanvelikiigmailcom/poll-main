import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../services/game_settings.dart';

/// Optional bundled intro. Missing or failed video never blocks launch.
class StartupIntro extends StatefulWidget {
  const StartupIntro({super.key, required this.onComplete});
  final VoidCallback onComplete;
  static const asset = 'assets/animations/flyprox-intro.mp4';
  @override
  State<StartupIntro> createState() => _StartupIntroState();
}

class _StartupIntroState extends State<StartupIntro>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Timer? _deadline;
  bool _finished = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = !GameSettings.instance.sound || kIsWeb;
    _start();
  }

  Future<void> _start() async {
    _deadline = Timer(const Duration(seconds: 7), _finish);
    if (GameSettings.instance.haptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    try {
      if (GameSettings.instance.effectiveReduceMotion) {
        _deadline?.cancel();
        _deadline = Timer(const Duration(milliseconds: 600), _finish);
        return;
      }
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!mounted || _finished) return;
      if (!manifest.listAssets().contains(StartupIntro.asset)) {
        _deadline?.cancel();
        _deadline = Timer(const Duration(milliseconds: 600), _finish);
        return;
      }
      final video = VideoPlayerController.asset(StartupIntro.asset,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _video = video;
      await video.initialize();
      if (!mounted || _finished) return;
      await video.setVolume(_muted ? 0 : 1);
      if (!mounted || _finished) return;
      video.addListener(_watchVideo);
      setState(() {});
      await video.play();
    } catch (_) {
      _finish();
    }
  }

  void _watchVideo() {
    final value = _video?.value;
    if (value == null) return;
    if (value.hasError ||
        (value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >= value.duration)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _deadline?.cancel();
    _video?.removeListener(_watchVideo);
    _video?.pause();
    widget.onComplete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _video?.removeListener(_watchVideo);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      backgroundColor: const Color(0xFF4B6EF5),
      body: Stack(fit: StackFit.expand, children: [
        if (video != null && video.value.isInitialized)
          Center(
              child: AspectRatio(
                  aspectRatio: video.value.aspectRatio,
                  child: VideoPlayer(video)))
        else
          Center(
              child: Image.asset('assets/images/flyprox-logo.png',
                  width: 112, height: 112, semanticLabel: 'Flyprox logo')),
        SafeArea(
            child: Align(
                alignment: Alignment.topRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (video != null && video.value.isInitialized)
                    IconButton(
                        tooltip: _muted ? 'Turn sound on' : 'Mute',
                        color: Colors.white,
                        icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                        onPressed: () async {
                          final muted = !_muted;
                          setState(() => _muted = muted);
                          try {
                            await video.setVolume(muted ? 0 : 1);
                            await GameSettings.instance
                                .setOption('sound', !muted);
                          } catch (_) {
                            _finish();
                          }
                        }),
                  TextButton(
                      onPressed: _finish,
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Skip')),
                  const SizedBox(width: 8),
                ]))),
      ]),
    );
  }
}
