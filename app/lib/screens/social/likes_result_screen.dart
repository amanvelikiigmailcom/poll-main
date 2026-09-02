import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);

class LikesResultScreen extends ConsumerWidget {
  const LikesResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: SingleChildScrollView(
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
                      'Детали голоса',
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
                    'За тебя проголосовали!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Info card
                _InfoCard(),
                const SizedBox(height: 20),
                // Locked name section
                _LockedNameCard(),
                const SizedBox(height: 20),
                // Premium upsell card
                _PremiumCard(),
                const SizedBox(height: 28),
                // Share section
                const _ShareSection(),
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
        children: const [
          _InfoRow(
            icon: Icons.school_outlined,
            label: 'Класс',
            value: '10 класса',
          ),
          SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Пол',
            value: 'Девочка',
          ),
          SizedBox(height: 16),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Время',
            value: 'Час назад',
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
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Locked name card
// ---------------------------------------------------------------------------

class _LockedNameCard extends StatelessWidget {
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
            'Имя',
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
                        'Александра К.',
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
            'Узнайте имя',
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
// Premium upsell card
// ---------------------------------------------------------------------------

class _PremiumCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C3FE4), Color(0xFF4B6EF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FE4).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Premium',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Оформите подписку чтобы узнать имя',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Откройте имена всех, кто проголосовал за вас',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6C3FE4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Открыть имя',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          const SnackBar(content: Text('Instagram не установлен')),
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
          const SnackBar(content: Text('TikTok не установлен')),
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
          'Поделиться',
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
