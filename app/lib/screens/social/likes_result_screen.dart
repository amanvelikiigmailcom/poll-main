import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import 'received_likes_screen.dart';

/// Details of one received vote, opened from a Like card.
///
/// Shows only what the server returns for the vote: the question and the
/// vote time. The voter stays anonymous; the API never sends names or
/// identity hints, so this screen promises no reveal.
class LikesResultScreen extends ConsumerWidget {
  const LikesResultScreen({super.key, this.like});

  final Map<String, dynamic>? like;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final like = this.like;
    final occurred = like == null
        ? null
        : DateTime.tryParse(
            like['occurredAt'] is String ? like['occurredAt'] as String : '',
          );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B4B), Color(0xFF1A2E6C), Color(0xFF2D4BA8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: like == null
              ? const Center(
                  child: Text(
                    'Like not found.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Back button and title
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Vote details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Heart animation / icon
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Someone picked you!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Info card
                      _InfoCard(
                        question: like['question'] as String? ?? '',
                        timeLabel: occurred == null
                            ? ''
                            : likeTimeAgo(occurred.toLocal(), DateTime.now()),
                      ),
                      const SizedBox(height: 20),
                      // Anonymous voter section
                      _AnonymousCard(),
                      const SizedBox(height: 20),
                      // Voting circle from this device
                      _CircleSection(
                        question: like['question'] as String? ?? '',
                      ),
                      const SizedBox(height: 20),
                      // Share section
                      const _ShareSection(),
                      const SizedBox(height: 20),
                      // Reveal opens the paywall; it never reveals the voter.
                      const _RevealButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.question, required this.timeLabel});

  final String question;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.help_outline,
            label: 'Question',
            value: question,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Time',
            value: timeLabel,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Anonymous voter card
// ---------------------------------------------------------------------------

class _AnonymousCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voter',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Anonymous voter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The voter stays anonymous.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Share section
// ---------------------------------------------------------------------------

class _ShareSection extends StatelessWidget {
  const _ShareSection();

  Future<void> _openInstagram(BuildContext context) async {
    final uri = Uri.parse('https://www.instagram.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open Instagram')),
        );
      }
    }
  }

  Future<void> _openTikTok(BuildContext context) async {
    final uri = Uri.parse('https://www.tiktok.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open TikTok')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ShareButton(
                label: 'Instagram',
                icon: _InstagramIcon(),
                onTap: () => _openInstagram(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShareButton(
                label: 'TikTok',
                icon: _TikTokIcon(),
                onTap: () => _openTikTok(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social media icons (custom painted)
// ---------------------------------------------------------------------------

class _InstagramIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _InstagramPainter()),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(rect, paint);

    // Camera circle
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.27,
      paint,
    );

    // Dot top-right
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.24),
      size.width * 0.07,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TikTokIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _TikTokPainter()),
    );
  }
}

class _TikTokPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Musical note-like TikTok shape (simplified)
    final path = Path();
    // Vertical bar
    path.moveTo(size.width * 0.38, size.height * 0.85);
    path.lineTo(size.width * 0.38, size.height * 0.25);
    // Curve to the right forming the top "flag"
    path.quadraticBezierTo(
      size.width * 0.38,
      size.height * 0.12,
      size.width * 0.70,
      size.height * 0.18,
    );
    path.lineTo(size.width * 0.70, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.55,
      size.height * 0.30,
      size.width * 0.55,
      size.height * 0.45,
    );
    path.lineTo(size.width * 0.55, size.height * 0.72);

    canvas.drawPath(path, paint);

    // Bottom circle (note head)
    canvas.drawCircle(
      Offset(size.width * 0.30, size.height * 0.78),
      size.width * 0.15,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.47, size.height * 0.66),
      size.width * 0.13,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Voting circle (names saved on this device)
// ---------------------------------------------------------------------------

/// The four contacts the user votes with, loaded from local game storage.
///
/// The server never sends vote participants, so this section shows only
/// on-device data and labels it as such. A storage failure shows the empty
/// state instead of invented names.
class _CircleSection extends StatefulWidget {
  const _CircleSection({required this.question});

  final String question;

  @override
  State<_CircleSection> createState() => _CircleSectionState();
}

class _CircleSectionState extends State<_CircleSection> {
  List<String>? _names;
  String? _pick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<String> names = const [];
    String? pick;
    try {
      final game = LocalGameService.instance;
      names = await game.selectedOptions();
      final answers = [
        ...await game.getRoundAnswers(),
        ...await game.getRoundAnswers(completed: true),
      ];
      for (final answer in answers) {
        if (answer.question == widget.question && answer.choice != null) {
          pick = answer.choice;
          break;
        }
      }
    } catch (_) {
      names = const [];
      pick = null;
    }
    if (mounted) {
      setState(() {
        _names = names;
        _pick = pick;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your voting circle',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'People you vote with on this device.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (names == null)
          const SizedBox(height: 8)
        else if (names.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: const Text(
              'Play a round to see your voting circle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          )
        else
          for (final name in names)
            _CircleCard(name: name, isPick: name == _pick),
      ],
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.name, required this.isPick});

  final String name;
  final bool isPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF4B6EF5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('🙂', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          if (isPick)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4B6EF5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Your pick',
                style: TextStyle(
                  color: Color(0xFF4B6EF5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reveal button (paywall entry only)
// ---------------------------------------------------------------------------

/// Opens the Premium paywall. It never reveals the voter by itself.
class _RevealButton extends StatelessWidget {
  const _RevealButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.premium),
        icon: const Icon(Icons.lock_outline),
        label: const Text('Find out who voted for you'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A2E6C),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
