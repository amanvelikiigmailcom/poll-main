import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';

class PhoneRegistrationScreen extends ConsumerStatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  ConsumerState<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState
    extends ConsumerState<PhoneRegistrationScreen> {
  static const _primaryColor = Color(0xFF4B6EF5);
  static const _ctaColor = Color(0xFFFF3B5C);

  final _formKey = GlobalKey<FormState>();
  PhoneNumber? _phoneNumber;
  bool _isPhoneValid = false;
  String _completePhone = '';

  void _onPhoneChanged(PhoneNumber phone) {
    setState(() {
      _phoneNumber = phone;
      _completePhone = phone.completeNumber;
      // intl_phone_field considers the number valid only when it matches the
      // country pattern; we gate the button on that flag.
      _isPhoneValid = phone.number.isNotEmpty;
    });
  }

  void _onPhoneValidated(PhoneNumber phone) {
    setState(() => _isPhoneValid = true);
  }

  Future<void> _submit() async {
    if (!_isPhoneValid || _completePhone.isEmpty) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .sendOtp(_completePhone);

    if (!mounted) return;

    if (success) {
      context.push(
        '${AppRoutes.otp}?phone=${Uri.encodeComponent(_completePhone)}',
      );
    } else {
      final error = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Произошла ошибка. Попробуйте снова.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // ── Logo mark ──────────────────────────────────────
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'O',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Title ──────────────────────────────────────────
                        const Text(
                          'Вход в OISTER',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1117),
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Введите номер телефона — отправим код подтверждения.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Phone field ────────────────────────────────────
                        _PhoneField(
                          onChanged: _onPhoneChanged,
                          onValidated: _onPhoneValidated,
                          enabled: !isLoading,
                        ),

                        const SizedBox(height: 28),

                        // ── CTA button ─────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                (_isPhoneValid && !isLoading) ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ctaColor,
                              disabledBackgroundColor:
                                  _ctaColor.withOpacity(0.45),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Продолжить',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),

                        const Spacer(),

                        // ── Terms ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _TermsText(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone field widget ─────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.onChanged,
    required this.onValidated,
    required this.enabled,
  });

  final ValueChanged<PhoneNumber> onChanged;
  final ValueChanged<PhoneNumber> onValidated;
  final bool enabled;

  static const _primaryColor = Color(0xFF4B6EF5);

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: 'KZ',
      decoration: InputDecoration(
        labelText: 'Номер телефона',
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintText: '700 000 0000',
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: const TextStyle(fontSize: 16, color: Color(0xFF0D1117)),
      dropdownTextStyle:
          const TextStyle(fontSize: 15, color: Color(0xFF0D1117)),
      flagsButtonPadding: const EdgeInsets.only(left: 12, right: 4),
      showDropdownIcon: true,
      dropdownIconPosition: IconPosition.trailing,
      dropdownIcon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF6B7280),
        size: 20,
      ),
      keyboardType: TextInputType.phone,
      enabled: enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onChanged,
      onCountryChanged: (_) {},
      invalidNumberMessage: 'Введите корректный номер телефона',
    );
  }
}

// ── Terms text ─────────────────────────────────────────────────────────────────

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9CA3AF),
          height: 1.6,
        ),
        children: [
          const TextSpan(
            text: 'Регистрируясь, вы соглашаетесь с нашими ',
          ),
          TextSpan(
            text: 'Условиями использования',
            style: const TextStyle(
              color: Color(0xFF4B6EF5),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF4B6EF5),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // TODO: Open terms URL
              },
          ),
          const TextSpan(text: ' и '),
          TextSpan(
            text: 'Политикой конфиденциальности',
            style: const TextStyle(
              color: Color(0xFF4B6EF5),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF4B6EF5),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // TODO: Open privacy URL
              },
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
