import '../router/app_router.dart';

/// Maps backend push types to the screen each tap must open. Unknown types
/// stay unrouted (null): the app keeps its current route instead of guessing.
abstract final class PushRouting {
  static const _routes = <String, String>{
    'vote_received': AppRoutes.likesFilled,
    'round_ready': AppRoutes.vote,
    'inactive_1': AppRoutes.vote,
    'inactive_3': AppRoutes.vote,
    'inactive_7': AppRoutes.vote,
    'invitation_activated': AppRoutes.invite,
    'friend_request': AppRoutes.friendRequests,
    'friend_accepted': AppRoutes.friends,
    'premium_renewed': AppRoutes.premium,
    'premium_expiring': AppRoutes.premium,
    'new_device': AppRoutes.settings,
    'moderation': AppRoutes.settings,
  };

  static String? routeFor(String type) => _routes[type];

  static bool isKnown(String type) => _routes.containsKey(type);
}
