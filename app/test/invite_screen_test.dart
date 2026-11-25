import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/invite_friend_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/invitation_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'fakes/social_storage.dart';

void main() {
  testWidgets('invite screen shows hero, actions and invitations', (
    tester,
  ) async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            data: request.path == '/api/invites/mine'
                ? {
                    'invites': [
                      {
                        'code': 'ABC123',
                        'status': 'activated',
                        'activated': true,
                      },
                    ],
                  }
                : <String, dynamic>{},
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          invitationServiceProvider.overrideWith(
            (ref) => InvitationService(api, storage),
          ),
          onboardingDetailsProvider.overrideWith(
            (ref) => OnboardingDetailsService(api, storage),
          ),
        ],
        child: const MaterialApp(home: InviteFriendScreen()),
      ),
    );
    // Adaptive polling does not block these bounded initial rendering pumps.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('One friend. One more round.'), findsOneWidget);
    expect(find.text('Invite through Messages'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('My invitations'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Code ABC123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
