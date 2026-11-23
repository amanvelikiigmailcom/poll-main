import 'package:flutter/material.dart';

import '../../services/content_service.dart';
import '../../services/external_link_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/constants.dart';

/// Weekly Premium paywall ($6.99/week, product `premium_pro_weekly`).
///
/// Our own paywall UI; billing runs through Superwall (see
/// [SubscriptionService]). Unlocks honest local benefits only: the full
/// round Reveal, double stars and a profile badge. Waiting periods apply to all players.
/// Title, subtitle, product card and CTA come from [ContentService]; the legal
/// block stays in code so review-required wording cannot drift.
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

  final SubscriptionService _subs = SubscriptionService.instance;

  bool _loading = true;
  String _priceLabel = fallbackPrice;

  @override
  void initState() {
    super.initState();
    _subs.notice.addListener(_showNotice);
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final label = await _subs.priceLabel(AppConstants.premiumProProductId);
    if (!mounted) return;
    setState(() {
      _priceLabel = label;
      _loading = false;
    });
  }

  void _showNotice() {
    final msg = _subs.notice.value;
    if (msg == null) return;
    _subs.notice.value = null;
    _showMessage(msg);
  }

  Future<void> _buy() => _subs.buyPro(AppConstants.premiumProProductId);

  Future<void> _restorePurchases() => _subs.restore();

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _subs.notice.removeListener(_showNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = _priceLabel;
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
              ValueListenableBuilder<bool>(
                valueListenable: _subs.purchasePending,
                builder: (context, pending, _) => pending
                    ? const LinearProgressIndicator(color: primaryBlue)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            const Text('👑', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            Text(
                              ContentService.instance.text('paywall_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ContentService.instance.text('paywall_subtitle'),
                              style: const TextStyle(
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
    final features = ContentService.instance.stringList('paywall_features_v2');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ContentService.instance.text('paywall_product_name'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text('💙', style: TextStyle(fontSize: 20)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
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
            ContentService.instance.template('paywall_term', {
              'price': priceLabel,
            }),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final (index, feature) in features.indexed)
            _buildFeature(
              icon: switch (index) {
                0 => Icons.visibility_outlined,
                1 => Icons.star_outline,
                _ => Icons.verified_outlined,
              },
              text: feature,
            ),
          const Text(
            'The 60-minute wait also applies to Premium. Earn wait passes by inviting new friends.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder<bool>(
              valueListenable: _subs.purchasePending,
              builder: (context, pending, _) => ElevatedButton(
                onPressed: pending ? null : _buy,
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
                  ContentService.instance.template('paywall_cta', {
                    'price': priceLabel,
                  }),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
      ),
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
              onPressed: () => openExternalLink(
                context,
                ContentService.instance.text('url_terms'),
              ),
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
              onPressed: () => openExternalLink(
                context,
                ContentService.instance.text('url_privacy'),
              ),
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
