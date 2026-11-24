import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';

class WaitPassCard extends ConsumerStatefulWidget {
  const WaitPassCard({super.key, this.onCheck});
  final Future<void> Function()? onCheck;
  @override
  ConsumerState<WaitPassCard> createState() => _WaitPassCardState();
}

class _WaitPassCardState extends ConsumerState<WaitPassCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(invitationServiceProvider).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final passes = ref.watch(invitationServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              passes.balance == null
                  ? 'Wait passes: ${passes.signedIn ? 'check balance' : 'sign in to earn'}'
                  : passes.policyVersion == 2
                  ? 'Rounds available: ${passes.balance}'
                  : 'Wait passes left: ${passes.balance}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (passes.balance != null)
              Text(
                passes.policyVersion == 2
                    ? 'Rounds activated: ${passes.earned} · Used: ${passes.used}'
                    : 'Earned: ${passes.earned} · Used: ${passes.used}',
              ),
            if (passes.policyVersion == 2) ...[
              Text(
                'Messages sent: ${passes.messagesSent} · WhatsApp attempts: ${passes.whatsappAttempts}',
              ),
              Text(
                'WhatsApp instant unlocks today: ${passes.whatsappAdvancesToday}/${passes.whatsappAdvanceLimit}',
              ),
              if (passes.dailyRemaining != null)
                Text('Rounds left today: ${passes.dailyRemaining}/50'),
            ],
            if (passes.error != null) Text(passes.error!),
            TextButton(
              onPressed: widget.onCheck ?? () => context.push(AppRoutes.invite),
              child: Text(
                widget.onCheck != null
                    ? 'Refresh passes'
                    : 'Invitations and passes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
