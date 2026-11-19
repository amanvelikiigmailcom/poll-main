import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../router/app_router.dart';
import '../../services/subscription_service.dart';
import '../../utils/constants.dart';

/// Weekly Premium paywall ($6.99/week, product `premium_pro_weekly`).
///
/// Unlocks honest local benefits only: the full round Reveal, no 40-minute
/// wait, double stars and a profile badge. No backend in this build.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const Color primaryBlue = Color(0xFF4B6EF5);
  static const Color accentRed = Color(0xFFFF3B5C);
  static const Color gradientStart = Color(0xFF0D0D2B);
  static const Color gradientMid = Color(0xFF1A1A4E);
  static const Color gradientEnd = Color(0xFF0F3460);
  static const String fallbackPrice = '\$6.99';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _available = false;
  bool _loading = true;
  ProductDetails? _product;
  bool _purchasePending = false;

  @override
  void initState() {
    super.initState();
    _initIAP();
  }

  Future<void> _initIAP() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        if (mounted) {
          setState(() {
            _available = false;
            _loading = false;
          });
        }
        return;
      }

      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (Object e) {
          _showMessage('Purchase error: $e');
        },
      );

      final response = await _iap.queryProductDetails(
        {AppConstants.premiumProProductId},
      );
      if (!mounted) return;
      setState(() {
        _available = true;
        _loading = false;
        _product = response.productDetails.isEmpty
            ? null
            : response.productDetails.first;
      });
    } catch (_) {
      // No store on this platform (e.g. web): show the paywall with the
      // fallback price instead of hanging on the loader.
      if (mounted) {
        setState(() {
          _available = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _purchasePending = true);
      } else {
        if (mounted) setState(() => _purchasePending = false);
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await SubscriptionService.instance
              .setPro(true, productId: purchase.productID);
          _showMessage('Premium activated! Welcome 👑');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          _showMessage(
              'Error: ${purchase.error?.message ?? 'Unknown error'}');
        } else if (purchase.status == PurchaseStatus.canceled) {
          _showMessage('Purchase canceled');
        }
      }
    }
  }

  Future<void> _buy() async {
    if (!_available) {
      _showMessage('Purchases are not available on this device');
      return;
    }
    final product = _product;
    if (product == null) {
      _showMessage('Product not found. Please try again later.');
      return;
    }
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> _restorePurchases() async {
    await _iap.restorePurchases();
    _showMessage('Restoring purchases...');
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = _product?.price ?? fallbackPrice;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gradientStart, gradientMid, gradientEnd],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              if (_purchasePending)
                const LinearProgressIndicator(color: primaryBlue),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            const Text('👑', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            const Text(
                              'Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Unlock your full round',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            _buildProCard(priceLabel),
                            const SizedBox(height: 24),
                            _buildLegalBlock(priceLabel),
                            const SizedBox(height: 12),
                            _buildBottomSection(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildProCard(String priceLabel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.5), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Premium Weekly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text('💙', style: TextStyle(fontSize: 20)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'WEEK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$priceLabel / week · 1-week auto-renewing subscription',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeature(
            icon: Icons.visibility_outlined,
            text: 'Full Reveal — all 12 answers every round',
          ),
          _buildFeature(
            icon: Icons.timer_off_outlined,
            text: 'No 40-minute wait between rounds',
          ),
          _buildFeature(
            icon: Icons.star_outline,
            text: 'Stars ×2 for every completed round',
          ),
          _buildFeature(
            icon: Icons.verified_outlined,
            text: '✓ badge in your profile',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _purchasePending ? null : _buy,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Get Premium · $priceLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalBlock(String priceLabel) {
    return Text(
      'Premium Weekly ($priceLabel per week) is a 1-week auto-renewing '
      'subscription. Payment is charged to your Apple Account at confirmation '
      'of purchase. The subscription renews automatically unless cancelled at '
      'least 24 hours before the end of the current period. Manage or cancel '
      'anytime in your App Store account settings.',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        TextButton(
          onPressed: _restorePurchases,
          child: const Text(
            'Restore purchases',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push(AppRoutes.terms),
              child: const Text(
                'Terms of Use',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            const Text(
              '|',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.privacy),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
