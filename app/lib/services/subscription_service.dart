import 'package:shared_preferences/shared_preferences.dart';

/// Local weekly Premium entitlement.
///
/// This build has no backend: the flag is set after a StoreKit purchase or
/// restore and lives in [SharedPreferences]. It intentionally survives
/// Reset game — the purchase belongs to the Apple Account, not to the local
/// game profile.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String _activeKey = 'sub_pro_active';
  static const String _productKey = 'sub_pro_product_id';
  static const String _updatedKey = 'sub_pro_updated_at';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> isPro() async => (await _prefs).getBool(_activeKey) ?? false;

  Future<void> setPro(bool active, {String? productId}) async {
    final prefs = await _prefs;
    await prefs.setBool(_activeKey, active);
    if (productId != null) {
      await prefs.setString(_productKey, productId);
    }
    await prefs.setString(_updatedKey, DateTime.now().toIso8601String());
  }
}
