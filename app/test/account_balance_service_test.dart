import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/account_balance_service.dart';
import 'package:flyprox_app/services/api_service.dart';

void main() {
  test('guest stars stay local; signed-in stars use absolute server balance and isolated cache', () async {
    String? token;
    dynamic balance = 17;
    var guestCalls = 0;
    final cache = <String,int>{};
    var fail = false;
    final service = AccountBalanceService(
      readToken: () async => token,
      guestBalance: () async { guestCalls++; return 5000; },
      fetchBalance: (_) async { if (fail) throw const ApiException('offline'); return balance; },
      readCached: (t) async => cache[t],
      writeCached: (t,n) async { cache[t]=n; },
    );
    expect(await service.load(),5000);
    token='account-A';
    expect(await service.load(),17);
    expect(await service.load(),17);
    expect(guestCalls,1);
    fail=true;
    expect(await service.load(),17);
    token='account-B';
    expect(await service.load(),isNull);
    fail=false;
    for (final invalid in [-1, 2.5, '1000', null, 9007199254740992]) {
      balance=invalid;
      expect(await service.load(),isNull);
    }
    expect(cache.containsKey('account-B'),false);
    token=null;
    expect(await service.load(),5000);
  });

  test('account switch ignores pending success and 401 never substitutes a cached balance', () async {
    String? token='A';
    final response=Completer<dynamic>();
    final writes=<String>[];
    final service=AccountBalanceService(
      readToken: () async => token, guestBalance: () async => 999,
      fetchBalance: (_) => response.future,
      readCached: (_) async => 100,
      writeCached: (t,_) async {writes.add(t);},
    );
    final pending=service.load();
    await Future<void>.delayed(Duration.zero);
    token='B'; response.complete(1000);
    expect(await pending,isNull);
    expect(writes,isEmpty);
    final denied=AccountBalanceService(
      readToken: () async => token,guestBalance: () async => 999,
      fetchBalance: (_) async => throw const ApiException('expired',statusCode:401),
      readCached: (_) async => 100,writeCached: (_,_) async {},
    );
    expect(await denied.load(),isNull);
  });
}
