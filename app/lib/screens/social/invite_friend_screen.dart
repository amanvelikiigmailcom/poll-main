import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/invite_share_service.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

/// Optional text sharing. A social-button tap skips the current round timer.
class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key});

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  InvitePayload? _payload;
  bool _sharing = false;
  bool _timerSkipped = false;
  bool _hasTimer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final payload = await InviteShareService.instance.buildPayload();
    final seconds = await LocalGameService.instance.secondsUntilNextRound();
    if (!mounted) return;
    setState(() {
      _payload = payload;
      _hasTimer = seconds > 0;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _share(Future<void> Function() openApp) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Unlock on tap, even if the user cancels or the external app is absent.
      final seconds = await LocalGameService.instance.secondsUntilNextRound();
      await LocalGameService.instance.bypassTimer();
      if (!mounted) return;
      setState(() {
        _timerSkipped = _timerSkipped || seconds > 0;
        _hasTimer = false;
      });
      await openApp();
    } catch (_) {
      _toast('Couldn’t open the app. You can copy the message instead.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _whatsapp() => _share(() async {
        final opened = await InviteShareService.instance.shareWhatsApp();
        _toast(opened
            ? 'WhatsApp opened. Choose a chat to send the message.'
            : 'Couldn’t open WhatsApp. You can copy the message instead.');
      });

  Future<void> _instagram() => _share(() async {
        final result = await InviteShareService.instance.shareInstagram();
        _toast(result.openedApp
            ? 'Copied. Paste it in Instagram.'
            : 'Copied. Open Instagram and paste the message.');
      });

  Future<void> _copyMessage() async {
    await InviteShareService.instance.copyMessage();
    _toast('Message copied');
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Share Flyprox'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: payload == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  'Send a ready-made invite',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sharing is optional. Your quiz answers stay private, and the other person plays their own quiz.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (_hasTimer || _timerSkipped) ...[
                  const SizedBox(height: 20),
                  Text(
                    _timerSkipped
                        ? 'Timer skipped. Your next round is ready.'
                        : 'Tap WhatsApp or Instagram to skip the timer. Sending a message is optional.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ],
                if (_timerSkipped) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/vote'),
                    child: const Text('Start next round'),
                  ),
                ],
                const SizedBox(height: 20),
                _socialButton(
                    'WhatsApp', 'Open a ready-made message', _whatsapp),
                const SizedBox(height: 12),
                _socialButton('Instagram',
                    'Copy the message and open Instagram', _instagram),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(payload.message,
                      style: const TextStyle(height: 1.5)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _copyMessage,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy message'),
                ),
              ],
            ),
    );
  }

  Widget _socialButton(String name, String subtitle, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: _sharing ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.open_in_new_rounded, size: 20),
        ],
      ),
    );
  }
}
