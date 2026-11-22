import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';

/// Blocks the current app run, without terminating the iOS application.
class AgeBlockedScreen extends StatelessWidget {
  const AgeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFF4B6EF5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 54),
                const SizedBox(height: 24),
                const Text(
                  'Flyprox isn’t available for your age',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sorry, Flyprox is only available to people aged 13 and older.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.forParents),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  child: const Text('For Parents'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push(AppRoutes.privacy),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
