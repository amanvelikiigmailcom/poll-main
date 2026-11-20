import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/superwall_ids.dart';
import 'billing_gateway.dart';

/// Weekly Premium entitlement, powered by Superwall.
///
/// Source of truth for paid access is the Superwall `pro` entitlement.
/// The local flag doubles as a test/debug override. It intentionally
/// survives Reset game.
///
/// Every billing entry retries the SDK attach, so a transient failure at
/// startup (no network, slow init) never disables purchases permanently.
class SubscriptionService {
  SubscriptionService._() : _gateway = SuperwallGateway();
  static final SubscriptionService instance = SubscriptionService._();

  BillingGateway _gateway;

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

  StreamSubscription<Set<String>>? _statusSub;
  bool _ready = false;
  bool _entitlementActive = false;

  /// True once the billing backend is configured and reachable.
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

  /// Short install identifier for the diagnostics dialog.
  Future<String> debugInstallId() async {
    final id = (await _prefs).getString(_installIdKey);
    return (id == null || id.isEmpty) ? 'not set' : id;
  }

  /// Attach to the billing backend. Idempotent, retryable, never throws.
  Future<void> initialize() async {
    if (_ready) return;
    try {
      _ready = await _gateway.isConfigured();
    } catch (_) {
      _ready = false;
    }
    if (!_ready) {
      proListenable.value = await isPro();
      return;
    }
    await _identifyInstall();
    await _attachStatusListener();
    await refresh();
  }

  Future<void> _identifyInstall() async {
    try {
      final prefs = await _prefs;
      var id = prefs.getString(_installIdKey);
      if (id == null || id.isEmpty) {
        id = _newInstallId();
        await prefs.setString(_installIdKey, id);
      }
      await _gateway.identify(id);
    } catch (e) {
      debugPrint('Billing identify failed: $e');
    }
  }

  String _newInstallId() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
  }

  Future<void> _attachStatusListener() async {
    if (_statusSub != null) return;
    try {
      _statusSub = _gateway.watchActiveEntitlements().listen(
        (ids) async {
          _entitlementActive = ids.contains(SuperwallIds.proEntitlement);
          proListenable.value = await isPro();
        },
        onError: (Object e) => debugPrint('Billing status failed: $e'),
      );
    } catch (e) {
      debugPrint('Billing status attach failed: $e');
    }
  }

  Future<void> _ensureReady() async {
    if (!_ready) await initialize();
  }

  /// Re-read entitlements from the backend (safe to call any time).
  Future<void> refresh() async {
    await _ensureReady();
    if (!_ready) return;
    try {
      final ids = await _gateway.activeEntitlements();
      _entitlementActive = ids.contains(SuperwallIds.proEntitlement);
    } catch (e) {
      debugPrint('Billing entitlements check failed: $e');
    }
    proListenable.value = await isPro();
  }

  /// Store price label with a safe fallback.
  Future<String> priceLabel(String productId,
      {String fallback = '\$6.99'}) async {
    await _ensureReady();
    if (!_ready) return fallback;
    try {
      return await _gateway.priceFor(productId) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Buy through the billing backend using our own paywall UI.
  Future<void> buyPro(String productId) async {
    await _ensureReady();
    if (!_ready) {
      notice.value = 'Purchases are not available on this device';
      return;
    }
    purchasePending.value = true;
    try {
      final result = await _gateway.buy(productId);
      switch (result.outcome) {
        case BuyOutcome.purchased:
          await refresh();
          notice.value = 'Premium activated! Welcome 👑';
        case BuyOutcome.cancelled:
          notice.value = 'Purchase canceled';
        case BuyOutcome.pending:
          notice.value = 'Purchase pending approval';
        case BuyOutcome.failed:
          notice.value = 'Error: ${result.error}';
      }
    } catch (e) {
      notice.value = 'Error: $e';
      debugPrint('Billing purchase failed: $e');
    } finally {
      purchasePending.value = false;
    }
  }

  /// Restore past purchases through the billing backend.
  Future<void> restore() async {
    await _ensureReady();
    if (!_ready) {
      notice.value = 'Purchases are not available on this device';
      return;
    }
    purchasePending.value = true;
    try {
      await _gateway.restore();
      await refresh();
      notice.value = proListenable.value
          ? 'Premium restored! Welcome 👑'
          : 'No purchases found';
    } catch (e) {
      notice.value = 'Error: $e';
      debugPrint('Billing restore failed: $e');
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
      await _gateway.reset();
    } catch (e) {
      debugPrint('Billing reset failed: $e');
    }
    await _identifyInstall();
  }

  @visibleForTesting
  void debugGateway(BillingGateway gateway) {
    _gateway = gateway;
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    await _statusSub?.cancel();
    _statusSub = null;
    _gateway = SuperwallGateway();
    _ready = false;
    _entitlementActive = false;
    proListenable.value = false;
    purchasePending.value = false;
    notice.value = null;
  }
}
