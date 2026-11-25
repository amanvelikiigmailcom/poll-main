import 'dart:async';
import 'package:dio/dio.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  CancelToken? _request;
  int _operation = 0;
  String _backRoute = AppRoutes.namesEntry;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final game = LocalGameService.instance;
    final name = await game.ensureUsername();
    if (!mounted) return;
    final details = await ref.read(onboardingDetailsProvider).read();
    if (!mounted) return;
    setState(() {
      _controller.text = details['usernameDraft'] as String? ?? name;
      _backRoute = details['stage'] == 'username'
          ? AppRoutes.schoolSetup
          : AppRoutes.namesEntry;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _operation++;
    _request?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    _operation++;
    _request?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(onboardingDetailsProvider).draft({
      'usernameDraft': _controller.text,
    });
    if (mounted) context.go(_backRoute);
  }

  Future<void> _continue() async {
    if (_loading || _saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final operation = ++_operation;
    final storage = ref.read(storageServiceProvider);
    final owner = await storage.getToken();
    if (!mounted || operation != _operation) return;
    setState(() {
      _saving = true;
      _submissionError = null;
    });
    try {
      var name = _controller.text.trim();
      if (owner?.isNotEmpty == true) {
        final request = _request = CancelToken();
        name = await ref
            .read(socialServiceProvider)
            .saveHandle(name, cancelToken: request)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                request.cancel();
                throw const ApiException(
                  'Connection timed out. Please try again.',
                );
              },
            );
      }
      if (!mounted || operation != _operation) return;
      if (owner != await storage.getToken()) {
        throw const ApiException('Account changed. Please sign in again.');
      }
      final game = LocalGameService.instance;
      await game.saveUsername(name);
      if (!mounted || operation != _operation) return;
      await ref.read(localProfileProvider.notifier).refresh();
      if (!mounted || operation != _operation) return;
      final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
      if (!mounted || operation != _operation) return;
      String? invitationNotice;
      if (loggedIn) {
        try {
          await ref
              .read(invitationServiceProvider)
              .completeRegistration()
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Keep the pending invitation for a retry after registration. A
          // network error must not discard locally saved profile details.
          if (await InviteCodeStore.code() != null) {
            invitationNotice =
                'Your profile is saved. Check your invitation in Settings → Invitation code.';
          }
        }
      }
      if (!mounted || operation != _operation) return;
      final needsPush =
          loggedIn &&
          await ref
              .read(pushServiceProvider)
              .needsPrompt()
              .timeout(const Duration(seconds: 2), onTimeout: () => true);
      if (!mounted || operation != _operation) return;
      if (owner != await storage.getToken()) {
        throw const ApiException('Account changed. Please sign in again.');
      }
      await ref.read(onboardingDetailsProvider).draft({'usernameDraft': null});
      await game.setUsernameSetupPending(false);
      await ref.read(onboardingDetailsProvider).finish();
      if (!mounted || operation != _operation) return;
      if (invitationNotice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(invitationNotice)));
      }
      context.go(needsPush ? AppRoutes.pushPrompt : AppRoutes.home);
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() {
        _saving = false;
        _submissionError = error is ApiException
            ? error.message
            : 'Couldn’t save your username. Try again.';
      });
    }
  }

  String? _submissionError;

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
                  tooltip: _backRoute == AppRoutes.schoolSetup
                      ? 'Back to campus'
                      : 'Back to contacts',
                  onPressed: _back,
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
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    floatingLabelStyle: const TextStyle(
                      color: _primaryBlue,
                      backgroundColor: Colors.white,
                    ),
                    prefixText: '@',
                    helperText: '3–32 characters: A–Z, numbers or _',
                    helperMaxLines: 3,
                    helperStyle: const TextStyle(color: Colors.white),
                    errorStyle: const TextStyle(color: Colors.white),
                    errorText: _submissionError,
                    errorMaxLines: 4,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) =>
                      LocalGameService.validateUsername(value ?? ''),
                  onChanged: (_) {
                    _formKey.currentState?.validate();
                    if (_submissionError != null) {
                      setState(() => _submissionError = null);
                    }
                  },
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
