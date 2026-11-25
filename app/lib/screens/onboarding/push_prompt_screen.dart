import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/service_providers.dart';
import '../../router/app_router.dart';

/// Optional notification prompt after eligible users complete contacts setup.
class PushPromptScreen extends ConsumerStatefulWidget {
  const PushPromptScreen({super.key});

  @override
  ConsumerState<PushPromptScreen> createState() => _PushPromptScreenState();
}

class _PushPromptScreenState extends ConsumerState<PushPromptScreen> {
  static const _primaryBlue = Color(0xFF4B6EF5);

  bool _busy = false;

  void _backToFriends() {
    context.go(AppRoutes.home);
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(pushServiceProvider).enable();
    if (!mounted) return;
    _backToFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
                      const Center(
                        child: Text('🔔', style: TextStyle(fontSize: 64)),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Know when you’re picked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Get notified when friends pick you. '
                        'No spam, just game updates — turn off anytime in Settings.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _enable,
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
                            _busy ? 'Enabling…' : 'Enable notifications',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _backToFriends,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Skip for now'),
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
