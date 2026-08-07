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
  bool _notifyTimerExpired = true; // always on, disabled
  bool _notifyFriendRequests = true;
  bool _notifyPremium = false;

  // Language
  String _selectedLanguage = 'Русский';

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
          'Настройки',
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
          // ── УВЕДОМЛЕНИЯ ─────────────────────────────────────────────────────
          _SectionHeader(title: 'УВЕДОМЛЕНИЯ'),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.star_outline,
                iconColor: AppColors.premiumGold,
                title: 'Новые голоса',
                subtitle: 'Когда кто-то проголосовал за вас',
                value: _notifyNewVotes,
                onChanged: (v) => setState(() => _notifyNewVotes = v),
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.timer_outlined,
                iconColor: AppColors.primaryBlue,
                title: 'Таймер истёк',
                subtitle: 'Всегда включено',
                value: _notifyTimerExpired,
                onChanged: null, // disabled — always on
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.person_add_outlined,
                iconColor: AppColors.success,
                title: 'Запросы в друзья',
                subtitle: 'Новые запросы на добавление',
                value: _notifyFriendRequests,
                onChanged: (v) => setState(() => _notifyFriendRequests = v),
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppColors.premiumPurple,
                title: 'Подписка Premium',
                subtitle: 'Акции и обновления подписки',
                value: _notifyPremium,
                onChanged: (v) => setState(() => _notifyPremium = v),
              ),
            ],
          ),

          // ── АККАУНТ ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'АККАУНТ'),
          _SettingsCard(
            children: [
              _ArrowTile(
                icon: Icons.person_outline,
                iconColor: AppColors.primaryBlue,
                title: 'Изменить профиль',
                onTap: () => context.push(AppRoutes.editProfile),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.phone_outlined,
                iconColor: AppColors.primaryBlue,
                title: 'Изменить номер телефона',
                onTap: () => _showChangePhoneDialog(),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.language_outlined,
                iconColor: AppColors.primaryBlue,
                title: 'Язык',
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
                title: 'Удалить аккаунт',
                titleColor: AppColors.accentRed,
                onTap: () => _showDeleteAccountDialog(),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.logout,
                iconColor: AppColors.accentRed,
                title: 'Выйти',
                titleColor: AppColors.accentRed,
                onTap: () => _showLogoutDialog(),
              ),
            ],
          ),

          // ── ПРИЛОЖЕНИЕ ───────────────────────────────────────────────────────
          _SectionHeader(title: 'ПРИЛОЖЕНИЕ'),
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
                  'Версия приложения',
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
                title: 'Условия использования',
                trailingIcon: Icons.open_in_new,
                onTap: () => _launchUrl(
                  'https://oister.app/terms',
                  'Условия использования',
                ),
              ),
              _Divider(),
              _ArrowTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppColors.textSecondary,
                title: 'Политика конфиденциальности',
                trailingIcon: Icons.open_in_new,
                onTap: () => _launchUrl(
                  'https://oister.app/privacy',
                  'Политика конфиденциальности',
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
            title: const Text('Выберите язык'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LanguageOption(
                  label: 'Русский',
                  flag: '🇷🇺',
                  selected: localSelected == 'Русский',
                  onTap: () => setDialogState(() => localSelected = 'Русский'),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: 'English',
                  flag: '🇬🇧',
                  selected: localSelected == 'English',
                  onTap: () => setDialogState(() => localSelected = 'English'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
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
                child: const Text('Применить'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePhoneDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Изменить номер'),
        content: const Text(
          'Для изменения номера телефона вам будет отправлен код подтверждения на новый номер.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.phone);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    String? selectedReason;
    const reasons = [
      'Больше не хочу пользоваться',
      'Создам новый аккаунт',
      'Проблемы с приватностью',
      'Беспокоит безопасность данных',
      'Другая причина',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Удалить аккаунт',
            style: TextStyle(color: AppColors.accentRed),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Это действие нельзя отменить. Все ваши данные будут удалены через 30 дней.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Укажите причину:',
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
              child: const Text('Отмена'),
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
              child: const Text('Удалить аккаунт'),
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
        title: const Text('Вы уверены?'),
        content: const Text(
          'Аккаунт будет помечен для удаления и полностью удалён через 30 дней. Вы можете отменить это в течение 30 дней, войдя в приложение.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Запрос на удаление аккаунта отправлен'),
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
            child: const Text('Да, удалить'),
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
        title: const Text('Выйти из аккаунта'),
        content: const Text(
          'Вы уверены, что хотите выйти? Для входа потребуется повторная верификация.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
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
            child: const Text('Выйти'),
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
          SnackBar(content: Text('Не удалось открыть $label')),
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
