import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Local form state
// ---------------------------------------------------------------------------

class _EditFormState {
  const _EditFormState({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.localAvatarPath,
    this.isSaving = false,
    this.errorMessage,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String? localAvatarPath;
  final bool isSaving;
  final String? errorMessage;

  _EditFormState copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? localAvatarPath,
    bool clearLocalAvatar = false,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return _EditFormState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      localAvatarPath:
          clearLocalAvatar ? null : localAvatarPath ?? this.localAvatarPath,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _EditFormNotifier extends StateNotifier<_EditFormState> {
  _EditFormNotifier(User? user)
      : super(_EditFormState(
          firstName: user?.firstName ?? '',
          lastName: user?.lastName ?? '',
          username: user?.username ?? '',
        ));

  void setFirstName(String v) => state = state.copyWith(firstName: v);
  void setLastName(String v) => state = state.copyWith(lastName: v);
  void setUsername(String v) => state = state.copyWith(username: v);
  void setLocalAvatar(String path) =>
      state = state.copyWith(localAvatarPath: path);
  void clearError() => state = state.copyWith(clearError: true);

  Map<String, dynamic> toPayload() => {
        'firstName': state.firstName.trim(),
        'lastName': state.lastName.trim(),
        'username': state.username.trim(),
      };
}

final _editFormProvider =
    StateNotifierProvider<_EditFormNotifier, _EditFormState>((ref) {
  final user = ref.watch(currentUserProvider);
  return _EditFormNotifier(user);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _usernameCtrl;
  final _formKey = GlobalKey<FormState>();
  String? _deleteReason;

  static const _deleteReasons = [
    'Больше не хочу пользоваться',
    'Приложение неудобное',
    'Проблемы с конфиденциальностью',
    'Создам новый аккаунт',
    'Другая причина',
  ];

  @override
  void initState() {
    super.initState();
    final formState = ref.read(_editFormProvider);
    _firstNameCtrl = TextEditingController(text: formState.firstName);
    _lastNameCtrl = TextEditingController(text: formState.lastName);
    _usernameCtrl = TextEditingController(text: formState.username);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      ref.read(_editFormProvider.notifier).setLocalAvatar(picked.path);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(userNotifierProvider.notifier);
    final formNotifier = ref.read(_editFormProvider.notifier);
    final formState = ref.read(_editFormProvider);

    // Upload avatar if changed
    if (formState.localAvatarPath != null) {
      await notifier.uploadPhoto(formState.localAvatarPath!);
    }

    final success = await notifier.updateProfile(formNotifier.toPayload());
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final formState = ref.watch(_editFormProvider);
    final userState = ref.watch(userNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close,
              color: AppColors.textPrimary, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Редактировать профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              _AvatarSection(
                user: user,
                localPath: formState.localAvatarPath,
                onTap: _pickImage,
              ),
              const SizedBox(height: 20),
              _TextFieldsSection(
                firstNameCtrl: _firstNameCtrl,
                lastNameCtrl: _lastNameCtrl,
                usernameCtrl: _usernameCtrl,
                onFirstNameChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setFirstName(v),
                onLastNameChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setLastName(v),
                onUsernameChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setUsername(v),
              ),
              const SizedBox(height: 12),
              _SchoolClassSection(user: user),
              const SizedBox(height: 12),
              _PremiumRow(user: user),
              if (userState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    userState.errorMessage!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SaveButton(
                isSaving: userState.isLoading,
                onPressed: _save,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _showDeleteDialog(context),
                child: const Text(
                  'Удалить аккаунт',
                  style: TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showSchoolDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Изменить школу',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Вы уверены? После смены школы вам нужно будет заново выбрать класс.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.school);
            },
            child: const Text(
              'Изменить',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    String? localReason = _deleteReason;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Удалить аккаунт?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Укажите причину удаления:',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                ..._deleteReasons.map(
                  (r) => RadioListTile<String>(
                    title: Text(r,
                        style: const TextStyle(fontSize: 14)),
                    value: r,
                    groupValue: localReason,
                    activeColor: AppColors.primaryBlue,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) =>
                        setDialogState(() => localReason = v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: localReason == null
                  ? null
                  : () {
                      setState(() => _deleteReason = localReason);
                      Navigator.pop(ctx);
                      // TODO: call delete account API
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.border,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Удалить безвозвратно'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar section
// ---------------------------------------------------------------------------

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    this.user,
    this.localPath,
    required this.onTap,
  });

  final User? user;
  final String? localPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);
    final hasNetwork =
        user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;

    Widget avatar;
    if (localPath != null) {
      // Local file picked by user
      avatar = CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(File(localPath!)),
        backgroundColor: AppColors.primaryBlue,
      );
    } else if (hasNetwork) {
      avatar = CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(user!.avatarUrl!),
        backgroundColor: AppColors.primaryBlue,
      );
    } else {
      avatar = CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.primaryBlue,
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            avatar,
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: const Text(
            'Изменить фото',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(User? user) {
    if (user == null) return 'МЯ';
    final f = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final l = user.lastName.isNotEmpty ? user.lastName[0] : '';
    return '$f$l'.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Text fields
// ---------------------------------------------------------------------------

class _TextFieldsSection extends StatelessWidget {
  const _TextFieldsSection({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.usernameCtrl,
    required this.onFirstNameChanged,
    required this.onLastNameChanged,
    required this.onUsernameChanged,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController usernameCtrl;
  final ValueChanged<String> onFirstNameChanged;
  final ValueChanged<String> onLastNameChanged;
  final ValueChanged<String> onUsernameChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InputField(
            label: 'Имя',
            controller: firstNameCtrl,
            onChanged: onFirstNameChanged,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
          ),
          const SizedBox(height: 14),
          _InputField(
            label: 'Фамилия',
            controller: lastNameCtrl,
            onChanged: onLastNameChanged,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Введите фамилию' : null,
          ),
          const SizedBox(height: 14),
          _InputField(
            label: 'Логин',
            controller: usernameCtrl,
            onChanged: onUsernameChanged,
            prefixText: '@',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Введите логин';
              if (v.contains(' ')) return 'Логин не должен содержать пробелы';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.prefixText,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? prefixText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// School / class section
// ---------------------------------------------------------------------------

class _SchoolClassSection extends StatelessWidget {
  const _SchoolClassSection({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final schoolName =
        user?.schoolName?.isNotEmpty == true ? user!.schoolName! : 'Не указана';
    final gradeText = user?.displayGrade ?? 'Не указан';

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Школа',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            subtitle: Text(
              schoolName,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => _showChangeSchoolDialog(context),
              child: const Text(
                'Изменить',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: const Text(
              'Класс',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            subtitle: Text(
              gradeText,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => context.push(AppRoutes.classSelect),
              child: const Text(
                'Изменить',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeSchoolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Изменить школу',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Вы уверены? После смены школы вам нужно будет заново выбрать класс.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.school);
            },
            child: const Text(
              'Изменить',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium row
// ---------------------------------------------------------------------------

class _PremiumRow extends StatelessWidget {
  const _PremiumRow({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final isPremium = user?.isPremium ?? false;

    return Container(
      color: AppColors.white,
      child: ListTile(
        title: const Text(
          'Premium статус',
          style:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.premiumGold,
                      Color(0xFFFFA500)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Бесплатный',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
        onTap: () => context.push(AppRoutes.premium),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save button
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSaving ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Сохранить',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
