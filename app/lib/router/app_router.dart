import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/names_entry_screen.dart';
import '../screens/auth/phone_registration_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../services/local_game_service.dart';
import '../screens/registration/registration_screen.dart';
import '../screens/registration/location_screen.dart';
import '../screens/registration/school_screen.dart';
import '../screens/registration/class_screen.dart';
import '../screens/registration/username_screen.dart';
import '../screens/registration/contacts_screen.dart';
import '../screens/registration/photo_upload_screen.dart';
import '../screens/voting/before_vote_screen.dart';
import '../screens/voting/before_vote2_screen.dart';
import '../screens/voting/vote_screen.dart';
import '../screens/voting/star_received_screen.dart';
import '../screens/voting/star_taking_screen.dart';
import '../screens/voting/timer_screen.dart';
import '../screens/social/invite_friend_screen.dart';
import '../screens/social/activity_screen.dart';
import '../screens/social/friends_list_screen.dart';
import '../screens/social/friend_requests_screen.dart';
import '../screens/social/search_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/profile_for_people_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/collection_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/premium/premium_result_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/notifications_settings_screen.dart';
import '../screens/settings/language_settings_screen.dart';
import '../screens/settings/blocked_users_screen.dart';
import '../screens/settings/hidden_users_screen.dart';
import '../screens/settings/delete_account_screen.dart';
import '../screens/settings/settings_poll_screen.dart';
import '../screens/social/likes_filled_screen.dart';
import '../screens/social/likes_empty_screen.dart';
import '../screens/social/likes_result_screen.dart';
import '../screens/social/room_screen.dart';
import '../screens/social/create_room_screen.dart';
import '../screens/info/faq_screen.dart';
import '../screens/info/how_to_use_screen.dart';
import '../screens/info/safety_center_screen.dart';
import '../screens/info/for_parents_screen.dart';
import '../screens/home/home_screen.dart';
import '../widgets/common/app_shell.dart';

// ---------------------------------------------------------------------------
// Route name constants
// ---------------------------------------------------------------------------
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const namesEntry = '/names';
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
  static const vote = '/vote';
  static const starReceived = '/star-received';
  static const starTaking = '/star-taking';
  static const timer = '/timer';
  static const invite = '/invite';

  // Bottom-nav shell home
  static const home = '/home';

  // Individual tab sub-routes (used as push destinations from within the shell)
  static const activity = '/home/activity';
  static const search = '/home/search';
  static const profile = '/home/profile';

  // Profile extras (pushed on top of shell)
  static const profileUser = '/profile/:userId';
  static const editProfile = '/edit-profile';
  static const collection = '/collection';

  // Social
  static const friends = '/friends';
  static const friendRequests = '/friend-requests';

  // Premium
  static const premium = '/premium';
  static const premiumResult = '/premium-result';

  // Settings
  static const settings = '/settings';
  static const notificationsSettings = '/notifications-settings';
  static const languageSettings = '/language-settings';
  static const blockedUsers = '/blocked-users';
  static const hiddenUsers = '/hidden-users';
  static const deleteAccount = '/delete-account';
  static const settingsPoll = '/settings-poll';

  // Likes
  static const likesFilled = '/likes';
  static const likesEmpty = '/likes-empty';
  static const likesResult = '/likes-result';

  // Rooms
  static const room = '/room';
  static const createRoom = '/create-room';

  // Info
  static const faq = '/faq';
  static const howToUse = '/how-to-use';
  static const safetyCenter = '/safety-center';
  static const forParents = '/for-parents';
}

// ---------------------------------------------------------------------------
// Splash / redirect widget
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // ── Splash ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const _SplashRedirect(),
    ),

    // ── Onboarding ──────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.namesEntry,
      builder: (_, __) => const NamesEntryScreen(),
    ),

    // ── Auth ─────────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.phone,
      builder: (_, __) => const PhoneRegistrationScreen(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (_, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OTPVerificationScreen(phone: phone);
      },
    ),

    // ── Registration flow ────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.register,
      builder: (_, __) => const RegistrationScreen(),
    ),
    GoRoute(
      path: AppRoutes.location,
      builder: (_, __) => const LocationScreen(),
    ),
    GoRoute(
      path: AppRoutes.school,
      builder: (_, __) => const SchoolScreen(),
    ),
    GoRoute(
      path: AppRoutes.classSelect,
      builder: (_, __) => const ClassScreen(),
    ),
    GoRoute(
      path: AppRoutes.username,
      builder: (_, __) => const UsernameScreen(),
    ),
    GoRoute(
      path: AppRoutes.contacts,
      builder: (_, __) => const ContactsScreen(),
    ),
    GoRoute(
      path: AppRoutes.photo,
      builder: (_, __) => const PhotoUploadScreen(),
    ),

    // Tab bar stays on every logged-in screen (Instagram-style).
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.beforeVote,
          builder: (_, __) => const BeforeVoteScreen(),
        ),
        GoRoute(
          path: AppRoutes.beforeVote2,
          builder: (_, __) => const BeforeVote2Screen(),
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
          path: AppRoutes.starTaking,
          builder: (_, __) => const StarTakingScreen(),
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
          path: AppRoutes.activity,
          builder: (_, __) => const ActivityScreen(),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, __) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (_, state) {
            final userId = state.pathParameters['userId']!;
            return ProfileForPeopleScreen(userId: userId);
          },
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
          path: AppRoutes.friends,
          builder: (_, __) => const FriendsListScreen(),
        ),
        GoRoute(
          path: AppRoutes.friendRequests,
          builder: (_, __) => const FriendRequestsScreen(),
        ),
        GoRoute(
          path: AppRoutes.premium,
          builder: (_, __) => const PremiumScreen(),
        ),
        GoRoute(
          path: AppRoutes.premiumResult,
          builder: (_, state) {
            final pollQuestion = state.uri.queryParameters['pollQuestion'];
            return PremiumResultScreen(pollQuestion: pollQuestion ?? '');
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen(),
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
          builder: (_, __) => const BlockedUsersScreen(),
        ),
        GoRoute(
          path: AppRoutes.hiddenUsers,
          builder: (_, __) => const HiddenUsersScreen(),
        ),
        GoRoute(
          path: AppRoutes.deleteAccount,
          builder: (_, __) => const DeleteAccountScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsPoll,
          builder: (_, __) => const SettingsPollScreen(),
        ),
        GoRoute(
          path: AppRoutes.likesFilled,
          builder: (_, __) => const LikesFilledScreen(),
        ),
        GoRoute(
          path: AppRoutes.likesEmpty,
          builder: (_, __) => const LikesEmptyScreen(),
        ),
        GoRoute(
          path: AppRoutes.likesResult,
          builder: (_, __) => const LikesResultScreen(),
        ),
        GoRoute(
          path: AppRoutes.room,
          builder: (_, __) => const RoomScreen(),
        ),
        GoRoute(
          path: AppRoutes.createRoom,
          builder: (_, __) => const CreateRoomScreen(),
        ),
        GoRoute(
          path: AppRoutes.faq,
          builder: (_, __) => const FaqScreen(),
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
          path: AppRoutes.forParents,
          builder: (_, __) => const ForParentsScreen(),
        ),
      ],
    ),
  ],

  // Global error page
  errorBuilder: (_, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
