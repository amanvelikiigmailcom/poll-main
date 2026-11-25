import '../../services/support_email_service.dart';
import '../../widgets/common/support_email_dialog.dart';
import '../../widgets/common/friends_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_game_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/external_link_service.dart';
import '../../services/content_service.dart';
import '../../theme/app_colors.dart';
import '../../services/game_settings.dart';
import '../../services/subscription_service.dart';
import '../../services/app_info_service.dart';
import '../../widgets/common/reset_game_action.dart';
import 'settings_quiz_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget route(IconData icon, String title, String path) =>
        _ArrowTile(icon: icon, title: title, onTap: () => context.push(path));
    Widget card(List<Widget> rows) => _SettingsCard(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'YOUR CIRCLE'),
          card([
            route(Icons.auto_awesome_outlined, 'Activity', AppRoutes.activity),
            const FriendsLink(),
            route(Icons.stars_outlined, 'Collection', AppRoutes.collection),
          ]),
          const _SectionHeader(title: 'ACCOUNT'),
          card([
            route(Icons.person_outline, 'Edit profile', AppRoutes.editProfile),
            route(
              Icons.notifications_none,
              'Notifications',
              AppRoutes.notificationsSettings,
            ),
            _ArrowTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Invitation code',
              onTap: () => context.push(AppRoutes.invitationCode, extra: true),
            ),
          ]),
          const _SectionHeader(title: 'VISIBILITY'),
          card([
            route(
              Icons.visibility_off_outlined,
              'Hidden suggestions',
              AppRoutes.hiddenSuggestions,
            ),
            route(
              Icons.shield_outlined,
              'Blocked users',
              AppRoutes.blockedUsers,
            ),
          ]),
          const _SectionHeader(title: 'GAME'),
          card([
            _ArrowTile(
              icon: Icons.tune,
              title: 'Quiz preferences',
              onTap: () => showQuizPreferences(context),
            ),
            ListenableBuilder(
              listenable: GameSettings.instance,
              builder: (context, _) {
                final settings = GameSettings.instance;
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Sound'),
                      value: settings.sound,
                      onChanged: (v) => settings.setOption('sound', v),
                    ),
                    SwitchListTile(
                      title: const Text('Haptics'),
                      value: settings.haptics,
                      onChanged: (v) => settings.setOption('haptics', v),
                    ),
                    SwitchListTile(
                      title: const Text('Reduce motion'),
                      value: settings.reduceMotion,
                      onChanged: (v) => settings.setOption('reduce_motion', v),
                    ),
                  ],
                );
              },
            ),
          ]),
          const _SectionHeader(title: 'PREMIUM'),
          card([
            route(
              Icons.workspace_premium_outlined,
              'Premium',
              AppRoutes.premium,
            ),
            const _SubscriptionStatusTile(),
          ]),
          const _SectionHeader(title: 'HELP'),
          card([
            route(Icons.help_outline, 'How to play', AppRoutes.howToUse),
            route(Icons.live_help_outlined, 'FAQ', AppRoutes.faq),
            for (final kind in [
              SupportEmailKind.support,
              SupportEmailKind.problem,
              SupportEmailKind.feedback,
            ])
              _ArrowTile(
                icon: kind == SupportEmailKind.feedback
                    ? Icons.feedback_outlined
                    : Icons.mail_outline,
                title: kind.title,
                onTap: () => showSupportEmail(context, kind: kind),
              ),
            route(Icons.support_agent, 'Safety', AppRoutes.safetyCenter),
            route(
              Icons.family_restroom_outlined,
              'For parents',
              AppRoutes.forParents,
            ),
            route(
              Icons.auto_awesome_outlined,
              'Replay intro',
              AppRoutes.onboarding,
            ),
          ]),
          const _SectionHeader(title: 'PRIVACY & DATA'),
          card([
            for (final link in [
              (Icons.privacy_tip_outlined, 'Privacy Policy', 'url_privacy'),
              (Icons.article_outlined, 'Terms of Use', 'url_terms'),
            ])
              _ArrowTile(
                icon: link.$1,
                title: link.$2,
                onTap: () => openExternalLink(
                  context,
                  ContentService.instance.text(link.$3),
                ),
              ),
            _ArrowTile(
              icon: Icons.data_object,
              title: 'View my local data',
              onTap: () async {
                final data = await LocalGameService.instance.exportLocalData();
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Your local data'),
                    content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(child: SelectableText(data)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(ClipboardData(text: data));
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Copied. This includes private game data.',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Couldn’t copy. Select the text to copy it.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Copy JSON'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          const _SectionHeader(title: 'ACCOUNT ACTIONS'),
          card([
            _ArrowTile(
              icon: Icons.restart_alt,
              title: 'Reset game',
              color: AppColors.accentRed,
              onTap: () => showResetGameDialog(context, ref),
            ),
            _ArrowTile(
              icon: Icons.delete_outline,
              title: 'Delete account',
              color: AppColors.accentRed,
              onTap: () => context.push(AppRoutes.deleteAccount),
            ),
          ]),
          FutureBuilder<String>(
            future: AppInfoService.versionLabel(),
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.data ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

class _ArrowTile extends StatelessWidget {
  const _ArrowTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: TextStyle(color: color)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

/// Live subscription state for support and self-diagnostics.
class _SubscriptionStatusTile extends StatelessWidget {
  const _SubscriptionStatusTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.instance.proListenable,
      builder: (context, pro, _) => _ArrowTile(
        icon: Icons.verified_outlined,
        title: 'Subscription status',
        subtitle: pro ? 'Active' : 'Free',
        onTap: () => showSubscriptionStatusDialog(context),
      ),
    );
  }
}

Future<String> _subscriptionStatusText() async {
  final sub = SubscriptionService.instance;
  var timedOut = false;
  try {
    await sub.refresh().timeout(const Duration(seconds: 8));
  } catch (_) {
    timedOut = true;
  }
  if (await sub.isPro()) return 'Premium is active on this device.';
  if (!timedOut && sub.statusAvailable) {
    return 'You are using the free version. No active Premium subscription was found. '
        'If you purchased Premium before, use Restore purchases on the Premium screen.';
  }
  return 'We couldn’t check your subscription right now. Check your connection and try again. '
      'This does not mean your subscription has been cancelled.';
}

Future<void> showSubscriptionStatusDialog(BuildContext context) async {
  final status = _subscriptionStatusText();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Subscription status'),
      content: FutureBuilder<String>(
        future: status,
        builder: (context, snapshot) {
          if (snapshot.hasData) return Text(snapshot.data!);
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Flexible(child: Text('Checking your subscription…')),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
