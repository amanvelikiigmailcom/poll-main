import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

/// Local mode: 3 classmates is enough. No "wait for school" gate.
/// Redirects straight into the vote intro or names onboarding.
class BeforeVoteScreen extends StatefulWidget {
  const BeforeVoteScreen({super.key});

  @override
  State<BeforeVoteScreen> createState() => _BeforeVoteScreenState();
}

class _BeforeVoteScreenState extends State<BeforeVoteScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final ready = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    // Ready (login + name + ≥3 friends) → how-it-works → vote
    // Not ready → back to names
    context.go(ready ? AppRoutes.beforeVote2 : AppRoutes.namesEntry);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );
  }
}
