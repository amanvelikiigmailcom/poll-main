import '../../services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../services/invite_code_store.dart';

const _primaryBlue = Color(0xFF4B6EF5);

/// A local profile nickname, after contacts and before optional notifications.
class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _controller = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final game = LocalGameService.instance;
    final name = await game.ensureUsername();
    final fullName = await game.getFullName();
    final cached = ref.read(storageServiceProvider).getUser();
    if (!mounted) return;
    setState(() {
      _controller.text = name;
      _firstName.text = fullName.$1.isNotEmpty
          ? fullName.$1
          : cached?.firstName ?? '';
      _lastName.text = fullName.$2.isNotEmpty
          ? fullName.$2
          : cached?.lastName ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading || _saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      var name = _controller.text.trim();
      final storage = ref.read(storageServiceProvider);
      if ((await storage.getToken())?.isNotEmpty == true) {
        name = await ref.read(socialServiceProvider).saveHandle(name);
      }
      final game = LocalGameService.instance;
      await game.saveUsername(name);
      await game.saveFullName(_firstName.text, _lastName.text);
      if (!mounted) return;
      await ref.read(localProfileProvider.notifier).refresh();
      final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
      String? invitationNotice;
      if (loggedIn) {
        try {
          await ref.read(invitationServiceProvider).completeRegistration();
        } catch (_) {
          // Keep the pending invitation for a retry after registration. A
          // network error must not discard locally saved profile details.
          if (await InviteCodeStore.code() != null) {
            invitationNotice =
                'Your profile is saved. Check your invitation in Settings → Invitation code.';
          }
        }
      }
      if (!mounted) return;
      final needsPush =
          loggedIn && await ref.read(pushServiceProvider).needsPrompt();
      await game.setUsernameSetupPending(false);
      await ref.read(onboardingDetailsProvider).finish();
      if (!mounted) return;
      if (invitationNotice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(invitationNotice)));
      }
      context.go(needsPush ? AppRoutes.pushPrompt : AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Couldn’t save your username. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _primaryBlue,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back to contacts',
                  onPressed: _saving
                      ? null
                      : () => context.go(AppRoutes.namesEntry),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose your username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a username so friends can find you. Your first name is shared with the friend whose invitation you activate. Your name is never added to voting cards.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else ...[
                TextFormField(
                  key: const Key('onboarding-username'),
                  controller: _controller,
                  enabled: !_saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    helperText: 'At least 3 characters: letters, numbers or _',
                    helperMaxLines: 3,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) =>
                      LocalGameService.validateUsername(value ?? ''),
                  onFieldSubmitted: (_) => _continue(),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading || _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving…' : 'Continue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
