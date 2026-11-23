import '../screens/registration/profile_details_screen.dart';
import '../screens/registration/school_setup_screen.dart';
import '../providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/social/social_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/names_entry_screen.dart';
import '../screens/registration/username_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/phone_registration_screen.dart';
import '../screens/auth/invitation_code_screen.dart';
import '../services/invite_code_store.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/onboarding/push_prompt_screen.dart';
import '../screens/voting/vote_screen.dart';
import '../screens/voting/star_received_screen.dart';
import '../screens/voting/timer_screen.dart';
import '../screens/social/invite_friend_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/delete_account_screen.dart';
import '../screens/info/how_to_use_screen.dart';
import '../screens/info/safety_center_screen.dart';
import '../screens/info/privacy_policy_screen.dart';
import '../screens/info/terms_screen.dart';
import '../screens/home/home_screen.dart';
import '../services/local_game_service.dart';
import '../widgets/common/app_shell.dart';
import '../widgets/common/push_listener.dart';
import '../widgets/common/startup_intro.dart';

import '../screens/info/faq_screen.dart';
import '../screens/info/for_parents_screen.dart';
import '../screens/social/activity_screen.dart';
import '../screens/profile/collection_screen.dart';
import '../screens/settings/notifications_settings_screen.dart';
import '../screens/settings/language_settings_screen.dart';
import '../screens/settings/hidden_users_screen.dart';
import '../screens/settings/settings_quiz_screen.dart';
import '../screens/social/likes_empty_screen.dart';
import '../screens/social/room_screen.dart';
import '../screens/social/create_room_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/premium/age_picker_screen.dart';
import '../screens/premium/age_blocked_screen.dart';
import '../services/age_gate_service.dart';
import '../services/onboarding_flow.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const namesEntry = '/names';
  static const profileDetails = '/profile-details';
  static const schoolSetup = '/school-setup';
  static const schoolWaiting = '/school-waiting';
  static const username = '/username';
  static const age = '/age';
  static const ageBlocked = '/age-blocked';
  static const vote = '/vote';
  static const starReceived = '/star-received';
  static const timer = '/timer';
  static const invite = '/invite';
  static const home = '/home';
  static const profile = '/home/profile';
  static const editProfile = '/edit-profile';
  static const settings = '/settings';
  static const deleteAccount = '/delete-account';
  static const howToUse = '/how-to-use';
  static const safetyCenter = '/safety-center';
  static const privacy = '/privacy';
  static const terms = '/terms';

  static const phone = '/phone';
  static const invitationCode = '/invitation-code';
  static const otp = '/otp';
  static const pushPrompt = '/push-prompt';

  // Kept so leftover screens still compile. Not registered on the router.
  static const register = '/register';
  static const location = '/location';
  static const school = '/school';
  static const classSelect = '/class';
  static const contacts = '/contacts';
  static const photo = '/photo';
  static const beforeVote = '/before-vote';
  static const beforeVote2 = '/before-vote-2';
  static const starTaking = '/star-taking';
  static const activity = '/home/activity';
  static const search = '/home/search';
  static const collection = '/collection';
  static const friends = '/friends';
  static const friendRequests = '/friend-requests';
  static const premium = '/premium';
  static const premiumResult = '/premium-result';
  static const notificationsSettings = '/notifications-settings';
  static const languageSettings = '/language-settings';
  static const blockedUsers = '/blocked-users';
  static const hiddenUsers = '/hidden-users';
  static const settingsQuiz = '/settings-quiz';
  static const likesFilled = '/likes';
  static const likesEmpty = '/likes-empty';
  static const likesResult = '/likes-result';
  static const room = '/room';
  static const createRoom = '/create-room';
  static const faq = '/faq';
  static const forParents = '/for-parents';
}

class _SplashRedirect extends ConsumerStatefulWidget {
  const _SplashRedirect();

  @override
  ConsumerState<_SplashRedirect> createState() => _SplashRedirectState();
}

