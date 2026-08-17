import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

class StarReceivedScreen extends StatefulWidget {
  const StarReceivedScreen({super.key});

  @override
  State<StarReceivedScreen> createState() => _StarReceivedScreenState();
}

class _StarReceivedScreenState extends State<StarReceivedScreen>
    with TickerProviderStateMixin {
  // Flat reward for finishing a local 12-question round
  static const int _starsEarned = 1000;

  late AnimationController _starBounceController;
  late AnimationController _contentFadeController;
  late AnimationController _sparkleController;

  late Animation<double> _starScale;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;
  late Animation<double> _sparkleAnim;

  int _displayedCount = 0;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();

    _starBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _contentFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _starScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_starBounceController);

    _contentFade = CurvedAnimation(
      parent: _contentFadeController,
      curve: Curves.easeOut,
    );

    _contentSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentFadeController, curve: Curves.easeOut),
    );

    _sparkleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  void _startSequence() async {
    HapticFeedback.heavyImpact();
    await _starBounceController.forward();
    if (!mounted) return;
    _contentFadeController.forward();
    _startCountAnimation();
  }

  void _startCountAnimation() {
    const steps = 30;
    const stepDuration = Duration(milliseconds: 50);
    int step = 0;
    _countTimer = Timer.periodic(stepDuration, (t) {
      step++;
      final value =
          (_starsEarned * step / steps).round().clamp(0, _starsEarned);
      if (mounted) setState(() => _displayedCount = value);
      if (step >= steps) t.cancel();
    });
  }

  @override
  void dispose() {
    _starBounceController.dispose();
    _contentFadeController.dispose();
    _sparkleController.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A237E), // deep indigo
              Color(0xFF283593),
              Color(0xFF4B6EF5), // brand blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _sparkleAnim,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _sparkleAnim.value,
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text('✨', style: TextStyle(fontSize: 18)),
                                  Text('⭐', style: TextStyle(fontSize: 14)),
                                  Text('✨', style: TextStyle(fontSize: 22)),
                                  Text('⭐', style: TextStyle(fontSize: 14)),
                                  Text('✨', style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        ScaleTransition(
                          scale: _starScale,
                          child: const Text(
                            '⭐',
                            style: TextStyle(fontSize: 88),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+$_displayedCount',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'звёздочек получено!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        AnimatedBuilder(
                          animation: _contentFadeController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _contentFade.value,
                              child: Transform.translate(
                                offset: Offset(0, _contentSlide.value),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    const _SummaryItem(
                                      emoji: '🗳️',
                                      label: 'Вопросов',
                                      value: '12',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white24,
                                    ),
                                    const _SummaryItem(
                                      emoji: '✅',
                                      label: 'Ответов',
                                      value: '10',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white24,
                                    ),
                                    _SummaryItem(
                                      emoji: '⭐',
                                      label: 'Звёзд',
                                      value: '+$_starsEarned',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Nice round. These answers stay on your device.\nNobody else sees who you picked.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white60,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.timer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Продолжить'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.invite),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Share Hidavo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _SummaryItem({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }
}
