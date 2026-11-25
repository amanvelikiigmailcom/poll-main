import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/story_share_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/voter_reveal_card.dart';

/// One vote participant, opened by tapping a card in vote details.
///
/// Matches the voting screen: light background, initial avatar, question
/// card, share actions and the backend-authorized voter reveal entry.
/// Sharing captures only the avatar and the question card; the voter
/// reveal below it is never part of the shared screenshot.
class LikePersonScreen extends StatefulWidget {
  const LikePersonScreen({super.key, this.data, this.storyShare});

  final Map<String, dynamic>? data;
  final StoryShareService? storyShare;

  @override
  State<LikePersonScreen> createState() => _LikePersonScreenState();
}

class _LikePersonScreenState extends State<LikePersonScreen> {
  final _shotKey = GlobalKey();
  bool _sharing = false;

  StoryShareService get _share => widget.storyShare ?? StoryShareService();

  Future<void> _shareResult(
    StoryShareTarget target,
    Rect? origin,
    String question,
  ) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final png = await _share.capture(
        _shotKey,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      if (!mounted) return;
      if (png == null || png.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t prepare the image. Try again.'),
          ),
        );
        return;
      }
      final outcome = await _share.share(
        png: png,
        target: target,
        caption: 'My Flyprox result: $question',
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      if (outcome == StoryShareOutcome.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              target == StoryShareTarget.instagram
                  ? 'Couldn’t open Instagram'
                  : 'Couldn’t open Snapchat',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
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
                          RepaintBoundary(
                            key: _shotKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ShareSection(
                            busy: _sharing,
                            onShare: (target, origin) =>
                                _shareResult(target, origin, question),
                          ),
                          const SizedBox(height: 20),
                          VoterRevealCard(voteId: data?['voteId'] as String?),
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
  const _ShareSection({required this.onShare, required this.busy});

  final Future<void> Function(StoryShareTarget target, Rect? origin) onShare;
  final bool busy;

  Rect? _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return Rect.fromCenter(
      center: box.localToGlobal(box.size.center(Offset.zero)),
      width: 1,
      height: 1,
    );
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
                onTap: busy
                    ? null
                    : () =>
                          onShare(StoryShareTarget.instagram, _origin(context)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShareButton(
                label: 'Snapchat',
                icon: _SnapchatIcon(),
                onTap: busy
                    ? null
                    : () =>
                          onShare(StoryShareTarget.snapchat, _origin(context)),
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
  final VoidCallback? onTap;

  const _ShareButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primaryBlue
              : AppColors.primaryBlue.withValues(alpha: 0.5),
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
// The voter reveal component is shared with vote details.
// ---------------------------------------------------------------------------
