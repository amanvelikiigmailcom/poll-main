import 'push_driver.dart';
import 'storage_service.dart';
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
    'new_device': AppRoutes.signInNotice,
    'moderation': AppRoutes.accountUpdate,
  };

  static int _revision = 0;

  /// Refresh already mounted data destinations. Keep a pending round intact.
  static String? locationFor(PushTap tap) {
    final route = routeFor(tap.type);
    if (route == null || route == AppRoutes.vote) return route;
    return Uri(
      path: route,
      queryParameters: {
        'push': '${++_revision}',
        if (tap.actorId != null &&
            ['friend_request', 'friend_accepted'].contains(tap.type))
          'focus': tap.actorId!,
        if (tap.eventId != null) 'event': tap.eventId!,
      },
    ).toString();
  }

  /// Metadata is a navigation hint, never permission to read another account.
  static Future<bool> canOpen(PushTap tap, StorageService storage) async {
    if (!isKnown(tap.type)) return false;
    if (tap.recipientId == null) return true;
    if (storage.getUser()?.id != tap.recipientId) return false;
    final token = await storage.getToken();
    return token?.isNotEmpty == true &&
        storage.getUser()?.id == tap.recipientId;
  }

  static String? routeFor(String type) => _routes[type];

  static bool isKnown(String type) => _routes.containsKey(type);
}
