import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

/// Dead end for underage users. There is intentionally no path back to the
/// age wheel: only For Parents (information) and Close.
class AgeBlockedScreen extends StatelessWidget {
  const AgeBlockedScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A1A4E), Color(0xFF0F3460)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Center(
                  child: Text('🔒', style: TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Not available for your age',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Flyprox is for ages 13 and up. This game isn’t available '
                  'for your age yet. Ask a parent or guardian if you have '
                  'questions.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.forParents),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('For Parents'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _close(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F3460),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
