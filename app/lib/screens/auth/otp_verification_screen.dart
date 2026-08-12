import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum _OtpChannel { telegram, whatsapp, sms }

// ── Screen ─────────────────────────────────────────────────────────────────────

class OTPVerificationScreen extends ConsumerStatefulWidget {
  const OTPVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState
    extends ConsumerState<OTPVerificationScreen> {
  static const _primaryColor = Color(0xFF4B6EF5);
  static const _ctaColor = Color(0xFFFF3B5C);
  static const _errorColor = Color(0xFFFF3B5C);
  static const _timerDuration = 30;

  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  _OtpChannel _currentChannel = _OtpChannel.telegram;
  bool _hasError = false;
  bool _isVerifying = false;
  int _secondsLeft = _timerDuration;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _timerDuration;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
          _canResend = true;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // ── Deep links ─────────────────────────────────────────────────────────────

  Future<void> _openTelegram() async {
    const url = 'tg://resolve?domain=HidavoBot';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web
      await launchUrl(
        Uri.parse('https://t.me/HidavoBot'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _openWhatsApp() async {
    // Format phone for WhatsApp (remove leading +)
    final cleaned = widget.phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Verification ───────────────────────────────────────────────────────────

  Future<void> _verify(String code) async {
    if (code.length != 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .verifyOtp(widget.phone, code);

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (result.success) {
      if (result.isNewUser) {
        context.go(AppRoutes.register);
      } else {
        context.go(AppRoutes.activity);
      }
    } else {
      setState(() => _hasError = true);
      _pinController.clear();
      _pinFocus.requestFocus();
    }
  }

  // ── Resend ─────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (!_canResend) return;

    setState(() => _hasError = false);
    _pinController.clear();

    final success = await ref
        .read(authNotifierProvider.notifier)
        .sendOtp(widget.phone);

    if (!mounted) return;
    if (success) _startTimer();
  }

  void _switchChannel(_OtpChannel channel) {
    setState(() {
      _currentChannel = channel;
      _hasError = false;
      _pinController.clear();
    });
    _resend();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _channelLabel {
    switch (_currentChannel) {
      case _OtpChannel.telegram:
        return 'Telegram';
      case _OtpChannel.whatsapp:
        return 'WhatsApp';
      case _OtpChannel.sms:
        return 'SMS';
    }
  }

  String get _timerLabel {
    final s = _secondsLeft;
    return '0:${s.toString().padLeft(2, '0')}';
  }

  // ── Pin theme ──────────────────────────────────────────────────────────────

  PinTheme _buildPinTheme({required bool isActive, required bool hasError}) {
    Color border;
    Color background;

    if (hasError) {
      border = _errorColor;
      background = _errorColor.withOpacity(0.06);
    } else if (isActive) {
      border = _primaryColor;
      background = _primaryColor.withOpacity(0.06);
    } else {
      border = const Color(0xFFE5E7EB);
      background = const Color(0xFFF9FAFB);
    }

    return PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: hasError ? _errorColor : const Color(0xFF0D1117),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isActive ? 2 : 1.5),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading || _isVerifying;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Color(0xFF0D1117)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  'Код из $_channelLabel',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1117),
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Введите 6-значный код, отправленный на\n${widget.phone}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                // ── PIN input ──────────────────────────────────────────────
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pinController,
                    focusNode: _pinFocus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: _buildPinTheme(
                        isActive: false, hasError: _hasError),
                    focusedPinTheme: _buildPinTheme(
                        isActive: true, hasError: _hasError),
                    errorPinTheme: _buildPinTheme(
                        isActive: false, hasError: true),
                    separatorBuilder: (_) => const SizedBox(width: 10),
                    onCompleted: _verify,
                    onChanged: (_) {
                      if (_hasError) setState(() => _hasError = false);
                    },
                    readOnly: isLoading,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Error message ──────────────────────────────────────────
                AnimatedOpacity(
                  opacity: _hasError ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(
                    child: Text(
                      'Неверный код. Попробуйте ещё раз.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Loading indicator ──────────────────────────────────────
                if (isLoading)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_primaryColor),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Open Telegram / WhatsApp button ────────────────────────
                _ChannelButton(
                  channel: _currentChannel,
                  onOpenTelegram: _openTelegram,
                  onOpenWhatsApp: _openWhatsApp,
                ),

                const SizedBox(height: 24),

                // ── Timer / resend ─────────────────────────────────────────
                Center(
                  child: _canResend
                      ? _ResendOptions(
                          currentChannel: _currentChannel,
                          onResendSameChannel: _resend,
                          onSwitchChannel: _switchChannel,
                        )
                      : Text(
                          'Отправить снова через $_timerLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Channel deep-link button ───────────────────────────────────────────────────

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({
    required this.channel,
    required this.onOpenTelegram,
    required this.onOpenWhatsApp,
  });

  final _OtpChannel channel;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenWhatsApp;

  @override
  Widget build(BuildContext context) {
    if (channel == _OtpChannel.sms) return const SizedBox.shrink();

    final isTelegram = channel == _OtpChannel.telegram;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: isTelegram ? onOpenTelegram : onOpenWhatsApp,
        style: OutlinedButton.styleFrom(
          foregroundColor: isTelegram
              ? const Color(0xFF229ED9) // Telegram blue
              : const Color(0xFF25D366), // WhatsApp green
          side: BorderSide(
            color: isTelegram
                ? const Color(0xFF229ED9)
                : const Color(0xFF25D366),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(
          isTelegram ? Icons.send_rounded : Icons.chat_rounded,
          size: 20,
        ),
        label: Text(
          isTelegram ? 'Открыть Telegram' : 'Получить в WhatsApp',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Resend options ─────────────────────────────────────────────────────────────

class _ResendOptions extends StatelessWidget {
  const _ResendOptions({
    required this.currentChannel,
    required this.onResendSameChannel,
    required this.onSwitchChannel,
  });

  final _OtpChannel currentChannel;
  final VoidCallback onResendSameChannel;
  final ValueChanged<_OtpChannel> onSwitchChannel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Resend same channel
        TextButton(
          onPressed: onResendSameChannel,
          child: Text(
            'Отправить снова',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B6EF5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Alternative channel options
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (currentChannel != _OtpChannel.telegram)
              _AltChannelChip(
                label: 'Telegram',
                onTap: () => onSwitchChannel(_OtpChannel.telegram),
              ),
            if (currentChannel != _OtpChannel.telegram &&
                currentChannel != _OtpChannel.whatsapp)
              const SizedBox(width: 8),
            if (currentChannel != _OtpChannel.whatsapp)
              _AltChannelChip(
                label: 'WhatsApp',
                onTap: () => onSwitchChannel(_OtpChannel.whatsapp),
              ),
            if (currentChannel != _OtpChannel.sms) ...[
              const SizedBox(width: 8),
              _AltChannelChip(
                label: 'SMS',
                onTap: () => onSwitchChannel(_OtpChannel.sms),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AltChannelChip extends StatelessWidget {
  const _AltChannelChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
