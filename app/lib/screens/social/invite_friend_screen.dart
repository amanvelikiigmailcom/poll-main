import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/invite_share_service.dart';
import '../../theme/app_colors.dart';

/// After voting / timer: invite friends via WhatsApp, Telegram, Instagram
/// with a ready-made message (deep links where supported).
class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key});

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  InvitePayload? _payload;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await InviteShareService.instance.buildPayload();
    if (!mounted) return;
    setState(() {
      _payload = p;
      _loading = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _whatsapp() async {
    await InviteShareService.instance.shareWhatsApp();
    _toast('Opening WhatsApp…');
  }

  Future<void> _telegram() async {
    await InviteShareService.instance.shareTelegram();
    _toast('Opening Telegram…');
  }

  Future<void> _instagram() async {
    final r = await InviteShareService.instance.shareInstagram();
    if (r.copied) {
      _toast(
        r.openedApp
            ? 'Copied — paste it in Direct / Stories'
            : 'Copied. Open Instagram and paste the invite',
      );
    }
  }

  Future<void> _everywhere() async {
    await InviteShareService.instance.shareEverywhere();
  }

  Future<void> _copyMessage() async {
    await InviteShareService.instance.copyMessage();
    _toast('Message copied');
  }

  Future<void> _copyLink() async {
    await InviteShareService.instance.copyLink();
    _toast('Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final p = _payload;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Share Hidavo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _BenefitBanner(),
                const SizedBox(height: 16),
                if (p != null) _PromoCodeCard(code: p.username, onCopy: _copyLink),
                const SizedBox(height: 20),
                const Text(
                  'Send a ready-made invite',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Optional. Send a link so someone can play their own quiz. They will not see your answers.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                _SocialButton(
                  label: 'WhatsApp',
                  subtitle: 'Chat with a ready-made message',
                  color: const Color(0xFF25D366),
                  icon: Icons.chat_rounded,
                  onTap: _whatsapp,
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Telegram',
                  subtitle: 'Share the link + message',
                  color: const Color(0xFF2AABEE),
                  icon: Icons.send_rounded,
                  onTap: _telegram,
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Instagram',
                  subtitle: 'Message copied → paste in Direct',
                  color: const Color(0xFFE1306C),
                  icon: Icons.camera_alt_rounded,
                  onTap: _instagram,
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'All apps',
                  subtitle: 'System share menu',
                  color: AppColors.primaryBlue,
                  icon: Icons.ios_share_rounded,
                  onTap: _everywhere,
                ),
                const SizedBox(height: 20),
                if (p != null) _MessagePreview(message: p.message),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _copyMessage,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link only'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BenefitBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Text('🎉', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Share the app if you want. The other person plays their own quiz. They do not see your answers.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryBlue,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _PromoCodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOUR LOGIN',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '@$code',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onCopy,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.9), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePreview extends StatelessWidget {
  final String message;

  const _MessagePreview({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite message',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
