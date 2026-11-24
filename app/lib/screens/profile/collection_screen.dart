import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/collection_service.dart';
import '../../theme/app_colors.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});
  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  bool _purchaseFlow = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(collectionServiceProvider).load();
    });
  }

  Future<void> _buy(CollectionService shop, StarBoost boost) async {
    if (_purchaseFlow || shop.buying) return;
    _purchaseFlow = true;
    try {
      await _confirmAndBuy(shop, boost);
    } finally {
      _purchaseFlow = false;
    }
  }

  Future<void> _confirmAndBuy(CollectionService shop, StarBoost boost) async {
    final owner = shop.accountId;
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getToken();
    if (!mounted || owner == null || token == null || owner != shop.accountId) {
      return;
    }
    if (shop.pendingBoostId == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Buy boost?'),
          content: Text(
            'Buy “${boost.title}” for ${_format(boost.price)} stars?\n\n'
            '${boost.id == 'four_questions' ? 'Your name will appear in 4 random questions in one other player’s round, with at most 1 crush question.' : 'Your name will appear in 1 crush question in another player’s round.'}\n\n'
            'Active immediately for future eligible campus rounds. Votes are not guaranteed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Buy'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (token != await storage.getToken() ||
        owner != shop.accountId ||
        !mounted) {
      return;
    }
    final success = await shop.purchase(boost);
    if (!mounted) return;
    if (success) {
      ref.invalidate(starBalanceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boost activated for future eligible rounds.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(collectionServiceProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF101A42),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D3072), Color(0xFF0B122C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.profile),
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                    const Expanded(
                      child: Text(
                        'IN-GAME POINTS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: shop.buying ? () async {} : shop.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'YOUR BALANCE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (shop.loading) ...[
                        const _ShopSkeleton(height: 60),
                        const SizedBox(height: 28),
                        const _ShopSkeleton(height: 120),
                        const SizedBox(height: 12),
                        const _ShopSkeleton(height: 120),
                      ] else if (shop.guest) ...[
                        const _ShopHeading('Sign in to use your stars'),
                        const SizedBox(height: 12),
                        const Text(
                          'Guest stars stay on this device and cannot buy server boosts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.phone),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ] else if (shop.error != null) ...[
                        Text(
                          shop.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: shop.load,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '⭐ ${shop.balance == null ? '—' : _format(shop.balance!)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _ShopHeading('Promote yourself'),
                        const SizedBox(height: 8),
                        const Text(
                          'Use stars to put your name in more polls.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        if (!shop.eligible)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Choose your campus before buying a boost.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        for (final boost in shop.catalog)
                          _BoostCard(
                            boost: boost,
                            shop: shop,
                            onBuy: () => _buy(shop, boost),
                          ),
                        if (shop.purchaseError != null) ...[
                          Text(
                            shop.purchaseError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFFD1CA)),
                          ),
                          if (shop.balance == null)
                            TextButton(
                              onPressed: shop.buying ? null : shop.load,
                              child: const Text('Refresh balance'),
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (shop.activeBoosts.isNotEmpty) ...[
                          const _ShopHeading('Active boosts'),
                          const SizedBox(height: 12),
                          for (final active in shop.activeBoosts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${active['boostId'] == 'sympathy' ? 'Crush question' : '4-question boost'} · '
                                '${active['remaining']} placements · '
                                '${active['status'] == 'waiting_for_campus' ? 'Waiting for original campus' : 'Queued'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                        const _ShopHeading('How do I earn stars?'),
                        const SizedBox(height: 10),
                        const Text(
                          'Earn 1,000 stars for each completed 12-question round.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Boosts join the queue immediately. They apply to future eligible campus rounds, not rounds already issued. A placement is not a guaranteed vote.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
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
}

String _format(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class _ShopHeading extends StatelessWidget {
  const _ShopHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _BoostCard extends StatelessWidget {
  const _BoostCard({
    required this.boost,
    required this.shop,
    required this.onBuy,
  });
  final StarBoost boost;
  final CollectionService shop;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final pending = shop.pendingBoostId == boost.id;
    final enough = shop.balance != null && shop.balance! >= boost.price;
    final enabled =
        !shop.buying &&
        (pending || shop.pendingBoostId == null && shop.eligible && enough);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF263047),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('⭐', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  boost.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: enabled ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF444C60),
                disabledForegroundColor: Colors.white60,
              ),
              child: shop.buying && pending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      pending ? 'Check purchase' : '⭐ ${_format(boost.price)}',
                    ),
            ),
          ),
          if (!enough && !pending)
            const Text(
              'Not enough stars',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _ShopSkeleton extends StatelessWidget {
  const _ShopSkeleton({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading collection',
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