Future<String?> _ageRedirect(BuildContext context, GoRouterState state) async {
  final age = AgeGateService.instance;
  final path = state.uri.path;
  const information = {
    AppRoutes.privacy,
    AppRoutes.terms,
    AppRoutes.forParents,
  };
  if (information.contains(path)) return null;
  if (age.status == AgeGateStatus.blocked) {
    return path == AppRoutes.ageBlocked ? null : AppRoutes.ageBlocked;
  }
  if (age.status == AgeGateStatus.unknown) {
    if ({
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.phone,
      AppRoutes.invitationCode,
      AppRoutes.otp,
    }.contains(path)) {
      return null;
    }
    if (path == AppRoutes.age && OnboardingFlow.instance.phoneComplete) {
      return null;
    }
    return age.replayIntroOnLaunch
        ? AppRoutes.onboarding
        : OnboardingFlow.instance.phoneComplete
        ? AppRoutes.age
        : AppRoutes.phone;
  }
  final setup = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(onboardingDetailsProvider);
  final details = await setup.read();
  const setupExempt = {
    AppRoutes.phone,
    AppRoutes.otp,
    AppRoutes.invitationCode,
    AppRoutes.onboarding,
    AppRoutes.privacy,
    AppRoutes.terms,
    AppRoutes.forParents,
  };
  if (!setupExempt.contains(path)) {
    final stage = details['stage'];
    if (stage == null &&
        {AppRoutes.schoolSetup, AppRoutes.schoolWaiting}.contains(path)) {
      return AppRoutes.profileDetails;
    }
    if (stage == 'profile' && path != AppRoutes.profileDetails) {
      return AppRoutes.profileDetails;
    }
    if (stage == 'school' &&
        path != AppRoutes.schoolSetup &&
        path != AppRoutes.profileDetails) {
      return AppRoutes.schoolSetup;
    }
    if (stage == 'contacts' &&
        !{
          AppRoutes.namesEntry,
          AppRoutes.username,
          AppRoutes.schoolSetup,
          AppRoutes.profileDetails,
        }.contains(path)) {
      return await LocalGameService.instance.hasEnoughNames()
          ? AppRoutes.username
          : AppRoutes.namesEntry;
    }
    if (path == AppRoutes.vote && !await setup.votingAllowed()) {
      return AppRoutes.schoolWaiting;
    }
  }
  if (path == AppRoutes.age || path == AppRoutes.ageBlocked) {
    return LocalGameService.instance.hasEnoughNames().then(
      (ready) async => ready
          ? (await LocalGameService.instance.isUsernameSetupPending()
                ? AppRoutes.username
                : AppRoutes.home)
          : AppRoutes.profileDetails,
    );
  }
  return null;
}

