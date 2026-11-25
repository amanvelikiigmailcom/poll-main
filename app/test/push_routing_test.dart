import 'package:flyprox_app/services/push_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/push_routing.dart';

void main() {
  test('every backend push type routes to its meaningful screen', () {
    expect(PushRouting.routeFor('vote_received'), AppRoutes.likesFilled);
    expect(PushRouting.routeFor('round_ready'), AppRoutes.vote);
    expect(PushRouting.routeFor('inactive_1'), AppRoutes.vote);
    expect(PushRouting.routeFor('inactive_3'), AppRoutes.vote);
    expect(PushRouting.routeFor('inactive_7'), AppRoutes.vote);
    expect(PushRouting.routeFor('invitation_activated'), AppRoutes.invite);
    expect(PushRouting.routeFor('friend_request'), AppRoutes.friendRequests);
    expect(PushRouting.routeFor('friend_accepted'), AppRoutes.friends);
    expect(PushRouting.routeFor('premium_renewed'), AppRoutes.premium);
    expect(PushRouting.routeFor('premium_expiring'), AppRoutes.premium);
    expect(PushRouting.routeFor('new_device'), AppRoutes.signInNotice);
    expect(PushRouting.routeFor('moderation'), AppRoutes.accountUpdate);
  });

  test(
    'payload decoding preserves only valid metadata and supports legacy types',
    () {
      expect(PushTap.fromPayload('vote_received')?.type, 'vote_received');
      final tap = PushTap.fromPayload({
        'type': 'friend_request',
        'recipientId': 'owner',
        'actorId': 'friend',
        'eventId': 'e1',
        'voterId': 'PRIVATE',
      });
      expect(tap?.recipientId, 'owner');
      expect(tap?.actorId, 'friend');
      expect(tap?.eventId, 'e1');
      for (final payload in [
        null,
        {},
        {'type': ''},
        {'type': 'vote_received', 'recipientId': 42},
        {'type': 'vote_received', 'recipientId': ''},
      ]) {
        expect(PushTap.fromPayload(payload), isNull);
      }
      expect(
        PushRouting.locationFor(const PushTap('round_ready')),
        AppRoutes.vote,
      );
    },
  );

  test('unknown and empty types stay unrouted', () {
    expect(PushRouting.routeFor('marketing'), isNull);
    expect(PushRouting.routeFor(''), isNull);
    expect(PushRouting.isKnown('vote_received'), isTrue);
    expect(PushRouting.isKnown('marketing'), isFalse);
  });
}
