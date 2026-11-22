import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import '../../config/phone_regions.dart';
import '../../services/contact_sync_service.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

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
  String _completePhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _internationalNumber(String raw, String country, String dialCode) {
    var national = raw.trim();
    if ((country == 'GB' || country == 'NZ') && national.startsWith('0')) {
      national = national.substring(1);
    }
    if (national.isEmpty) return '';
    return ContactSyncService.normalizePhone(
          national,
          defaultRegion: IsoCode.fromJson(country),
        ) ??
        '+$dialCode$national';
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    OnboardingFlow.instance.completePhoneStep();
    context.go(
      AgeGateService.instance.status == AgeGateStatus.verified
          ? AppRoutes.namesEntry
          : AppRoutes.age,
    );
  }

  bool _sending = false;

  Future<void> _submit() async {
    if (_completePhone.isEmpty || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    final notifier = ref.read(authNotifierProvider.notifier);
    final result = await notifier.sendFirebaseCode(_completePhone);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.autoIdToken != null && result.success) {
      _next();
      return;
    }
    if (result.success && result.verificationId != null) {
      context.push(
        AppRoutes.otp,
        extra: {
          'phone': _completePhone,
          'verificationId': result.verificationId,
        },
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Couldn’t send the code.')),
    );
  }

  void _continueAsGuest() {
    if (ContentService.instance.flag('guest_enabled')) _next();
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
                          decoration: const InputDecoration(
                            hintText: 'Phone number',
                            border: InputBorder.none,
                          ),
                          initialCountryCode: PhoneRegions.defaultCountry,
                          countries: PhoneRegions.countries,
                          // Preserve national trunk zeros until normalization.
                          // The package limit otherwise truncates UK/NZ input.
                          disableLengthCheck: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          onCountryChanged: (country) => setState(() {
                            _completePhone = _internationalNumber(
                              _phoneController.text,
                              country.code,
                              country.fullCountryCode,
                            );
                          }),
                          onChanged: (PhoneNumber phone) => setState(() {
                            _completePhone = _internationalNumber(
                              phone.number,
                              phone.countryISOCode,
                              phone.countryCode.replaceFirst('+', ''),
                            );
                          }),
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
                            'Play as a guest for now.',
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
                          onPressed:
                              available &&
                                  _completePhone.isNotEmpty &&
                                  !_sending
                              ? _submit
                              : null,
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
                      if (ContentService.instance.flag('guest_enabled')) ...[
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
                      TextButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          context.push(AppRoutes.privacy);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Privacy Policy'),
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
