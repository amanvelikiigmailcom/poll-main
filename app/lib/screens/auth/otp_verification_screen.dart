import '../../providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../services/age_gate_service.dart';
import '../../services/onboarding_flow.dart';
import '../../services/local_game_service.dart';
import '../../services/content_service.dart';

/// Phone login, step 2: the SMS code. On success the backend session is
/// stored, then the declared-age step precedes contacts.
class OTPVerificationScreen extends ConsumerStatefulWidget {
  const OTPVerificationScreen({
    super.key,
    required this.phone,
    this.verificationId,
  });

  final String phone;
  final String? verificationId;

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  static const _primaryBlue = Color(0xFF4B6EF5);

  final TextEditingController _pinController = TextEditingController();
  String? _verificationId;
  bool _verifying = false;
  bool _resending = false;
  String? _codeError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _pinController.text.trim();
    final verificationId = _verificationId;
    if (_verifying || _resending) return;
    if (verificationId == null) {
      setState(() => _codeError = 'Request a new code to continue.');
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _codeError = 'Enter all 6 digits from the SMS.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _verifying = true;
      _codeError = null;
      _notice = null;
    });
    try {
      final result = await ref
          .read(authNotifierProvider.notifier)
          .verifyFirebaseCode(
            verificationId: verificationId,
            code: code,
            phone: widget.phone,
          );
      if (!mounted) return;
      if (result.success) {
        await _afterLogin();
      } else {
        setState(
          () => _codeError =
              result.message ?? 'Couldn’t verify the code. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _codeError = 'Couldn’t verify the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _afterLogin() async => _next();

  Future<void> _next() async {
    final country = GoRouterState.of(context).extra;
    if (country is Map && country['country'] is String) {
      await ref
          .read(onboardingDetailsProvider)
          .setCountry(country['country'] as String);
    }
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final onboarding = ref.read(onboardingDetailsProvider);
    await onboarding.restore(requireOnline: true);
    if (!mounted) return;
    final storage = ref.read(storageServiceProvider);
    final reviewer =
        storage.reviewerSkipsAllowed &&
        (await storage.getToken())?.isNotEmpty == true;
    if (reviewer) await ref.read(onboardingDetailsProvider).prepareReviewer();
    final hasNames =
        reviewer && await LocalGameService.instance.hasEnoughNames();
    final restored = await onboarding.read();
    final returning =
        !reviewer &&
        restored['profileComplete'] == true &&
        restored['status'] == 'selected';
    if (!mounted) return;
    OnboardingFlow.instance.completePhoneStep();
    context.go(
      AgeGateService.instance.status != AgeGateStatus.verified
          ? AppRoutes.age
          : reviewer
          ? (hasNames ? AppRoutes.username : AppRoutes.namesEntry)
          : returning
          ? (restored['stage'] == 'contacts'
                ? AppRoutes.namesEntry
                : AppRoutes.username)
          : AppRoutes.profileDetails,
    );
  }

  Future<void> _resend() async {
    if (_resending || _verifying) return;
    setState(() {
      _resending = true;
      _notice = null;
      _codeError = null;
    });
    try {
      final result = await ref
          .read(authNotifierProvider.notifier)
          .sendFirebaseCode(widget.phone);
      if (!mounted) return;
      if (result.autoIdToken != null && result.success) {
        await _afterLogin();
      } else if (result.success && result.verificationId != null) {
        setState(() {
          _verificationId = result.verificationId;
          _pinController.clear();
          _notice = 'A new code is on its way.';
        });
      } else {
        setState(
          () => _codeError =
              result.message ?? 'Couldn’t resend the code. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _codeError = 'Couldn’t resend the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  bool _continuingAsGuest = false;

  Future<void> _continueAsGuest() async {
    if (_continuingAsGuest ||
        !ref.read(storageServiceProvider).reviewerSkipsAllowed ||
        !ContentService.instance.flag('guest_enabled')) {
      return;
    }
    setState(() {
      _continuingAsGuest = true;
      _codeError = null;
    });
    try {
      await _next();
    } catch (_) {
      if (mounted) {
        setState(
          () => _codeError =
              'Couldn’t continue. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _continuingAsGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ContentService.instance,
    builder: (context, _) => _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sent to ${widget.phone}. It expires in a few minutes.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Pinput(
                        length: 6,
                        controller: _pinController,
                        enabled: !_verifying && !_resending,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) {
                          if (_codeError != null) {
                            setState(() => _codeError = null);
                          }
                        },
                        autofocus: true,
                        onCompleted: (_) => _verify(),
                        defaultPinTheme: PinTheme(
                          width: ((constraints.maxWidth - 88) / 6).clamp(
                            24.0,
                            50.0,
                          ),
                          height: 60,
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if ((_codeError ?? _notice) case final message?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed:
                              _resending || _verifying || widget.phone.isEmpty
                              ? null
                              : _resend,
                          child: Text(
                            _resending ? 'Sending…' : 'Resend code',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _verifying || _resending ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primaryBlue,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _verifying ? 'Checking…' : 'Verify',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if ((ref
                              .read(storageServiceProvider)
                              .reviewerSkipsAllowed &&
                          ContentService.instance.flag('guest_enabled'))) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _verifying || _continuingAsGuest
                              ? null
                              : _continueAsGuest,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Continue with this account'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
