import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ── Settings state managed locally + via Riverpod auth for logout/delete ──────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Notification toggles
  bool _notifyNewVotes = true;
  bool _notifyFriendRequests = true;
  bool _notifyPremium = false;

  // Language
  String _selectedLanguage = 'English';

  // App version (would normally come from package_info_plus)
  static const String _appVersion = '1.0.0 (build 1)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shadowColor: AppColors.border,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        children: [
          // ── NOTIFICATIONS ───────────────────────────────────────────────────
          _SectionHeader(title: 'NOTIFICATIONS'),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.star_outline,
                iconColor: AppColors.premiumGold,
                title: 'New votes',
                subtitle: 'When someone voted for you',
                value: _notifyNewVotes,
                onChanged: (v) => setState(() => _notifyNewVotes = v),
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.person_add_outlined,
                iconColor: AppColors.success,
                title: 'Friend requests',
                subtitle: 'New requests to add you',
                value: _notifyFriendRequests,
                onChanged: (v) => setState(() => _notifyFriendRequests = v),
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppColors.premiumPurple,
                title: 'Premium subscription',
                subtitle: 'Offers and subscription updates',
                value: _notifyPremium,
                onChanged: (v) => setState(() => _notifyPremium = v),
              ),
            ],
          ),

          // ── ACCOUNT ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'ACCOUNT'),
          _SettingsCard(
            children: [
              _ArrowTile(
                icon: Icons.person_outline,
                iconColor: AppColors.primaryBlue,
                title: 'Edit profile',
                onTap: () => context.push(AppRoutes.editProfile),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.language_outlined,
                iconColor: AppColors.primaryBlue,
                title: 'Language',
                trailing: Text(
                  _selectedLanguage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () => _showLanguageDialog(),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.delete_outline,
                iconColor: AppColors.accentRed,
                title: 'Delete account',
                titleColor: AppColors.accentRed,
                onTap: () => _showDeleteAccountDialog(),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.logout,
                iconColor: AppColors.accentRed,
                title: 'Log out',
                titleColor: AppColors.accentRed,
                onTap: () => _showLogoutDialog(),
              ),
            ],
          ),

          // ── APP ─────────────────────────────────────────────────────────────
          _SectionHeader(title: 'APP'),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'App version',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Text(
                  _appVersion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.article_outlined,
                iconColor: AppColors.textSecondary,
                title: 'Terms of use',
                trailingIcon: Icons.open_in_new,
                onTap: () => _launchUrl(
                  'https://hidavo.app/terms',
                  'Terms of use',
                ),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppColors.textSecondary,
                title: 'Privacy policy',
                trailingIcon: Icons.open_in_new,
                onTap: () => _launchUrl(
                  'https://hidavo.app/privacy',
                  'Privacy policy',
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String localSelected = _selectedLanguage;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Choose language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LanguageOption(
                  label: 'English',
                  flag: '🇬🇧',
                  selected: localSelected == 'English',
                  onTap: () => setDialogState(() => localSelected = 'English'),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: 'Русский',
                  flag: '🇷🇺',
                  selected: localSelected == 'Русский',
                  onTap: () => setDialogState(() => localSelected = 'Русский'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedLanguage = localSelected);
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    String? selectedReason;
    const reasons = [
      'I no longer want to use the app',
      'I will create a new account',
      'Privacy concerns',
      'Data security concerns',
      'Other',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete account',
            style: TextStyle(color: AppColors.accentRed),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This cannot be undone. All your data will be deleted after 30 days.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please select a reason:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...reasons.map(
                  (reason) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      reason,
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: AppColors.accentRed,
                    onChanged: (val) =>
                        setDialogState(() => selectedReason = val),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteAccount();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accentRed.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Are you sure?'),
        content: const Text(
          'Your account will be marked for deletion and fully removed after 30 days. You can cancel this within 30 days by signing in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request sent'),
                  backgroundColor: AppColors.accentRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out'),
        content: const Text(
          'Are you sure you want to log out? You will need to verify again to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    // Clear auth state via provider and navigate to phone registration
    try {
      ref.read(authNotifierProvider.notifier).logout();
    } catch (_) {}
    context.go(AppRoutes.phone);
  }

  Future<void> _launchUrl(String url, String label) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $label')),
        );
      }
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: AppColors.divider,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onChanged == null
              ? AppColors.textSecondary
              : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            )
          : null,
      value: value,
      activeColor: AppColors.primaryBlue,
      onChanged: onChanged,
    );
  }
}

class _ArrowTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  const _ArrowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.trailing,
    this.trailingIcon = Icons.chevron_right,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailing!,
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ],
            )
          : Icon(
              trailingIcon,
              color: AppColors.textHint,
              size: 18,
            ),
      onTap: onTap,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
