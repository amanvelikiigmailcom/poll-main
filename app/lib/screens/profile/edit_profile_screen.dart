import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../services/local_game_service.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/university_picker_field.dart';
import '../../widgets/common/reset_game_action.dart';

// ---------------------------------------------------------------------------
// Local form state
// ---------------------------------------------------------------------------

class _EditFormState {
  const _EditFormState({
    this.firstName = '',
    this.username = '',
    this.university = '',
    this.universityYear,
    this.isHydrated = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final String firstName;
  final String username;
  final String university;
  final int? universityYear;
  final bool isHydrated;
  final bool isSaving;
  final String? errorMessage;

  _EditFormState copyWith({
    String? firstName,
    String? username,
    String? university,
    int? universityYear,
    bool clearYear = false,
    bool? isHydrated,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return _EditFormState(
      firstName: firstName ?? this.firstName,
      username: username ?? this.username,
      university: university ?? this.university,
      universityYear: clearYear ? null : universityYear ?? this.universityYear,
      isHydrated: isHydrated ?? this.isHydrated,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _EditFormNotifier extends StateNotifier<_EditFormState> {
  _EditFormNotifier() : super(const _EditFormState());

  void hydrate({
    required String firstName,
    required String username,
    required String university,
    int? universityYear,
  }) {
    state = _EditFormState(
      firstName: firstName,
      username: username,
      university: university,
      universityYear: universityYear,
      isHydrated: true,
    );
  }

  void setFirstName(String v) => state = state.copyWith(firstName: v);
  void setUsername(String v) => state = state.copyWith(username: v);
  void setUniversity(String v) => state = state.copyWith(university: v);
  void setUniversityYear(int? year) =>
      state = state.copyWith(universityYear: year, clearYear: year == null);
  void setSaving(bool v) => state = state.copyWith(isSaving: v);
  void setError(String? message) => state = state.copyWith(
    errorMessage: message,
    clearError: message == null,
  );
}

final _editFormProvider =
    StateNotifierProvider.autoDispose<_EditFormNotifier, _EditFormState>((ref) {
      return _EditFormNotifier();
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
  final _lastNameCtrl = TextEditingController();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _universityCtrl;
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _universityCtrl = TextEditingController();
    _prefillFromLocal();
  }

  Future<void> _prefillFromLocal() async {
    final game = LocalGameService.instance;
    final cached = ref.read(localProfileProvider);
    var name = cached.playerName;
    var username = cached.username;
    var university = cached.university;
    var year = cached.universityYear;

    // Always read SharedPreferences so the form matches registration
    // even if the in-memory provider has not finished loading yet.
    name = await game.getPlayerName() ?? name;
    final fullName = await game.getFullName();
    if (fullName.$1.isNotEmpty) name = fullName.$1;
    username = await game.getUsername() ?? username;
    university = await game.getUniversity() ?? university;
    year = await game.getUniversityYear() ?? year;

    if (!mounted) return;
    _firstNameCtrl.text = name;
    _lastNameCtrl.text = fullName.$2;
    _usernameCtrl.text = username;
    _universityCtrl.text = university;
    ref
        .read(_editFormProvider.notifier)
        .hydrate(
          firstName: name,
          username: username,
          university: university,
          universityYear: year,
        );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _universityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final formNotifier = ref.read(_editFormProvider.notifier);
    final formState = ref.read(_editFormProvider);
    formNotifier.setSaving(true);
    formNotifier.setError(null);

    try {
      final last = _lastNameCtrl.text.trim();
      await LocalGameService.instance.saveFullName(formState.firstName, last);
      try {
        await ref.read(invitationServiceProvider).syncProfile();
      } catch (_) {
        /* Retried before creating or claiming an invitation. */
      }
      await ref
          .read(localProfileProvider.notifier)
          .save(
            username: formState.username.trim(),
            playerName: [
              formState.firstName.trim(),
              if (last.isNotEmpty) last,
            ].join(' '),
            university: formState.university.trim(),
            universityYear: formState.universityYear,
          );
      if (mounted) context.pop();
    } catch (e) {
      formNotifier.setSaving(false);
      formNotifier.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(_editFormProvider);
    final userState = ref.watch(userNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
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
              const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFEFF1FE),
                child: Text('🙂', style: TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 20),
              _TextFieldsSection(
                firstNameCtrl: _firstNameCtrl,
                usernameCtrl: _usernameCtrl,
                lastNameCtrl: _lastNameCtrl,
                onFirstNameChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setFirstName(v),
                onUsernameChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setUsername(v),
              ),
              const SizedBox(height: 12),
              _UniversitySection(
                universityCtrl: _universityCtrl,
                year: formState.universityYear,
                onUniversityChanged: (v) =>
                    ref.read(_editFormProvider.notifier).setUniversity(v),
                onYearChanged: (y) =>
                    ref.read(_editFormProvider.notifier).setUniversityYear(y),
              ),
              if (formState.errorMessage != null ||
                  userState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    formState.errorMessage ?? userState.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SaveButton(
                isSaving: formState.isSaving || userState.isLoading,
                onPressed: _save,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => showResetGameDialog(context, ref),
                child: const Text(
                  'Reset game',
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
}

// ---------------------------------------------------------------------------
// Text fields
// ---------------------------------------------------------------------------

class _TextFieldsSection extends StatelessWidget {
  const _TextFieldsSection({
    required this.firstNameCtrl,
    required this.usernameCtrl,
    required this.lastNameCtrl,
    required this.onFirstNameChanged,
    required this.onUsernameChanged,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController lastNameCtrl;
  final ValueChanged<String> onFirstNameChanged;
  final ValueChanged<String> onUsernameChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InputField(
            label: 'First name',
            controller: firstNameCtrl,
            onChanged: onFirstNameChanged,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
          _InputField(
            label: 'Last name',
            controller: lastNameCtrl,
            onChanged: (_) {},
            validator: (value) =>
                LocalGameService.validateProfileName(value ?? '', 'last name'),
          ),
          const SizedBox(height: 14),
          _InputField(
            label: 'Profile handle (optional)',
            controller: usernameCtrl,
            onChanged: onUsernameChanged,
            prefixText: '@',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (v.contains(' ')) return 'Handle cannot contain spaces';
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
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// University / year
// ---------------------------------------------------------------------------

class _UniversitySection extends StatelessWidget {
  const _UniversitySection({
    required this.universityCtrl,
    required this.year,
    required this.onUniversityChanged,
    required this.onYearChanged,
  });

  final TextEditingController universityCtrl;
  final int? year;
  final ValueChanged<String> onUniversityChanged;
  final ValueChanged<int?> onYearChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UniversityPickerField(
            controller: universityCtrl,
            onChanged: onUniversityChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: ValueKey(year),
            initialValue: year,
            decoration: InputDecoration(
              labelText: 'Year',
              hintText: 'Select year',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1st year')),
              DropdownMenuItem(value: 2, child: Text('2nd year')),
              DropdownMenuItem(value: 3, child: Text('3rd year')),
              DropdownMenuItem(value: 4, child: Text('4th year')),
            ],
            onChanged: onYearChanged,
          ),
        ],
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
              borderRadius: BorderRadius.circular(12),
            ),
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
                  'Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
