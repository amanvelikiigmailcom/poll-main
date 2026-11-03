import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

const _slides = [
  (
    eyebrow: 'A NEW WAY TO PLAY',
    title: 'Who’s most\nlikely to…?',
    description:
        'Light up the room? Make everyone laugh?\nPick the person who fits best.',
  ),
  (
    eyebrow: 'BETTER WITH YOUR PEOPLE',
    title: 'Make it\nyour circle.',
    description:
        'Add your name and three people you know.\nThey don’t need the app to be in your quiz.',
  ),
  (
    eyebrow: 'A LITTLE PLAY. A LITTLE JOY.',
    title: 'Play. Collect.\nRepeat.',
    description:
        'Answer 12 questions, collect your stars,\nand come back for a fresh round.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final hasNames = await LocalGameService.instance.hasEnoughNames();
      await storage.saveOnboardingDone();
      if (!mounted) return;
      context.go(hasNames ? AppRoutes.home : AppRoutes.namesEntry);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Couldn’t save your progress. Try again.')),
      );
    }
  }

  void _goTo(int page) {
    if (_saving) return;
    _controller.animateToPage(
      page,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlue,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, Color(0xFF364FC7)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 16, 0),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFFFFD878)),
                      const SizedBox(width: 5),
                      const Expanded(
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Flyprox',
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.7)))),
                      TextButton(
                        onPressed: _saving ? null : _finish,
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 48)),
                        child:
                            const Text('Skip', style: TextStyle(fontSize: 14)),
                      ),
                    ]),
                  ),
                  Expanded(
                      child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (_, index) => _IntroPage(index: index),
                  )),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        SizedBox(
                            width: 48,
                            height: 48,
                            child: _page == 0
                                ? null
                                : IconButton(
                                    tooltip: 'Back',
                                    onPressed:
                                        _saving ? null : () => _goTo(_page - 1),
                                    icon: const Icon(Icons.arrow_back_rounded,
                                        color: Colors.white),
                                  )),
                        Expanded(
                            child: Semantics(
                          liveRegion: true,
                          label: 'Page ${_page + 1} of ${_slides.length}',
                          child: ExcludeSemantics(
                              child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                _slides.length,
                                (index) => AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      width: _page == index ? 24 : 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                              alpha: _page == index ? 1 : 0.35),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    )),
                          )),
                        )),
                        SizedBox(
                            width: 48,
                            child: Text('${_page + 1} / 3',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12))),
                      ]),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () => last ? _finish() : _goTo(_page + 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlueDark,
                          disabledBackgroundColor: Colors.white70,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_saving)
                                  const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                else ...[
                                  Flexible(
                                      child: Text(last ? 'Get started' : 'Next',
                                          textAlign: TextAlign.center)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 19),
                                ],
                              ]),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final slide = _slides[index];
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 490;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ExcludeSemantics(
                child: MediaQuery.withNoTextScaling(
                    child: SizedBox(
              height: compact ? 195 : 300,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                    width: 340,
                    height: 300,
                    child: switch (index) {
                      0 => const _PollIllustration(),
                      1 => const _CircleIllustration(),
                      _ => const _StarsIllustration(),
                    }),
              ),
            ))),
            const SizedBox(height: 18),
            Text(slide.eyebrow,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFFFE4A3),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            const SizedBox(height: 14),
            Semantics(
                header: true,
                child: Text(slide.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 34 : 40,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -1.4))),
            const SizedBox(height: 16),
            Text(slide.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFE4EAFF), fontSize: 15, height: 1.6)),
            const SizedBox(height: 20),
          ]),
        ),
      );
    });
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2830449C),
                  blurRadius: 30,
                  offset: Offset(0, 16))
            ]),
        child: child,
      );
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.icon,
      required this.label,
      this.color = const Color(0xFFFFE5A6)});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1830449C),
                  blurRadius: 16,
                  offset: Offset(0, 6))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _PollIllustration extends StatelessWidget {
  const _PollIllustration();

  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        Transform.rotate(
            angle: -0.09,
            child: Container(
                width: 265,
                height: 236,
                decoration: BoxDecoration(
                    color: const Color(0xFF91A6FF),
                    borderRadius: BorderRadius.circular(26)))),
        Positioned(
            top: 22,
            left: 35,
            right: 35,
            child: _Paper(
                child: Column(children: [
              const Text('THE GOOD VIBES ROUND',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Who lights up\nevery room?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 23,
                      height: 1.15,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              for (final row in [
                ['Alex', 'You'],
                ['Sam', 'Jamie']
              ])
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: row
                          .map((name) => Expanded(
                                  child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: name == 'Sam'
                                        ? AppColors.primaryBlue
                                        : const Color(0xFFF0F3FF),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (name == 'Sam') ...[
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.white, size: 14),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(name,
                                          style: TextStyle(
                                              color: name == 'Sam'
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                              )))
                          .toList(),
                    )),
            ]))),
        const Positioned(
            bottom: 5,
            right: 5,
            child: _Badge(
                icon: Icons.auto_awesome_rounded, label: 'Good vibes only')),
      ]);
}

