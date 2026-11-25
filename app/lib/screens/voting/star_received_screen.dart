import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/game_settings.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

/// Collect presents a receipt. The server already credited the completed round.
class StarReceivedScreen extends StatefulWidget {
  const StarReceivedScreen({super.key, this.starsAwarded});
  final int? starsAwarded;
  @override
  State<StarReceivedScreen> createState() => _StarReceivedScreenState();
}

class _StarReceivedScreenState extends State<StarReceivedScreen>
    with SingleTickerProviderStateMixin {
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  final _canvas = GlobalKey(), _hero = GlobalKey(), _wallet = GlobalKey();
  Offset _from = Offset.zero, _to = Offset.zero;
  bool _collecting = false, _collected = false, _sessionChanged = false;
  int? _balance;
  ProviderContainer? _scope;
  String? _ownerToken;
  VoidCallback? _storageListener;
  int get _earned => _sessionChanged ? 0 : widget.starsAwarded ?? 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      _scope = ProviderScope.containerOf(context, listen: false);
      final storage = _scope!.read(storageServiceProvider);
      _ownerToken = await storage.getToken();
      if (!mounted) return;
      _storageListener = () async {
        final current = await storage.getToken();
        if (mounted && current != _ownerToken) {
          _flight.stop();
          setState(() {
            _sessionChanged = true;
            _collecting = false;
            _balance = null;
          });
        }
      };
      storage.addListener(_storageListener!);
      final balance = await _scope!.read(starBalanceProvider.future);
      if (mounted && await storage.getToken() == _ownerToken) {
        setState(
          () =>
              _balance = balance != null && balance >= _earned ? balance : null,
        );
      }
    } on StateError {
      _scope = null; // Standalone previews have no provider scope.
      final balance = await LocalGameService.instance.getStars();
      if (mounted && balance >= _earned) setState(() => _balance = balance);
    } catch (_) {
      /* An unknown balance stays unknown. */
    }
  }

  Offset _center(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final canvas = _canvas.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || canvas == null) return Offset.zero;
    return canvas.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  Future<void> _collect() async {
    if (_collecting || _collected || _sessionChanged) return;
    final reduce =
        GameSettings.instance.effectiveReduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    _from = _center(_hero);
    _to = _center(_wallet);
    setState(() => _collecting = true);
    unawaited(GameSettings.instance.rewardFeedback());
    if (!reduce) {
      try {
        await _flight.forward().orCancel;
      } catch (_) {
        return;
      }
    }
    if (!mounted || _sessionChanged) return;
    GameSettings.instance.rewardComplete();
    setState(() {
      _collecting = false;
      _collected = true;
    });
  }

  @override
  void dispose() {
    if (_storageListener != null) {
      _scope?.read(storageServiceProvider).removeListener(_storageListener!);
    }
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primaryBlue,
    body: SafeArea(
      child: Stack(
        key: _canvas,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ROUND COMPLETE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _flight,
                      builder: (context, _) {
                        final progress = _collected
                            ? 1.0
                            : Curves.easeOutCubic.transform(_flight.value);
                        final count =
                            math.max(0, (_balance ?? 0) - _earned) +
                            (_earned * progress).round();
                        return Container(
                          key: _wallet,
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFE8A317),
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _balance == null ? 'Stars' : '$count',
                                    key: const Key('reward-balance'),
                                    style: const TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Container(
                        key: _hero,
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .22),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFFFD66E),
                            size: 126,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _sessionChanged
                            ? 'Account changed'
                            : _collected
                            ? 'Nice work!'
                            : 'You earned it.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _sessionChanged
                            ? 'Open your profile to see your balance.'
                            : widget.starsAwarded == null
                            ? 'Your round is complete.'
                            : '+$_earned',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFD66E),
                          fontSize: _sessionChanged ? 18 : 56,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (!_sessionChanged && widget.starsAwarded != null)
                        const Text(
                          'stars',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _collected
                            ? 'Your stars are safe in your balance.\nPut them to work in Collection.'
                            : '12 questions. One round well played.\nA little something for showing up.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.5,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: math
                          .max(
                            56,
                            52 * MediaQuery.textScalerOf(context).scale(1),
                          )
                          .toDouble(),
                      child: FilledButton(
                        key: const Key('collect-stars'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        onPressed: _collecting
                            ? null
                            : (_collected ||
                                  widget.starsAwarded == null ||
                                  _sessionChanged)
                            ? () => context.go(AppRoutes.timer)
                            : _collect,
                        child: Text(
                          _collecting
                              ? 'Collecting…'
                              : _collected ||
                                    widget.starsAwarded == null ||
                                    _sessionChanged
                              ? 'Continue'
                              : 'Collect $_earned stars',
                        ),
                      ),
                    ),
                    if (_collected ||
                        widget.starsAwarded == null ||
                        _sessionChanged)
                      TextButton(
                        onPressed: () => context.push(AppRoutes.collection),
                        child: const Text(
                          'Collection',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_collecting)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flight,
                  builder: (context, _) => CustomPaint(
                    painter: _StarFlight(_flight.value, _from, _to),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StarFlight extends CustomPainter {
  _StarFlight(this.progress, this.from, this.to);
  final double progress;
  final Offset from, to;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 18; i++) {
      final t = ((progress - i * .018) / .68).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final bend = Offset(
        (i.isEven ? 1 : -1) * (55.0 + i * 3),
        -100 - (i % 4) * 20.0,
      );
      final point =
          Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))! +
          bend * math.sin(math.pi * t);
      final radius = (9 + i % 4) * (1 - .45 * t);
      final path = Path();
      for (var k = 0; k < 10; k++) {
        final angle = -math.pi / 2 + k * math.pi / 5 + t * .8;
        final p =
            point +
            Offset(math.cos(angle), math.sin(angle)) *
                radius *
                (k.isEven ? 1 : .46);
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()..color = const Color(0xFFCA8610),
      );
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFDC73));
    }
  }

  @override
  bool shouldRepaint(_StarFlight oldDelegate) =>
      progress != oldDelegate.progress;
}
