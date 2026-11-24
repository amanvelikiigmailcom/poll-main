import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/collection_service.dart';
import 'fakes/social_storage.dart';
import 'fakes/collection_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'guest stars are not spendable and an error never substitutes cached stars',
    () async {
      final storage = SessionStorage()..token = null;
      final api = CollectionApiFake(storage);
      final shop = CollectionService(api, storage);
      addTearDown(shop.dispose);
      await shop.load();
      expect(shop.guest, isTrue);
      expect(shop.balance, isNull);
      storage.token = 'buyer';
      api.failLoad = true;
      await shop.load();
      expect(shop.error, isNotNull);
      expect(shop.balance, isNull);
      expect(api.requests, isEmpty);
    },
  );
  test(
    'lost acknowledgement persists ID across restart and retries below price without another debit',
    () async {
      final storage = SessionStorage();
      final api = CollectionApiFake(storage)..balance = 5000;
      final first = CollectionService(api, storage);
      await first.load();
      api.loseReply = true;
      expect(await first.purchase(first.catalog.first), isFalse);
      expect(first.pendingBoostId, 'four_questions');
      expect(api.balance, 0);
      first.dispose();
      final second = CollectionService(api, storage);
      addTearDown(second.dispose);
      await second.load();
      expect(second.balance, 0);
      expect(second.pendingBoostId, 'four_questions');
      expect(await second.purchase(second.catalog.last), isFalse);
      api.loseReply = false;
      expect(await second.purchase(second.catalog.first), isTrue);
      expect(api.requests.length, 2);
      expect(api.requests[0]['requestId'], api.requests[1]['requestId']);
      expect(api.balance, 0);
      expect(second.pendingBoostId, isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
  test(
    'double tap submits once; signed-out session cannot receive stale purchase result',
    () async {
      final storage = SessionStorage();
      final api = CollectionApiFake(storage);
      final shop = CollectionService(api, storage);
      addTearDown(shop.dispose);
      await shop.load();
      api.pending = Completer<void>();
      final buy = shop.purchase(shop.catalog.first);
      await Future<void>.delayed(Duration.zero);
      expect(await shop.purchase(shop.catalog.first), isFalse);
      await storage.clearToken();
      api.pending!.complete();
      expect(await buy, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(shop.balance, isNull);
      expect(shop.activeBoosts, isEmpty);
      expect(api.requests.length, 1);
    },
  );
  test(
    'definitive rejection clears the request and requires a fresh balance',
    () async {
      final storage = SessionStorage();
      final api = CollectionApiFake(storage)..rejectPurchase = 409;
      final shop = CollectionService(api, storage);
      addTearDown(shop.dispose);
      await shop.load();
      final boost = shop.catalog.first;
      expect(await shop.purchase(boost), isFalse);
      expect(shop.balance, isNull);
      expect(shop.pendingBoostId, isNull);
      expect(shop.purchaseError, 'Not enough stars.');
      expect(await shop.purchase(boost), isFalse);
      expect(api.requests.length, 1);
      api.rejectPurchase = null;
      await shop.load();
      expect(await shop.purchase(boost), isTrue);
      expect(api.balance, 20000);
      expect(shop.activeBoosts.single['remaining'], 4);
    },
  );
  test(
    'stale load after logout and insufficient balance never purchase',
    () async {
      final storage = SessionStorage();
      final api = CollectionApiFake(storage)..balance = 4999;
      final shop = CollectionService(api, storage);
      addTearDown(shop.dispose);
      await shop.load();
      expect(await shop.purchase(shop.catalog.first), isFalse);
      expect(api.requests, isEmpty);
      api.pending = Completer<void>();
      final load = shop.load();
      await Future<void>.delayed(Duration.zero);
      await storage.clearToken();
      api.pending!.complete();
      await load;
      expect(shop.balance, isNull);
    },
  );
}
