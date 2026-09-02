import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const Color _accentRed = Color(0xFFFF3B5C);

// ---------------------------------------------------------------------------
// Motivation quotes shown while waiting
// ---------------------------------------------------------------------------
const List<String> _motivationQuotes = [
  '"Real stars shine even when no one watches"',
  '"Every vote is a small sign of respect. Collect them!"',
  '"Those who wait get twice as much"',
  '"New round soon. Get ready to surprise your friends!"',
  '"Best moments come to those who wait"',
];

// ---------------------------------------------------------------------------
// Animated circular progress painter
// ---------------------------------------------------------------------------
class _ArcPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    // Foreground arc
    final arcPaint = Paint()
      ..shader = LinearGradient(
        colors: [arcColor, arcColor.withValues(alpha: 0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}

// ---------------------------------------------------------------------------
// TimerScreen
// ---------------------------------------------------------------------------
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  static const int _totalSeconds = 2400; // 40 minutes
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the timer ring glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade animation for quote rotations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // Rotate quotes every 8 seconds
    Timer.periodic(const Duration(seconds: 8), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _motivationQuotes.length;
        });
        _fadeController.forward();
      });
    });

    // Main countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) context.go('/vote');
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsLeft / _totalSeconds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildTimerRing(),
                const SizedBox(height: 40),
                _buildQuoteCard(),
                const SizedBox(height: 28),
                _buildInviteSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _accentRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Break between rounds',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Next round in...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTimerRing() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.25 * _pulseAnim.value),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow track
            CustomPaint(
              size: const Size(220, 220),
              painter: _ArcPainter(
                progress: _progress,
                trackColor: const Color(0xFFDDE4FF),
                arcColor: _primaryBlue,
                strokeWidth: 14,
              ),
            ),
            // Inner white circle
            Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'min : sec',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFEEF0FF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💬', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _motivationQuotes[_quoteIndex],
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF444466),
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Skip timer instantly!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Invite a friend and start next round instantly',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.push('/invite'),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Invite a friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => context.go('/home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryBlue,
            side: const BorderSide(color: Color(0xFFDDE4FF), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Go home'),
        ),
      ],
    );
  }
}
