import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/invite_friend_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/invitation_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'fakes/social_storage.dart';

void main() {
  for (final channel in ['messages', 'whatsapp']) {
    testWidgets(
      '$channel invite explains sending and cancels without creating an invitation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = SessionStorage();
        final api = ApiService(storage);
        final requests = <RequestOptions>[];
        final nativeCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(InvitationService.messages, (call) async {
              nativeCalls.add(call);
              return null; // User cancels the native contact picker.
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(InvitationService.messages, null);
        });
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
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
                      : {
                          'userId': 'owner',
                          'version': 2,
                          'balance': 0,
                          'earned': 0,
                          'used': 0,
                          'rewards': [],
                          'redemptions': [],
                          'preferredChannel': channel,
                          'policy': {
                            'enabled': true,
                            'buttonText': channel == 'messages'
                                ? 'Invite via Messages'
                                : 'Invite via WhatsApp',
                          },
                        },
                ),
              );
            },
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
        // A 5-second poll keeps the screen fresh; settle with bounded pumps.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('One friend. One more round.'), findsOneWidget);
        final button = find.text(
          channel == 'messages' ? 'Invite via Messages' : 'Invite via WhatsApp',
        );
        expect(button, findsOneWidget);
        expect(
          find.textContaining('Carrier charges may apply.'),
          channel == 'messages' ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('Nothing is sent until you tap Send.'),
          channel == 'messages' ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining('Raw contact numbers'), findsOneWidget);
        await tester.ensureVisible(button);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(button);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(nativeCalls, hasLength(1));
        expect(nativeCalls.single.method, 'pickRecipient');
        expect(nativeCalls.single.arguments, {
          'title': channel == 'messages'
              ? 'Choose a friend to message'
              : 'Choose a friend for WhatsApp',
        });
        expect(requests.where((request) => request.method == 'POST'), isEmpty);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('My invitations'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Code ABC123'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
