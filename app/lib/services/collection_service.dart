import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'storage_service.dart';

class StarBoost {
  const StarBoost({required this.id, required this.title, required this.price});
  final String id;
  final String title;
  final int price;
  factory StarBoost.fromJson(Map<String, dynamic> json) {
    final price = json['price'];
    if (price is! int || price <= 0) {
      throw const FormatException('Invalid boost price');
    }
    return StarBoost(
      id: json['id'] as String,
      title: json['title'] as String,
      price: price,
    );
  }
}

/// Shop state never uses a cached/guest balance to authorize a purchase.
/// A confirmed purchase ID survives timeouts, screen changes and app restarts.
class CollectionService extends ChangeNotifier {
  CollectionService(this.api, this.storage) {
    storage.addListener(_accountChanged);
  }
  final ApiService api;
  final StorageService storage;
  bool loading = false;
  bool buying = false;
  bool guest = false;
  bool eligible = false;
  String? error;
  String? purchaseError;
  int? balance;
  List<StarBoost> catalog = [];
  List<Map<String, dynamic>> activeBoosts = [];
  String? _owner;
  String? get accountId => _owner;
  Map<String, String>? _pending;
  String? get pendingBoostId => _pending?['boostId'];
  int _epoch = 0;
  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String _pendingKey(String owner) => 'pending_star_purchase_v1_$owner';

  void _accountChanged() {
    _epoch++;
    balance = null;
    catalog = [];
    activeBoosts = [];
    _owner = null;
    _pending = null;
    buying = false;
    eligible = false;
    error = null;
    purchaseError = null;
    load();
  }

  Options _options(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<void> load() async {
    if (buying) return;
    final epoch = ++_epoch;
    loading = true;
    error = null;
    balance = null;
    _emit();
    try {
      final token = await storage.getToken();
      if (epoch != _epoch || _disposed) return;
      guest = token == null || token.isEmpty;
      if (guest) {
        catalog = [];
        activeBoosts = [];
        return;
      }
      final response = await api.get<Map<String, dynamic>>(
        '/api/collection',
        options: _options(token!),
      );
      if (token != await storage.getToken() || epoch != _epoch || _disposed) {
        return;
      }
      _apply(response.data!);
      final saved = (await SharedPreferences.getInstance()).getString(
        _pendingKey(_owner!),
      );
      if (epoch != _epoch || _disposed) return;
      _pending = saved == null
          ? null
          : Map<String, String>.from(jsonDecode(saved) as Map);
    } catch (failure) {
      if (epoch == _epoch && !_disposed) {
        error = failure is ApiException && failure.statusCode == 503
            ? 'Boosts are not available yet. Please try again later.'
            : 'Couldn’t load your balance. Please try again.';
      }
    } finally {
      if (epoch == _epoch && !_disposed) {
        loading = false;
        _emit();
      }
    }
  }

  void _apply(Map<String, dynamic> data) {
    final value = data['balance'];
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const FormatException('Invalid balance');
    }
    final owner = data['userId'] as String;
    final items = (data['catalog'] as List)
        .map(
          (item) => StarBoost.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final active = (data['activeBoosts'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    balance = value;
    _owner = owner;
    eligible = data['eligible'] == true;
    catalog = items;
    activeBoosts = active;
  }

  Future<bool> purchase(StarBoost boost) async {
    if (buying ||
        error != null ||
        loading ||
        guest ||
        balance == null ||
        _owner == null ||
        (_pending != null && pendingBoostId != boost.id)) {
      return false;
    }
    // A pending operation may already have committed. Retry it even when the
    // refreshed balance is below its price; the server checks replay first.
    if (_pending == null && (!eligible || balance! < boost.price)) return false;
    buying = true;
    purchaseError = null;
    final epoch = _epoch, owner = _owner!;
    _emit();
    try {
      final token = await storage.getToken();
      if (token == null || token.isEmpty || epoch != _epoch || _disposed) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _epoch || _disposed) return false;
      _pending ??= {
        'boostId': boost.id,
        'requestId': List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      };
      final request = Map<String, String>.from(_pending!);
      if (!await prefs.setString(_pendingKey(owner), jsonEncode(request))) {
        throw StateError('Could not persist purchase request');
      }
      if (token != await storage.getToken() || epoch != _epoch || _disposed) {
        return false;
      }
      final response = await api.post<Map<String, dynamic>>(
        '/api/boosts/purchases',
        data: request,
        options: _options(token),
      );
      if (token != await storage.getToken() || epoch != _epoch || _disposed) {
        return false;
      }
      if (response.data?['userId'] != owner ||
          response.data?['purchaseId'] is! String) {
        throw const FormatException('Invalid purchase acknowledgement');
      }
      _apply(response.data!);
      // Clear only the request just resolved, even if the account has changed.
      if (prefs.getString(_pendingKey(owner)) == jsonEncode(request)) {
        await prefs.remove(_pendingKey(owner));
      }
      if (token != await storage.getToken() || epoch != _epoch || _disposed) {
        return false;
      }
      _pending = null;
      return true;
    } catch (failure) {
      if (epoch != _epoch || _disposed) return false;
      if (failure is ApiException &&
          [400, 403, 404, 409, 422].contains(failure.statusCode)) {
        await (await SharedPreferences.getInstance()).remove(
          _pendingKey(owner),
        );
        if (epoch != _epoch || _disposed) return false;
        _pending = null;
        balance = null; // require a fresh server read before another purchase
        purchaseError = failure.statusCode == 409
            ? failure.message
            : 'Couldn’t buy this boost. Please refresh and try again.';
      } else {
        purchaseError =
            'Purchase not confirmed. Tap “Check purchase” to safely retry.';
      }
      return false;
    } finally {
      if (epoch == _epoch && !_disposed) {
        buying = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    storage.removeListener(_accountChanged);
    super.dispose();
  }
}
