import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/premium_service.dart';
import 'social_storage.dart';

class FakePremium extends PremiumService {
  FakePremium([SessionStorage? session])
    : super(
        ApiService(session ?? SessionStorage()),
        session ?? SessionStorage(),
      );
  bool active = false;
  int full = 2, initial = 5;
  String? revealed;
  Object? failure;
  int spends = 0;
  Map<String, dynamic> state() => {
    'userId': 'owner',
    'active': active,
    'remaining': {'full': full, 'initial': initial},
    'resetsAt': '2099-01-01T15:00:00Z',
    'gender': 'female',
    'graduationYear': 2028,
    'revealed': revealed,
    if (revealed == 'initial') 'initial': 'M',
    if (revealed == 'full') 'name': 'Maria Rivera',
  };
  @override
  Future<Map<String, dynamic>> status() async {
    if (failure != null) throw failure!;
    return state();
  }

  @override
  Future<Map<String, dynamic>> vote(String id) => status();
  @override
  Future<Map<String, dynamic>> reveal(String id, String kind) async {
    if (failure != null) throw failure!;
    spends++;
    if (kind == 'full') {
      full--;
    } else {
      initial--;
    }
    revealed = kind;
    return state();
  }

  @override
  Future<String> preparePurchase() async =>
      '12345678-1234-1234-1234-123456789abc';
}

Widget withPremium(
  Widget child, {
  FakePremium? premium,
  SessionStorage? storage,
}) {
  final session = storage ?? SessionStorage();
  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(session),
      premiumServiceProvider.overrideWithValue(premium ?? FakePremium(session)),
    ],
    child: child,
  );
}
