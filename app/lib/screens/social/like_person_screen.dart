import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';

/// One vote participant, opened by tapping a card in vote details.
///
/// Matches the voting screen: light background, initial avatar, question
/// card, share actions and the reveal entry. The API never sends the
/// voter's identity, so the reveal button only opens the Premium paywall.
class LikePersonScreen extends StatelessWidget {
  const LikePersonScreen({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final name = data?['name'] as String? ?? '';
    final question = data?['question'] as String? ?? '';
    final isPick = data?['isPick'] == true;
    final year = data?['graduationYear'];
    final detail = year is int ? 'Class of $year' : '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: name.isEmpty
            ? const Center(
                child: Text(
                  'Person not found.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Text(
                          'Participant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: generateAvatarColor(name),
                              child: Text(
                                getInitials(name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                detail,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          if (isPick) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Your pick',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _QuestionCard(question: question),
                          const SizedBox(height: 20),
                          const _ShareSection(),
                          const SizedBox(height: 20),
                          const _RevealButton(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question card
// ---------------------------------------------------------------------------

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.help_outline,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Question',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
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

  Future<void> _openSnapchat(BuildContext context) async {
    final uri = Uri.parse('https://www.snapchat.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open Snapchat')),
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
          'Share the result',
          style: TextStyle(
            color: AppColors.textSecondary,
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
                label: 'Snapchat',
                icon: _SnapchatIcon(),
                onTap: () => _openSnapchat(context),
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
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(14),
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

class _SnapchatIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _SnapchatPainter()),
    );
  }
}

class _SnapchatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Ghost outline: domed head, straight sides, wavy hem.
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.86)
      ..lineTo(size.width * 0.22, size.height * 0.48)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.16,
        size.width * 0.5,
        size.height * 0.16,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.16,
        size.width * 0.78,
        size.height * 0.48,
      )
      ..lineTo(size.width * 0.78, size.height * 0.86)
      ..lineTo(size.width * 0.68, size.height * 0.77)
      ..lineTo(size.width * 0.59, size.height * 0.86)
      ..lineTo(size.width * 0.5, size.height * 0.77)
      ..lineTo(size.width * 0.41, size.height * 0.86)
      ..lineTo(size.width * 0.32, size.height * 0.77)
      ..close();
    canvas.drawPath(path, paint);

    // Eyes.
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.41, size.height * 0.45),
      size.width * 0.05,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.59, size.height * 0.45),
      size.width * 0.05,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      child: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.premium),
        icon: const Icon(Icons.lock_outline),
        label: const Text('Find out who voted for you'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
