import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../services/age_gate_service.dart';
import '../../services/onboarding_flow.dart';
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
    if (code.length != 6 || verificationId == null || _verifying) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _verifying = true);
    final result = await ref
        .read(authNotifierProvider.notifier)
        .verifyFirebaseCode(
          verificationId: verificationId,
          code: code,
          phone: widget.phone,
        );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (result.success) {
      await _afterLogin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Wrong code. Try again.')),
      );
    }
  }

  Future<void> _afterLogin() async => _next();

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    OnboardingFlow.instance.completePhoneStep();
    context.go(
      AgeGateService.instance.status == AgeGateStatus.verified
          ? AppRoutes.namesEntry
          : AppRoutes.age,
    );
  }

  Future<void> _resend() async {
    if (_resending || _verifying) return;
    setState(() => _resending = true);
    final result = await ref
        .read(authNotifierProvider.notifier)
        .sendFirebaseCode(widget.phone);
    if (!mounted) return;
    setState(() => _resending = false);
    if (result.autoIdToken != null && result.success) {
      await _afterLogin();
      return;
    }
    if (result.success && result.verificationId != null) {
      setState(() {
        _verificationId = result.verificationId;
        _pinController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Couldn’t resend the code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _resending ? null : _resend,
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
                          onPressed: _verificationId == null || _verifying
                              ? null
                              : _verify,
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
                      if (ContentService.instance.flag('guest_enabled')) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _verifying ? null : _next,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Continue without login'),
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
