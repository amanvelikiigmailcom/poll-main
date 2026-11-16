import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/external_link_service.dart';
import '../../utils/constants.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/reset_game_action.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0 (build 1)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.profile),
        ),
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
          const _SectionHeader(title: 'APP'),
          _SettingsCard(children: [
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
