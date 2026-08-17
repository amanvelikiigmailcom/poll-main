import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/names_entry_screen.dart';
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

abstract final class AppRoutes {
  static const splash = '/';
  static const namesEntry = '/names';
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

  // Kept so leftover screens still compile. Not registered on the router.
  static const onboarding = '/onboarding';
  static const phone = '/phone';
  static const otp = '/otp';
  static const register = '/register';
  static const location = '/location';
  static const school = '/school';
  static const classSelect = '/class';
  static const username = '/username';
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
  static const settingsPoll = '/settings-poll';
  static const likesFilled = '/likes';
  static const likesEmpty = '/likes-empty';
  static const likesResult = '/likes-result';
  static const room = '/room';
  static const createRoom = '/create-room';
  static const faq = '/faq';
  static const forParents = '/for-parents';
}

class _SplashRedirect extends StatefulWidget {
  const _SplashRedirect();

  @override
  State<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final hasNames = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    context.go(hasNames ? AppRoutes.home : AppRoutes.namesEntry);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF4B6EF5),
      body: Center(
        child: Text(
          'Hidavo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const _SplashRedirect(),
    ),
    GoRoute(
      path: AppRoutes.namesEntry,
      builder: (_, __) => const NamesEntryScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
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
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen(),
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
        GoRoute(
          path: AppRoutes.privacy,
          builder: (_, __) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: AppRoutes.terms,
          builder: (_, __) => const TermsScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
