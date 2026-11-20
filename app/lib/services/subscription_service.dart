import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

import '../config/superwall_ids.dart';

/// Weekly Premium entitlement, powered by Superwall.
///
/// Source of truth for paid access is the Superwall `pro` entitlement.
/// The local flag doubles as a test/debug override (used by widget tests and
/// as a graceful fallback when Superwall is not configured). It
/// intentionally survives Reset game.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String _activeKey = 'sub_pro_active';
  static const String _productKey = 'sub_pro_product_id';
  static const String _updatedKey = 'sub_pro_updated_at';
  static const String _installIdKey = 'superwall_install_id';

  /// Current Pro state for reactive UI.
  final ValueNotifier<bool> proListenable = ValueNotifier(false);

  /// True while a purchase sheet is expected to be on screen.
  final ValueNotifier<bool> purchasePending = ValueNotifier(false);

  /// One-shot user-facing message for the paywall to show and clear.
  final ValueNotifier<String?> notice = ValueNotifier(null);

  StreamSubscription<SubscriptionStatus>? _statusSub;
  bool _initialized = false;
  bool _ready = false;
  bool _entitlementActive = false;

  /// True once Superwall is configured and reachable.
  bool get billingReady => _ready;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> _localOverride() async =>
      (await _prefs).getBool(_activeKey) ?? false;

  /// Local override OR live Superwall entitlement.
  Future<bool> isPro() async {
    if (await _localOverride()) return true;
    return _entitlementActive;
  }

  /// Sets the local override (tests/debug). Production access comes from
  /// the Superwall entitlement; this never revokes it.
  Future<void> setPro(bool active, {String? productId}) async {
    final prefs = await _prefs;
    await prefs.setBool(_activeKey, active);
    if (productId != null) {
      await prefs.setString(_productKey, productId);
    }
    await prefs.setString(_updatedKey, DateTime.now().toIso8601String());
    proListenable.value = await isPro();
  }

  /// Attach to Superwall. Safe to call once at startup; extra calls are
  /// ignored. Never throws; without a configured SDK the service stays in
  /// local-flag mode.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _ready = await Superwall.shared.getIsConfigured();
    } catch (e) {
      debugPrint('Superwall not configured: $e');
      _ready = false;
    }
    if (!_ready) {
      proListenable.value = await isPro();
      return;
    }
    await _identifyInstall();
    await _setAttributes();
    try {
      _statusSub = Superwall.shared.subscriptionStatus.listen((status) async {
        await _refreshFromStatus(status);
      });
    } catch (e) {
      debugPrint('Superwall status stream failed: $e');
    }
    await refresh();
  }

  Future<void> _identifyInstall() async {
    try {
      final prefs = await _prefs;
      var id = prefs.getString(_installIdKey);
      if (id == null || id.isEmpty) {
        final random = Random.secure();
        id = base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
        await prefs.setString(_installIdKey, id);
      }
      await Superwall.shared.identify(id);
    } catch (e) {
      debugPrint('Superwall identify failed: $e');
    }
  }

  Future<void> _setAttributes() async {
    try {
      await Superwall.shared.setUserAttributes(const {
        'app': 'flyprox',
        'platform': 'ios',
        'locale': 'en',
      });
    } catch (e) {
      debugPrint('Superwall attributes failed: $e');
    }
  }

  Future<void> _refreshFromStatus(SubscriptionStatus status) async {
    var active = false;
    if (status is SubscriptionStatusActive) {
      active = status.entitlements
          .any((e) => e.id == SuperwallIds.proEntitlement);
    }
    _entitlementActive = active;
    proListenable.value = await isPro();
  }

  /// Re-read entitlements from the SDK (safe to call any time).
  Future<void> refresh() async {
    if (!_ready) return;
    try {
      final entitlements = await Superwall.shared.getEntitlements();
      _entitlementActive = entitlements.active
          .any((e) => e.id == SuperwallIds.proEntitlement);
    } catch (e) {
      debugPrint('Superwall entitlements check failed: $e');
    }
    proListenable.value = await isPro();
  }

  /// Store price label with a safe fallback.
  Future<String> priceLabel(String productId,
      {String fallback = '\$6.99'}) async {
    if (!_ready) return fallback;
    try {
      final products = await Superwall.shared.getProducts([productId]);
      if (products.isEmpty) return fallback;
      return products.first.localizedPrice;
    } catch (_) {
      return fallback;
    }
  }

  /// Buy through Superwall using our own paywall UI.
  Future<void> buyPro(String productId) async {
    if (!_ready) {
      notice.value = 'Purchases are not available on this device';
      return;
    }
    purchasePending.value = true;
    try {
      final result = await Superwall.shared.purchase(productId);
      if (result is PurchaseResultPurchased) {
        await refresh();
        notice.value = 'Premium activated! Welcome 👑';
      } else if (result is PurchaseResultCancelled) {
        notice.value = 'Purchase canceled';
      } else if (result is PurchaseResultPending) {
        notice.value = 'Purchase pending approval';
      } else if (result is PurchaseResultFailed) {
        notice.value = 'Error: ${result.error}';
      }
    } catch (e) {
      notice.value = 'Error: $e';
      debugPrint('Superwall purchase failed: $e');
    } finally {
      purchasePending.value = false;
    }
  }

  /// Restore past purchases through Superwall.
  Future<void> restore() async {
    if (!_ready) {
      notice.value = 'Purchases are not available on this device';
      return;
    }
    purchasePending.value = true;
    try {
      await Superwall.shared.restorePurchases();
      await refresh();
      notice.value = proListenable.value
          ? 'Premium restored! Welcome 👑'
          : 'No purchases found';
    } catch (e) {
      notice.value = 'Error: $e';
      debugPrint('Superwall restore failed: $e');
    } finally {
      purchasePending.value = false;
    }
  }

  /// Forget the anonymous install identity (game reset / account deletion).
  /// Paid access itself survives via the local override and Apple-ID restore.
  /// Never throws.
  Future<void> resetUser() async {
    final prefs = await _prefs;
    await prefs.remove(_installIdKey);
    if (!_ready) return;
    try {
      await Superwall.shared.reset();
    } catch (e) {
      debugPrint('Superwall reset failed: $e');
    }
    await _identifyInstall();
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    await _statusSub?.cancel();
    _statusSub = null;
    _initialized = false;
    _ready = false;
    _entitlementActive = false;
    proListenable.value = false;
    purchasePending.value = false;
    notice.value = null;
  }
}
