import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/service_providers.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';

// ---------------------------------------------------------------------------
// Data model for a single onboarding slide
// ---------------------------------------------------------------------------

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.emoji,
    required this.emojiSize,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.accentColor,
  });

  final String emoji;
  final double emojiSize;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Color accentColor;
}

// ---------------------------------------------------------------------------
// Static slide definitions (strings kept here; swap for AppLocalizations once
// the l10n build step is wired up in CI)
// ---------------------------------------------------------------------------

const List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    emoji: '🏃‍♂️🏃‍♀️',
    emojiSize: 90,
    title: 'Vote anonymously',
    description:
        'Answer fun questions about classmates — no one will know it is you. Full anonymity guaranteed.',
    gradientColors: [Color(0xFF4B6EF5), Color(0xFF7B9BFF)],
    accentColor: Color(0xFF4B6EF5),
  ),
  _OnboardingSlide(
    emoji: '🤝',
    emojiSize: 100,
    title: 'No negativity',
    description:
        'Only positive questions that bring your class together. Safe and friendly for everyone.',
    gradientColors: [Color(0xFF43B89C), Color(0xFF7FD9C4)],
    accentColor: Color(0xFF43B89C),
  ),
  _OnboardingSlide(
    emoji: '💃',
    emojiSize: 100,
    title: 'Anonymous feed',
    description:
        'See who got voted in class feed — collect stars and rise to the top.',
    gradientColors: [Color(0xFFAB47BC), Color(0xFFCE93D8)],
    accentColor: Color(0xFFAB47BC),
  ),
  _OnboardingSlide(
    emoji: '🎉',
    emojiSize: 100,
    title: 'Invite your friends',
    description:
        'More friends — more fun! Invite classmates and unlock full Hidavo experience.',
    gradientColors: [Color(0xFFFF3B5C), Color(0xFFFF8A80)],
    accentColor: Color(0xFFFF3B5C),
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(storageServiceProvider).saveOnboardingDone();
    if (mounted) context.go(AppRoutes.phone);
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── PageView ────────────────────────────────────────────────────
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) =>
                  _OnboardingPage(slide: _slides[index]),
            ),

            // ── Skip button ─────────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: AnimatedOpacity(
                opacity: isLast ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: isLast ? null : _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom controls ─────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomControls(
                currentPage: _currentPage,
                totalPages: _slides.length,
                pageController: _pageController,
                accentColor: slide.accentColor,
                isLast: isLast,
                onNext: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single onboarding page
// ---------------------------------------------------------------------------

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final heroHeight = size.height * 0.52;

    return Column(
      children: [
        // ── Hero area ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: heroHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: slide.gradientColors,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: heroHeight * 0.3,
                right: 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),

              // App name badge
              Positioned(
                top: topPadding + 16,
                left: 24,
                child: const Text(
                  'Hidavo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),

              // Central emoji illustration
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    // Emoji card
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          slide.emoji,
                          style: TextStyle(fontSize: slide.emojiSize),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: const Duration(milliseconds: 300)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Text content ─────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                )
                    .animate()
                    .slideX(
                      begin: 0.15,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    )
                    .fadeIn(duration: const Duration(milliseconds: 350)),

                const SizedBox(height: 14),

                Text(
                  slide.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                )
                    .animate()
                    .slideX(
                      begin: 0.15,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      delay: const Duration(milliseconds: 60),
                    )
                    .fadeIn(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 60),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom controls — dots + CTA button
// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.pageController,
    required this.accentColor,
    required this.isLast,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final PageController pageController;
  final Color accentColor;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress dots
          SmoothPageIndicator(
            controller: pageController,
            count: totalPages,
            effect: ExpandingDotsEffect(
              activeDotColor: accentColor,
              dotColor: const Color(0xFFE5E7EB),
              dotHeight: 8,
              dotWidth: 8,
              expansionFactor: 3,
              spacing: 5,
            ),
          ),

          const Spacer(),

          // Next / Start button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLast
                    ? [AppColors.accentRed, const Color(0xFFFF6B87)]
                    : [accentColor, accentColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (isLast ? AppColors.accentRed : accentColor)
                      .withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNext,
                borderRadius: BorderRadius.circular(28),
                splashColor: Colors.white24,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLast ? 28 : 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          isLast ? 'Start' : 'Next',
                          key: ValueKey<bool>(isLast),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