class _SplashRedirectState extends ConsumerState<_SplashRedirect> {
  Future<void> _redirect() async {
    if (AgeGateService.instance.replayIntroOnLaunch) {
      context.go(AppRoutes.onboarding);
      return;
    }
    final hasNames = await LocalGameService.instance.hasEnoughNames();
    final pendingUsername = await LocalGameService.instance
        .isUsernameSetupPending();
    if (!mounted) return;
    final introDone = ref.read(storageServiceProvider).isOnboardingDone();
    if (hasNames &&
        await InviteCodeStore.code() != null &&
        !await InviteCodeStore.accepted()) {
      if (mounted) context.go(AppRoutes.invitationCode, extra: true);
      return;
    }
    if (!mounted) return;
    context.go(
      hasNames
          ? (pendingUsername ? AppRoutes.username : AppRoutes.home)
          : introDone
          ? AppRoutes.phone
          : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) => StartupIntro(onComplete: _redirect);
}

final GoRouter appRouter = createAppRouter();

/// A fresh navigation tree for each app/test lifetime.
GoRouter createAppRouter({bool showInvitationIntro = true}) => GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  refreshListenable: Listenable.merge([
    AgeGateService.instance.statusListenable,
    OnboardingFlow.instance,
  ]),
  redirect: _ageRedirect,
  routes: [
    GoRoute(
      path: AppRoutes.profileDetails,
      builder: (_, __) => const ProfileDetailsScreen(),
    ),
    GoRoute(
      path: AppRoutes.schoolSetup,
      builder: (_, __) => const SchoolSetupScreen(),
    ),
    GoRoute(
      path: AppRoutes.schoolWaiting,
      builder: (_, __) => const SchoolWaitingScreen(),
    ),
    GoRoute(path: AppRoutes.age, builder: (_, __) => const AgePickerScreen()),
    GoRoute(
      path: AppRoutes.ageBlocked,
      builder: (_, __) => const AgeBlockedScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      builder: (_, __) => const PrivacyPolicyScreen(),
    ),
    GoRoute(path: AppRoutes.terms, builder: (_, __) => const TermsScreen()),
    GoRoute(
      path: AppRoutes.forParents,
      builder: (_, __) => const ForParentsScreen(),
    ),
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const _SplashRedirect(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.username,
      redirect: (_, __) async =>
          await LocalGameService.instance.hasEnoughNames()
          ? null
          : AppRoutes.namesEntry,
      builder: (_, __) => const UsernameScreen(),
    ),
    GoRoute(
      path: AppRoutes.namesEntry,
      builder: (_, __) => const NamesEntryScreen(),
    ),
    GoRoute(
      path: AppRoutes.phone,
      redirect: (_, __) async {
        if (!showInvitationIntro) return null;
        final pending = await InviteCodeStore.code();
        return await InviteCodeStore.seen() &&
                (pending == null || await InviteCodeStore.accepted())
            ? null
            : AppRoutes.invitationCode;
      },
      builder: (_, __) => const PhoneRegistrationScreen(),
    ),
    GoRoute(
      path: AppRoutes.invitationCode,
      builder: (_, state) =>
          InvitationCodeScreen(lateEntry: state.extra == true),
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (_, state) {
        final extra = state.extra;
        final phone = extra is Map ? extra['phone'] as String? ?? '' : '';
        final verificationId = extra is Map
            ? extra['verificationId'] as String?
            : null;
        return OTPVerificationScreen(
          phone: phone,
          verificationId: verificationId,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.pushPrompt,
      builder: (_, __) => const PushPromptScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        navigationShell: shell,
        child: PushListener(child: shell),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const HomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.vote,
              builder: (_, __) => const VoteScreen(),
            ),
            GoRoute(
              path: AppRoutes.starReceived,
              builder: (_, __) => const StarReceivedScreen(),
            ),
            GoRoute(
              path: AppRoutes.timer,
              builder: (_, __) => const TimerScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: AppRoutes.search,
          routes: [
            GoRoute(
              path: '/people/:id',
              builder: (_, state) => SocialScreen(
                page: SocialPage.person,
                userId: state.pathParameters['id'],
              ),
            ),
            GoRoute(
              path: AppRoutes.search,
              builder: (_, __) => const SocialScreen(page: SocialPage.search),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: AppRoutes.likesEmpty,
          routes: [
            GoRoute(
              path: AppRoutes.likesFilled,
              builder: (_, __) => const LikesEmptyScreen(),
            ),
            GoRoute(
              path: AppRoutes.likesEmpty,
              builder: (_, __) => const LikesEmptyScreen(),
            ),
            GoRoute(
              path: AppRoutes.likesResult,
              builder: (_, __) => const LikesEmptyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: AppRoutes.profile,
          routes: [
            GoRoute(
              path: AppRoutes.invite,
              builder: (_, __) => const InviteFriendScreen(),
            ),
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen(),
            ),
            GoRoute(
              path: AppRoutes.editProfile,
              builder: (_, __) => const EditProfileScreen(),
            ),
            GoRoute(
              path: AppRoutes.collection,
              builder: (_, __) => const CollectionScreen(),
            ),
            GoRoute(
              path: AppRoutes.premium,
              builder: (_, __) => const PremiumScreen(),
            ),
            // Retired fake-voters result URL leads back to the free game.
            GoRoute(
              path: AppRoutes.premiumResult,
              redirect: (_, __) => AppRoutes.home,
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, __) => const SettingsScreen(),
            ),
            GoRoute(
              path: AppRoutes.activity,
              builder: (_, __) => const ActivityScreen(),
            ),
            GoRoute(
              path: AppRoutes.deleteAccount,
              builder: (_, __) => const DeleteAccountScreen(),
            ),
            GoRoute(
              path: AppRoutes.howToUse,
              builder: (_, __) => const HowToUseScreen(),
            ),
            GoRoute(
              path: AppRoutes.safetyCenter,
              builder: (_, __) => const SafetyCenterScreen(),
            ),

            GoRoute(path: AppRoutes.faq, builder: (_, __) => const FaqScreen()),

            GoRoute(
              path: AppRoutes.friends,
              builder: (_, __) => const SocialScreen(page: SocialPage.friends),
            ),
            GoRoute(
              path: AppRoutes.friendRequests,
              builder: (_, __) => const SocialScreen(
                page: SocialPage.friends,
                initialKind: 'incoming',
              ),
            ),
            GoRoute(
              path: AppRoutes.notificationsSettings,
              builder: (_, __) => const NotificationsSettingsScreen(),
            ),
            GoRoute(
              path: AppRoutes.languageSettings,
              builder: (_, __) => const LanguageSettingsScreen(),
            ),
            GoRoute(
              path: AppRoutes.blockedUsers,
              builder: (_, __) => const SocialScreen(page: SocialPage.blocked),
            ),
            GoRoute(
              path: AppRoutes.hiddenUsers,
              builder: (_, __) => const HiddenUsersScreen(),
            ),
            GoRoute(
              path: AppRoutes.settingsQuiz,
              builder: (_, __) => const SettingsQuizScreen(),
            ),
            GoRoute(
              path: AppRoutes.room,
              builder: (_, __) => const RoomScreen(),
            ),
            GoRoute(
              path: AppRoutes.createRoom,
              builder: (_, __) => const CreateRoomScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (_, state) =>
      Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
);
