import 'package:flutter/material.dart';
import '../../services/external_link_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../config/phone_regions.dart';
import '../../providers/service_providers.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../services/content_service.dart';
import '../../services/age_gate_service.dart';
import '../../services/onboarding_flow.dart';

/// Phone login, step 1: the number. Firebase sends the SMS code; our backend
/// owns the session afterwards. Guests can skip into the local game.
class PhoneRegistrationScreen extends ConsumerStatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  ConsumerState<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState
    extends ConsumerState<PhoneRegistrationScreen> {
  static const _primaryBlue = Color(0xFF4B6EF5);

  final _phoneController = TextEditingController();
  String _selectedCountry = PhoneRegions.defaultCountry;
  String? _fieldError;
  String? _sendError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _internationalNumber(String raw, String country) {
    final compact = raw.trim().replaceAll(RegExp(r'[\s().\-–]'), '');
    if (!RegExp(r'^\+?[0-9]{1,15}$').hasMatch(compact)) return null;
    try {
      final region = IsoCode.fromJson(country);
      final parsed = compact.startsWith('+')
          ? PhoneNumber.parse(compact)
          : PhoneNumber.parse(compact, destinationCountry: region);
      if (parsed.isoCode != region ||
          !parsed.isValid() ||
          !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(parsed.international)) {
        return null;
      }
      return parsed.international;
    } catch (_) {
      return null;
    }
  }

  Future<void> _next() async {
    await ref.read(onboardingDetailsProvider).setCountry(_selectedCountry);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    OnboardingFlow.instance.completePhoneStep();
    context.go(
      AgeGateService.instance.status == AgeGateStatus.verified
          ? AppRoutes.profileDetails
          : AppRoutes.age,
    );
  }

  bool _sending = false;

  Future<void> _submit() async {
    if (_sending) return;
    final country = _selectedCountry;
    final raw = _phoneController.text;
    final phone = _internationalNumber(raw, country);
    if (phone == null) {
      setState(() {
        _sendError = null;
        _fieldError = switch (raw.trim()) {
          '' => 'Enter your phone number.',
          final value
              when RegExp(r'^\+?[0-9\s().\-–]+$').hasMatch(value) &&
                  value.replaceAll(RegExp(r'\D'), '').length < 8 =>
            'Enter the full phone number, including the area code if needed.',
          _ => 'Check the number and the selected country code.',
        };
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _fieldError = null;
      _sendError = null;
    });
    try {
      await ref.read(onboardingDetailsProvider).setCountry(country);
      if (!mounted) return;
      final result = await ref
          .read(authNotifierProvider.notifier)
          .sendFirebaseCode(phone);
      if (!mounted) return;
      if (result.autoIdToken != null && result.success) {
        await _next();
      } else if (result.success && result.verificationId != null) {
        context.push(
          AppRoutes.otp,
          extra: {
            'phone': phone,
            'country': country,
            'verificationId': result.verificationId,
          },
        );
      } else {
        setState(
          () => _sendError =
              result.message ?? 'Couldn’t send the code. Try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sendError = 'Couldn’t send the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _continueAsGuest() {
    if ((ref.read(storageServiceProvider).reviewerSkipsAllowed &&
        ContentService.instance.flag('guest_enabled'))) {
      _next();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ContentService.instance,
    builder: (context, _) => _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    final loading = ref.watch(authNotifierProvider.select((s) => s.isLoading));
    final supported = ref
        .read(authNotifierProvider.notifier)
        .isPhoneLoginAvailable;
    final available = supported && !loading;
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
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.onboarding),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Log in with phone',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use your number to sign in and let friends find you. '
                        'Firebase verifies your number; Flyprox stores it for your account. '
                        'Phone login is optional. Choose your country code below.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IntlPhoneField(
                          controller: _phoneController,
                          enabled: !_sending,
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            border: InputBorder.none,
                            errorText: _fieldError,
                            errorMaxLines: 3,
                          ),
                          initialCountryCode: PhoneRegions.defaultCountry,
                          countries: PhoneRegions.countries,
                          // Preserve national trunk zeros until normalization.
                          // The package limit otherwise truncates UK/NZ input.
                          disableLengthCheck: true,
                          onCountryChanged: (country) => setState(() {
                            _selectedCountry = country.code;
                            _fieldError = null;
                            _sendError = null;
                          }),
                          onChanged: (_) => setState(() {
                            _fieldError = null;
                            _sendError = null;
                          }),
                        ),
                      ),
                      if (_sendError case final message?)
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
                      if (!supported) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Text(
                            'Phone login isn’t available in this build yet. '
                            'Please try again later.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: available && !_sending ? _submit : null,
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
                            _sending ? 'Sending…' : 'Send code',
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
                          onPressed: _continueAsGuest,
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
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (final link in [
                            ('Privacy Policy', 'url_privacy'),
                            ('Terms of Use', 'url_terms'),
                          ])
                            TextButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                openExternalLink(
                                  context,
                                  ContentService.instance.text(link.$2),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(link.$1),
                            ),
                        ],
                      ),
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
