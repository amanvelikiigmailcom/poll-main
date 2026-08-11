import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';

/// No "school wait / few participants" gate.
/// ≥3 friends → vote. Otherwise → names onboarding.
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
    context.go(ready ? AppRoutes.vote : AppRoutes.namesEntry);
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
