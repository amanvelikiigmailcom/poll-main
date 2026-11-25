import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

const onboardingBlue = Color(0xFF4B6EF5);

/// The same blue/white form treatment as the existing phone/username steps.
class SetupFormPage extends StatelessWidget {
  const SetupFormPage({
    super.key,
    required this.title,
    required this.children,
    this.back,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? back;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: onboardingBlue,
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (back != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: back,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

InputDecoration setupInput(String label) => InputDecoration(
  labelText: label,
  floatingLabelBehavior: FloatingLabelBehavior.always,
  floatingLabelStyle: const TextStyle(
    color: onboardingBlue,
    backgroundColor: Colors.white,
  ),
  errorStyle: const TextStyle(color: Colors.white),
  errorMaxLines: 4,
  counterStyle: const TextStyle(color: Colors.white70),
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
);
ButtonStyle setupButton() => ElevatedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: onboardingBlue,
  padding: const EdgeInsets.symmetric(vertical: 16),
);

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});
  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final first = TextEditingController(), last = TextEditingController();
  final form = GlobalKey<FormState>();
  String? gender;
  bool loading = true, saving = false;
  String? error;
  bool genderRequired = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(onboardingDetailsProvider);
    await service.restore();
    final data = await service.read();
    if (data['stage'] == null) await service.draft({'stage': 'profile'});
    if (!mounted) return;
    setState(() {
      first.text = data['firstName'] as String? ?? '';
      last.text = data['lastName'] as String? ?? '';
      gender = data['gender'] as String?;
      loading = false;
    });
    first.addListener(_draft);
    last.addListener(_draft);
  }

  void _draft() {
    if (!loading && !saving) {
      unawaited(
        ref.read(onboardingDetailsProvider).draft({
          'firstName': first.text,
          'lastName': last.text,
          'gender': gender,
        }),
      );
    }
  }

  Future<void> _save() async {
    if (saving) return;
    final validNames = form.currentState?.validate() ?? false;
    setState(() => genderRequired = gender == null);
    if (!validNames || gender == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(onboardingDetailsProvider)
          .saveProfile(first.text, last.text, gender!);
      if (mounted) context.go(AppRoutes.schoolSetup);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Couldn’t save your profile. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SetupFormPage(
    title: 'About you',
    subtitle:
        'Add your name and choose your gender. Your name is not shown on voting cards.',
    back: saving ? null : () => context.go(AppRoutes.phone),
    children: [
      if (loading)
        const Center(child: CircularProgressIndicator(color: Colors.white))
      else
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('onboarding-first-name'),
                controller: first,
                autofillHints: const [AutofillHints.givenName],
                enabled: !saving,
                maxLength: 64,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 16),
                decoration: setupInput('First name'),
                validator: (v) =>
                    LocalGameService.validateProfileName(v ?? '', 'first name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('onboarding-last-name'),
                controller: last,
                autofillHints: const [AutofillHints.familyName],
                enabled: !saving,
                maxLength: 64,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 16),
                decoration: setupInput('Last name'),
                validator: (v) =>
                    LocalGameService.validateProfileName(v ?? '', 'last name'),
              ),
              const SizedBox(height: 20),
              for (final option in const [
                ('female', 'Female'),
                ('male', 'Male'),
                ('nonbinary', 'Non-binary'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: saving
                        ? null
                        : () {
                            setState(() {
                              gender = option.$1;
                              genderRequired = false;
                            });
                            _draft();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gender == option.$1
                          ? onboardingBlue
                          : Colors.white,
                      backgroundColor: gender == option.$1
                          ? Colors.white
                          : Colors.transparent,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(option.$2)),
                        Icon(
                          gender == option.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                      ],
                    ),
                  ),
                ),
              if (genderRequired)
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Choose a gender to continue.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: saving ? null : _save,
                style: setupButton(),
                child: Text(saving ? 'Please wait…' : 'Continue'),
              ),
            ],
          ),
        ),
    ],
  );
}
