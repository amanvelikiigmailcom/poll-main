import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../services/content_service.dart';

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

  String _completePhone = '';
  bool _sending = false;

  Future<void> _submit() async {
    if (_completePhone.isEmpty || _sending) return;
    setState(() => _sending = true);
    final notifier = ref.read(authNotifierProvider.notifier);
    final result = await notifier.sendFirebaseCode(_completePhone);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.autoIdToken != null && result.success) {
      context.pop();
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

  @override
  Widget build(BuildContext context) {
    final available =
        ref.watch(authNotifierProvider.select((s) => s.isLoading)) == false &&
            ref.read(authNotifierProvider.notifier).isPhoneLoginAvailable;
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                'We’ll text you a code. Your number lets friends find you — '
                'nothing else changes in the game.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IntlPhoneField(
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    border: InputBorder.none,
                  ),
                  initialCountryCode: 'KZ',
                  disableLengthCheck: false,
                  onChanged: (PhoneNumber phone) {
                    setState(() => _completePhone =
                        phone.number.isEmpty ? '' : phone.completeNumber);
                  },
                ),
              ),
              if (!available) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Text(
                    'Phone login isn’t available in this build yet. '
                    'Play as a guest for now.',
                    style: TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.35),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      available && _completePhone.isNotEmpty && !_sending
                          ? _submit
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryBlue,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _sending ? 'Sending…' : 'Send code',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (ContentService.instance.flag('guest_enabled')) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _sending ? null : () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  child: const Text('Continue without login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