class _CircleIllustration extends StatelessWidget {
  const _CircleIllustration();

  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24))),
        Container(
            width: 155,
            height: 155,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24))),
        const Positioned(
            top: 20,
            left: 113,
            width: 114,
            child: _PersonCard(
                name: 'Alex',
                initial: 'A',
                color: Color(0xFFFFDDAE),
                angle: -0.09)),
        const Positioned(
            top: 116,
            left: 16,
            width: 114,
            child: _PersonCard(
                name: 'Sam',
                initial: 'S',
                color: Color(0xFFE1D7FF),
                angle: -0.12)),
        const Positioned(
            top: 116,
            right: 16,
            width: 114,
            child: _PersonCard(
                name: 'Jamie',
                initial: 'J',
                color: Color(0xFFC7ECDD),
                angle: 0.12)),
        const Positioned(
            bottom: 10,
            left: 113,
            width: 114,
            child: _PersonCard(
                name: 'You',
                initial: 'Y',
                color: Color(0xFFD9E2FF),
                angle: 0.05)),
        const Positioned(
            top: 147,
            child: Icon(Icons.favorite_rounded,
                color: Color(0xFFFFD878), size: 34)),
      ]);
}

class _PersonCard extends StatelessWidget {
  const _PersonCard(
      {required this.name,
      required this.initial,
      required this.color,
      required this.angle});
  final String name;
  final String initial;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: _Paper(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text(initial,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Text(name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ])),
      );
}

class _StarsIllustration extends StatelessWidget {
  const _StarsIllustration();

  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        Transform.rotate(
            angle: 0.10,
            child: Container(
                width: 236,
                height: 232,
                decoration: BoxDecoration(
                    color: const Color(0xFF91A6FF),
                    borderRadius: BorderRadius.circular(26)))),
        Positioned(
          top: 25,
          left: 53,
          right: 53,
          child: _Paper(
              color: const Color(0xFFFFFAEE),
              child: Column(children: [
                const Text('ROUND COMPLETE',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Transform.rotate(
                    angle: -math.pi / 14,
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFFFBD3D),
                        size: 100,
                        shadows: [
                          Shadow(
                              color: Color(0x40E49300),
                              offset: Offset(0, 6),
                              blurRadius: 14)
                        ])),
                Text('+${LocalGameService.starsPerRound}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5)),
                const Text('a little well-earned sparkle',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ])),
        ),
        const Positioned(
            top: 2,
            left: 19,
            child: Icon(Icons.auto_awesome_rounded,
                size: 42, color: Color(0xFFFFDE8E))),
        const Positioned(
            right: 10,
            bottom: 65,
            child:
                Icon(Icons.star_rounded, size: 35, color: Color(0xFFFFDE8E))),
        const Positioned(
            bottom: 7,
            left: 35,
            child: _Badge(
                icon: Icons.check_circle_outline_rounded,
                label: '12 questions. You did it.',
                color: Color(0xFFDDF4E8))),
      ]);
}
