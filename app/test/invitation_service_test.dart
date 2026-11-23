import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/invitation_service.dart';
import 'package:flyprox_app/services/invite_code_store.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_secure_storage.dart';

class InviteApi extends ApiService {
  InviteApi(super.storage);
  int credits = 1, redeemCalls = 0, reads = 0;
  bool loseRedeemResponse = false, offline = false, claimFails = false;
  ApiException? claimError;
  bool composeFails = false, createFailsOnce = false;
  String accountId = 'account-a';
  Future<void> Function()? duringClaim;
  String? redeemedKey;
  Future<void> Function()? duringRedeem;
  final posts = <(String, dynamic)>[];
  final gate = Completer<void>();
  bool waitForGate = false;
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    reads++;
    if (waitForGate) await gate.future;
    if (offline) throw const ApiException('Offline');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          <String, dynamic>{
                'userId': accountId,
                'balance': credits,
                'earned': 1,
                'used': 1 - credits,
                'rewards': [
                  if (credits > 0) {'id': 'pass-a'},
                ],
                'redemptions': [
                  if (redeemedKey != null) {'cooldownKey': redeemedKey},
                ],
              }
              as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(requestOptions: RequestOptions(path: path));
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path, data));
    Map<String, dynamic> result = {};
    if (path.endsWith('/redeem')) {
      redeemCalls++;
      redeemedKey = data['cooldownKey'];
      credits = 0;
      if (duringRedeem != null) await duringRedeem!();
      if (loseRedeemResponse) {
        loseRedeemResponse = false;
        throw const ApiException('Connection lost');
      }
      result = {'redeemed': true, 'cooldownKey': redeemedKey};
    } else if (path.endsWith('/claim')) {
      if (claimFails) throw const ApiException('Offline');
      if (claimError != null) throw claimError!;
      if (duringClaim != null) await duringClaim!();
      result = {'claimed': true};
    } else if (path.endsWith('/compose-result')) {
      if (composeFails) throw const ApiException('Connection lost');
    } else if (path == '/api/invites') {
      if (createFailsOnce) {
        createFailsOnce = false;
        throw const ApiException('Connection lost');
      }
      result = {
        'code': 'ABC234',
        'url': 'https://api.flyprox.com/i/ABC234',
        'ownerUserId': accountId,
      };
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: result as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late InviteApi api;
  late InvitationService service;
  final game = LocalGameService.instance;
  setUp(() async {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.saveToken('session-a');
    api = InviteApi(storage);
    service = InvitationService(api, storage);
    await game.saveFullName('Aman', 'Smith');
  });
  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(InvitationService.messages, null);
  });

  test('a pass clears only the active wait and balance becomes zero', () async {
    await game.completeRound();
    await service.refresh();
    expect(await game.secondsUntilNextRound(), 0);
    expect(service.balance, 0);
    expect(service.used, 1);
    await service.refresh();
    expect(api.redeemCalls, 1);
  });
  test('pass is saved when there is no active wait', () async {
    await service.refresh();
    expect(service.balance, 1);
    expect(api.redeemCalls, 0);
  });
  test(
    'lost redeem response recovers after service restart without a second spend',
    () async {
      await game.completeRound();
      api.loseRedeemResponse = true;
      await service.refresh();
      expect(await game.secondsUntilNextRound(), greaterThan(0));
      service.dispose();
      service = InvitationService(api, storage);
      await service.refresh();
      expect(await game.secondsUntilNextRound(), 0);
      expect(api.redeemCalls, 1);
      expect(service.balance, 0);
    },
  );
  test('late response cannot clear a newer round waiting period', () async {
    await game.completeRound();
    final oldKey = await game.cooldownKey();
    api.duringRedeem = () async {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().firstWhere(
        (key) => prefs.get(key) == int.parse(oldKey!),
      );
      await prefs.setInt(key, int.parse(oldKey!) + 1000);
    };
    await service.refresh();
    expect(await game.secondsUntilNextRound(), greaterThan(0));
    expect(await game.cooldownKey(), isNot(oldKey));
  });
  test('parallel refreshes share one request and spend once', () async {
    await game.completeRound();
    api.waitForGate = true;
    final requests = List.generate(10, (_) => service.refresh());
    await Future<void>.delayed(Duration.zero);
    api.gate.complete();
    await Future.wait(requests);
    expect(api.redeemCalls, 1);
  });
  test(
    'offline balance is unknown, never a fabricated zero or an unlocked timer',
    () async {
      await game.completeRound();
      api.offline = true;
      await service.refresh();
      expect(service.balance, isNull);
      expect(service.error, isNotNull);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
    },
  );
  test(
    'switching account while checking cannot apply the previous account pass',
    () async {
      await game.completeRound();
      api.waitForGate = true;
      final pending = service.refresh();
      await Future<void>.delayed(Duration.zero);
      await storage.saveToken('different-session');
      api.gate.complete();
      await pending;
      expect(api.redeemCalls, 0);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
    },
  );
  test('cancelled Messages does not clear timer or report sent', () async {
    api.credits = 0;
    await game.completeRound();
    await service.refresh();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          InvitationService.messages,
          (call) async => 'cancelled',
        );
    final result = await service.compose({
      'code': 'ABC234',
      'url': 'https://api.flyprox.com/i/ABC234',
    });
    expect(result, 'cancelled');
    expect(await game.secondsUntilNextRound(), greaterThan(0));
    expect(
      api.posts
          .where((p) => p.$1.endsWith('compose-result'))
          .single
          .$2['result'],
      'cancelled',
    );
    expect(api.redeemCalls, 0);
  });
  test(
    'pending pasted code survives failure and clears only after confirmed claim',
    () async {
      await InviteCodeStore.save(' abc234 ', 'pasted');
      await InviteCodeStore.accept();
      api.claimFails = true;
      await expectLater(service.claimPending(), throwsA(isA<ApiException>()));
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(await InviteCodeStore.source(), 'pasted');
      api.claimFails = false;
      expect(await service.claimPending(), true);
      expect(await InviteCodeStore.code(), isNull);
      final claim =
          api.posts.lastWhere((p) => p.$1.endsWith('/claim')).$2 as Map;
      expect(claim, {'code': 'ABC234', 'source': 'pasted'});
      expect(claim.containsKey('phone'), false);
    },
  );
  test(
    'received link is not claimed before user accepts attribution',
    () async {
      await InviteCodeStore.save('https://api.flyprox.com/i/ABC234', 'link');
      expect(await service.claimPending(), false);
      expect(api.posts, isEmpty);
      expect(await InviteCodeStore.code(), 'ABC234');
    },
  );
  test(
    'phone-match registration attempt survives offline signup without a code',
    () async {
      api.claimFails = true;
      await expectLater(
        service.completeRegistration(),
        throwsA(isA<ApiException>()),
      );
      expect(await service.registrationPending(), true);
      service.dispose();
      service = InvitationService(api, storage);
      api.claimFails = false;
      expect(await service.registrationPending(), true);
      expect(await service.claimPending(), true);
      expect(await service.registrationPending(), false);
      expect(
        api.posts
            .lastWhere((p) => p.$1.endsWith('/claim'))
            .$2
            .containsKey('code'),
        false,
      );
    },
  );

  test(
    'switching accounts during claim cannot clear the code or spend a pass for the next user',
    () async {
      await storage.savePhone('+16505550000');
      await game.completeRound();
      await InviteCodeStore.save('ABC234', 'typed');
      await InviteCodeStore.accept();
      api.duringClaim = () async {
        await storage.saveToken('session-b');
        await storage.savePhone('+16505550001');
        api.accountId = 'account-b';
      };
      expect(await service.completeRegistration(), false);
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(await InviteCodeStore.needsAttention(), true);
      expect(api.redeemCalls, 0);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
    },
  );

  test(
    'an expired code needs correction; a server outage remains retryable',
    () async {
      await InviteCodeStore.save('ABC234', 'typed');
      await InviteCodeStore.accept();
      api.claimError = const ApiException('Unavailable', statusCode: 503);
      await expectLater(
        service.completeRegistration(),
        throwsA(isA<ApiException>()),
      );
      expect(await service.registrationPending(), true);
      expect(await InviteCodeStore.needsAttention(), false);
      api.claimError = const ApiException('Expired', statusCode: 410);
      await expectLater(service.claimPending(), throwsA(isA<ApiException>()));
      expect(await InviteCodeStore.code(), 'ABC234');
      expect(await service.registrationPending(), false);
      expect(await InviteCodeStore.needsAttention(), true);
      await InviteCodeStore.save('DEF678', 'typed');
      expect(await InviteCodeStore.needsAttention(), false);
    },
  );

  test(
    'a successful old claim never discards a different code entered while waiting',
    () async {
      await InviteCodeStore.save('ABC234', 'typed');
      await InviteCodeStore.accept();
      api.duringClaim = () async {
        await InviteCodeStore.save('DEF678', 'typed');
        await InviteCodeStore.accept();
      };
      expect(await service.claimPending(), true);
      expect(await InviteCodeStore.code(), 'DEF678');
      expect(await InviteCodeStore.accepted(), true);
    },
  );

  test(
    'sent compose telemetry survives an outage and restart, but never flushes as another account',
    () async {
      api.credits = 0;
      await game.completeRound();
      await service.refresh();
      api.composeFails = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            InvitationService.messages,
            (_) async => 'sent',
          );
      expect(
        await service.compose({
          'code': 'ABC234',
          'url': 'https://api.flyprox.com/i/ABC234',
        }),
        'sent',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('invite_compose_queue_v1'), hasLength(1));
      expect(
        prefs.getStringList('invite_compose_queue_v1').toString(),
        isNot(contains('session-a')),
      );
      service.dispose();
      service = InvitationService(api, storage);
      api.composeFails = false;
      api.accountId = 'account-b';
      await storage.saveToken('session-b');
      await service.refresh();
      expect(prefs.getStringList('invite_compose_queue_v1'), hasLength(1));
      expect(
        api.posts.where((p) => p.$1.endsWith('compose-result')),
        hasLength(1),
      );
      api.accountId = 'account-a';
      await storage.saveToken('session-a');
      await service.refresh();
      expect(prefs.getStringList('invite_compose_queue_v1'), isEmpty);
      expect(
        api.posts.where((p) => p.$1.endsWith('compose-result')),
        hasLength(2),
      );
      expect(api.redeemCalls, 0);
      expect(await game.secondsUntilNextRound(), greaterThan(0));
    },
  );

  test(
    'create retry reuses its request ID after restart and never persists the selected raw number',
    () async {
      await storage.savePhone('+16505550000');
      const selected = '+16505550123';
      api.createFailsOnce = true;
      await expectLater(
        service.create(phone: selected),
        throwsA(isA<ApiException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().map((key) => prefs.get(key).toString()).join(),
        isNot(contains(selected)),
      );
      service.dispose();
      service = InvitationService(api, storage);
      expect((await service.create(phone: selected))['code'], 'ABC234');
      final requests = api.posts.where((p) => p.$1 == '/api/invites').toList();
      expect(requests, hasLength(2));
      expect(requests.first.$2['requestId'], requests.last.$2['requestId']);
      expect(prefs.getString('invite_creation_request_v1'), isNull);
    },
  );
}
