import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';

class BeforeVote2Screen extends StatefulWidget {
  const BeforeVote2Screen({super.key});

  @override
  State<BeforeVote2Screen> createState() => _BeforeVote2ScreenState();
}

class _BeforeVote2ScreenState extends State<BeforeVote2Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  static const _steps = [
    _StepData(
      emoji: '👁️',
      color: Color(0xFF4B6EF5),
      title: 'Full anonymity',
      description:
          'No one will know who you voted for. All answers are hidden.',
    ),
    _StepData(
      emoji: '🗳️',
      color: Color(0xFFFF9500),
      title: 'How voting works',
      description:
          'One question — 4 cards: you + three friends (3 friends enough). Pick who fits best.',
    ),
    _StepData(
      emoji: '⭐',
      color: Color(0xFFFFD700),
      title: 'Earn stars',
      description:
          'You get stars each time someone votes for you. Collect them and unlock items.',
    ),
    _StepData(
      emoji: '🔓',
      color: Color(0xFF9B59B6),
      title: 'See who voted',
      description:
          'With Premium you can see who voted for you in each question.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'How it works',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Top illustration
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 40)),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hidavo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'vote anonymously',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text('⭐', style: TextStyle(fontSize: 40)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Steps list
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _steps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final step = _steps[i];
                      return _StepCard(step: step, index: i);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Continue button
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.vote),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final String emoji;
  final Color color;
  final String title;
  final String description;

  const _StepData({
    required this.emoji,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _StepCard extends StatelessWidget {
  final _StepData step;
  final int index;

  const _StepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: step.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: step.color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
