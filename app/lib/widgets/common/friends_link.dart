import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';

class FriendsLink extends ConsumerWidget {
  const FriendsLink({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(socialSummaryProvider).asData?.value;
    final count = summary?['friendsCount'] as int?;
    final incoming = summary?['incomingCount'] as int? ?? 0;
    return ListTile(
      leading: const Icon(Icons.people_outline_rounded),
      title: const Text('Friends'),
      subtitle: Text(
        count == null
            ? 'Your friends and requests'
            : '$count ${count == 1 ? 'friend' : 'friends'}${incoming == 0 ? '' : ' · $incoming new ${incoming == 1 ? 'request' : 'requests'}'}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.friends),
    );
  }
}
