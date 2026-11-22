import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

enum BuyOutcome { purchased, cancelled, pending, failed }

class BuyResult {
  const BuyResult(this.outcome, {this.error = ''});
  final BuyOutcome outcome;
  final String error;
}

/// Thin seam over the billing backend so tests can script purchases.
/// Production uses [SuperwallGateway]; every method degrades gracefully.
abstract class BillingGateway {
  Future<bool> isConfigured();
  Future<void> identify(String installId);
  Stream<Set<String>> watchActiveEntitlements();
  Future<Set<String>> activeEntitlements();
  Future<String?> priceFor(String productId);
  Future<BuyResult> buy(String productId);
  Future<void> restore();
  Future<void> reset();
}

class SuperwallGateway implements BillingGateway {
  @override
  Future<bool> isConfigured() async {
    try {
      return await Superwall.shared.getIsConfigured();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> identify(String installId) async {
    try {
      await Superwall.shared.identify(installId);
    } catch (e) {
      debugPrint('Superwall identify failed: $e');
    }
  }

  @override
  Stream<Set<String>> watchActiveEntitlements() {
    try {
      return Superwall.shared.subscriptionStatus.map((status) {
        if (status is SubscriptionStatusActive) {
          return status.entitlements.map((e) => e.id).toSet();
        }
        return <String>{};
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<Set<String>> activeEntitlements() async {
    // A failed check is not an empty entitlement set. Let the service keep
    // the last known access and show a retryable status instead.
    final entitlements = await Superwall.shared.getEntitlements();
    return entitlements.active.map((e) => e.id).toSet();
  }

  @override
  Future<String?> priceFor(String productId) async {
    try {
      final products = await Superwall.shared.getProducts([productId]);
      if (products.isEmpty) return null;
      return products.first.localizedPrice;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BuyResult> buy(String productId) async {
    try {
      final result = await Superwall.shared.purchase(productId);
      if (result is PurchaseResultPurchased) {
        return const BuyResult(BuyOutcome.purchased);
      } else if (result is PurchaseResultCancelled) {
        return const BuyResult(BuyOutcome.cancelled);
      } else if (result is PurchaseResultPending) {
        return const BuyResult(BuyOutcome.pending);
      } else if (result is PurchaseResultFailed) {
        return BuyResult(BuyOutcome.failed, error: result.error);
      }
      return const BuyResult(BuyOutcome.failed, error: 'Unknown result');
    } catch (e) {
      return BuyResult(BuyOutcome.failed, error: '$e');
    }
  }

  @override
  Future<void> restore() async {
    await Superwall.shared.restorePurchases();
  }

  @override
  Future<void> reset() async {
    try {
      await Superwall.shared.reset();
    } catch (e) {
      debugPrint('Superwall reset failed: $e');
    }
  }
}
