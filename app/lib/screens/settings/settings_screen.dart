import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_game_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/external_link_service.dart';
import '../../utils/constants.dart';
import '../../theme/app_colors.dart';
import '../../services/game_settings.dart';
import '../../widgets/common/reset_game_action.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.1 (build 3)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'GAME'),
          _SettingsCard(children: [
            _ArrowTile(
              icon: Icons.person_outline,
              title: 'Edit profile',
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.restart_alt,
              title: 'Reset game',
              color: AppColors.accentRed,
              onTap: () => showResetGameDialog(context, ref),
            ),
          ]),
          const _SectionHeader(title: 'EFFECTS'),
          ListenableBuilder(
            listenable: GameSettings.instance,
            builder: (context, _) {
              final settings = GameSettings.instance;
              return _SettingsCard(children: [
                SwitchListTile(title: const Text('Sound'), value: settings.sound,
                  onChanged: (v) => settings.setOption('sound', v)),
                SwitchListTile(title: const Text('Haptics'), value: settings.haptics,
                  onChanged: (v) => settings.setOption('haptics', v)),
                SwitchListTile(title: const Text('Reduce motion'),
                  subtitle: const Text('Also respects your device setting'),
                  value: settings.reduceMotion,
                  onChanged: (v) => settings.setOption('reduce_motion', v)),
              ]);
            },
          ),
          const _SectionHeader(title: 'PRIVACY'),
          _SettingsCard(children: [
            _ArrowTile(
              icon: Icons.delete_outline,
              title: 'Delete account',
              color: AppColors.accentRed,
              onTap: () => context.push(AppRoutes.deleteAccount),
            ),
            const Divider(height: 1),
            _ArrowTile(icon: Icons.data_object, title: 'View my local data',
              onTap: () async {
                final data = await LocalGameService.instance.exportLocalData();
                if (!context.mounted) return;
                await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
                  title: const Text('Your local data'),
                  content: SizedBox(width: 500, child: SingleChildScrollView(
                    child: SelectableText(data))),
                  actions: [
                    TextButton(onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: data));
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied. This includes private game data.')));
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Couldn’t copy. Select the text to copy it.')));
                        }
                      }
                    }, child: const Text('Copy JSON')),
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
                  ],
                ));
              }),
          ]),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text('Your profile, photo and latest round choices stay on this device. '
              'Use nicknames or example names. Reset game removes this local game data. '
              'Opening email, sharing or visiting external pages uses the service you choose.')),
          const _SectionHeader(title: 'APP'),
          _SettingsCard(children: [
            _ArrowTile(
              icon: Icons.workspace_premium_outlined,
              title: 'Premium',
              onTap: () => context.push(AppRoutes.premium),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.auto_awesome_outlined,
              title: 'Replay intro',
              onTap: () => context.push(AppRoutes.onboarding),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('App version'),
              trailing: Text(_appVersion),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.help_outline,
              title: 'How to play',
              onTap: () => context.push(AppRoutes.howToUse),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.support_agent,
              title: 'Support and safety',
              onTap: () => context.push(AppRoutes.safetyCenter),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.article_outlined,
              title: 'Terms of Use',
              onTap: () => openExternalLink(context, AppConstants.termsUrl),
            ),
            const Divider(height: 1),
            _ArrowTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => openExternalLink(context, AppConstants.privacyUrl),
            ),
          ]),
          const SizedBox(height: 40),
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
        child: Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
                letterSpacing: 1.4)),
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
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
