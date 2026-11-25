import 'profile_social_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/local_game_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/wait_pass_card.dart';
import '../../providers/service_providers.dart';

final _campusProfileProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(onboardingDetailsProvider).campusProfile();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userNotifierProvider);
    final user = userState.user;
    final local = ref.watch(localProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: userState.isLoading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: ProfileSkeleton(),
              )
            : RefreshIndicator(
                color: AppColors.primaryBlue,
                onRefresh: () async {
                  await ref.read(localProfileProvider.notifier).refresh();
                  ref.invalidate(_campusProfileProvider);
                  ref.invalidate(starBalanceProvider);
                  ref.invalidate(socialSummaryProvider);
                  ref.invalidate(profileIdentityProvider);
                  await ref.read(invitationServiceProvider).refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _ProfileHeaderCard(user: user, local: local),
                      const ProfileSocialSection(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: CollectionProfileCard(),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: WaitPassCard(),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _ProfileActions(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card: avatar + name + school + stats
// ---------------------------------------------------------------------------

class _ProfileHeaderCard extends ConsumerWidget {
  const _ProfileHeaderCard({this.user, required this.local});

  final User? user;
  final LocalProfile local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityState = ref.watch(profileIdentityProvider);
    final identity = identityState.isLoading || identityState.hasError
        ? null
        : identityState.asData?.value;
    final guest =
        !identityState.isLoading &&
        !identityState.hasError &&
        identityState.hasValue &&
        identity == null;
    final serverName = [
      identity?['firstName'],
      identity?['lastName'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    final displayName = !guest
        ? (serverName.isEmpty ? 'Your profile' : serverName)
        : local.playerName.isNotEmpty
        ? local.playerName
        : (user?.firstName ?? '');
    final login =
        identity?['username'] as String? ??
        (guest
            ? (local.username.isNotEmpty
                  ? local.username
                  : (user?.username ?? ''))
            : '');
    final username = login.isNotEmpty ? '@$login' : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 52,
            backgroundColor: Color(0xFFEFF1FE),
            child: Text('🙂', style: TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 14),
          // Display name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (identityState.isLoading) ...[
            const SizedBox(height: 48),
          ] else if (username.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              if (guest) {
                await showDialog<void>(
                  context: context,
                  builder: (_) => _UsernameEditor(initial: login),
                );
              } else {
                await context.push(AppRoutes.editProfile);
              }
              if (!context.mounted) return;
              ref.invalidate(profileIdentityProvider);
              ref.invalidate(_campusProfileProvider);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
          ),
          const Divider(height: 32),
          const _CampusProfileRow(),
        ],
      ),
    );
  }
}

class CollectionProfileCard extends ConsumerWidget {
  const CollectionProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(starBalanceProvider).asData?.value;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Text('⭐', style: TextStyle(fontSize: 30)),
        title: const Text(
          'Collection',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${balance == null ? 'Your stars' : '$balance stars'} · Promote yourself',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.collection),
      ),
    );
  }
}

class _UsernameEditor extends ConsumerStatefulWidget {
  const _UsernameEditor({required this.initial});
  final String initial;

  @override
  ConsumerState<_UsernameEditor> createState() => _UsernameEditorState();
}

class _UsernameEditorState extends ConsumerState<_UsernameEditor> {
  final form = GlobalKey<FormState>();
  late final controller = TextEditingController(text: widget.initial);
  String? error;
  bool saving = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      var name = controller.text.trim();
      final storage = ref.read(storageServiceProvider);
      final social = ref.read(socialServiceProvider);
      final token = await storage.getToken();
      if (!mounted) return;
      if (token?.isNotEmpty == true) name = await social.saveHandle(name);
      if (!mounted) return;
      if (token != await storage.getToken()) {
        throw const ApiException('Account changed. Try again.');
      }
      if (!mounted) return;
      await LocalGameService.instance.saveUsername(name);
      if (!mounted) return;
      await ref.read(localProfileProvider.notifier).refresh();
      ref.invalidate(profileIdentityProvider);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = failure is ApiException
              ? failure.message
              : 'Couldn’t save your username. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit username'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        enabled: !saving,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          prefixText: '@',
          labelText: 'Username',
          helperText: '3–32 characters: A–Z, numbers or _',
          helperMaxLines: 3,
          errorText: error,
          errorMaxLines: 4,
        ),
        validator: (value) => LocalGameService.validateUsername(value ?? ''),
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save username'),
      ),
    ],
  );
}

class _CampusProfileRow extends ConsumerWidget {
  const _CampusProfileRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(_campusProfileProvider);
    final info = result.isLoading || result.hasError
        ? null
        : result.asData?.value;
    final campus = info?.data['school'] as Map?;
    final name = campus?['name'] as String? ?? '';
    final location = [
      campus?['city'],
      campus?['region'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
    final year = info?.data['graduationYear'] as int?;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.school_outlined, color: AppColors.primaryBlue),
      title: const Text(
        'Campus',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        result.isLoading
            ? 'Loading…'
            : result.hasError
            ? 'Couldn’t load your campus.'
            : [
                if (campus == null)
                  'No campus selected'
                else if (name.isNotEmpty)
                  name
                else
                  'Campus selected',
                if (location.isNotEmpty) location,
                if (year != null) 'Class of $year',
              ].join('\n'),
      ),
      trailing: result.hasError
          ? TextButton(
              onPressed: () => ref.invalidate(_campusProfileProvider),
              child: const Text('Retry'),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _ProfileActions extends StatelessWidget {
  const _ProfileActions();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Share Flyprox'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.invite),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('How to use'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.howToUse),
          ),
        ],
      ),
    );
  }
}
