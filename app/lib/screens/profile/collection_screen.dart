import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Collection item model
// ---------------------------------------------------------------------------

enum _CollectionCategory { frames, badges, effects, titles }

class _CollectionItem {
  const _CollectionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
    this.isUnlocked = false,
    this.cost = 0,
    this.isEquipped = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final _CollectionCategory category;
  final bool isUnlocked;
  final int cost;
  final bool isEquipped;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

class _CollectionState {
  const _CollectionState({
    required this.items,
    this.selectedCategory,
  });

  final List<_CollectionItem> items;
  final _CollectionCategory? selectedCategory;

  List<_CollectionItem> get filtered {
    if (selectedCategory == null) return items;
    return items.where((i) => i.category == selectedCategory).toList();
  }

  _CollectionState copyWith({
    List<_CollectionItem>? items,
    _CollectionCategory? selectedCategory,
    bool clearCategory = false,
  }) {
    return _CollectionState(
      items: items ?? this.items,
      selectedCategory:
          clearCategory ? null : selectedCategory ?? this.selectedCategory,
    );
  }
}

class _CollectionNotifier extends StateNotifier<_CollectionState> {
  _CollectionNotifier()
      : super(_CollectionState(items: _kAllItems));

  void selectCategory(_CollectionCategory? cat) {
    if (state.selectedCategory == cat) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: cat);
    }
  }

  void equip(String id) {
    final updated = state.items.map((item) {
      if (item.category !=
          state.items.firstWhere((i) => i.id == id).category) {
        return item;
      }
      return _CollectionItem(
        id: item.id,
        label: item.label,
        icon: item.icon,
        category: item.category,
        isUnlocked: item.isUnlocked,
        cost: item.cost,
        isEquipped: item.id == id && item.isUnlocked,
      );
    }).toList();
    state = state.copyWith(items: updated);
  }

  static const _kAllItems = [
    // Frames
    _CollectionItem(
      id: 'frame_gold',
      label: 'Gold frame',
      icon: Icons.circle_outlined,
      category: _CollectionCategory.frames,
      isUnlocked: true,
      cost: 0,
    ),
    _CollectionItem(
      id: 'frame_blue',
      label: 'Blue frame',
      icon: Icons.radio_button_unchecked,
      category: _CollectionCategory.frames,
      isUnlocked: true,
      cost: 500,
    ),
    _CollectionItem(
      id: 'frame_rainbow',
      label: 'Rainbow frame',
      icon: Icons.panorama_fish_eye,
      category: _CollectionCategory.frames,
      isUnlocked: false,
      cost: 2000,
    ),
    _CollectionItem(
      id: 'frame_flame',
      label: 'Fire frame',
      icon: Icons.local_fire_department_outlined,
      category: _CollectionCategory.frames,
      isUnlocked: false,
      cost: 5000,
    ),
    // Badges
    _CollectionItem(
      id: 'badge_vote',
      label: 'First vote',
      icon: Icons.how_to_vote_outlined,
      category: _CollectionCategory.badges,
      isUnlocked: true,
      cost: 0,
    ),
    _CollectionItem(
      id: 'badge_popular',
      label: 'Popular',
      icon: Icons.local_fire_department_outlined,
      category: _CollectionCategory.badges,
      isUnlocked: true,
      cost: 0,
    ),
    _CollectionItem(
      id: 'badge_school',
      label: 'School friend',
      icon: Icons.school_outlined,
      category: _CollectionCategory.badges,
      isUnlocked: false,
      cost: 3000,
    ),
    _CollectionItem(
      id: 'badge_star',
      label: 'Star',
      icon: Icons.star_outline,
      category: _CollectionCategory.badges,
      isUnlocked: false,
      cost: 10000,
    ),
    _CollectionItem(
      id: 'badge_mystery',
      label: 'Mysterious',
      icon: Icons.person_outline,
      category: _CollectionCategory.badges,
      isUnlocked: false,
      cost: 7500,
    ),
    _CollectionItem(
      id: 'badge_activist',
      label: 'Activist',
      icon: Icons.campaign_outlined,
      category: _CollectionCategory.badges,
      isUnlocked: false,
      cost: 4000,
    ),
    // Effects
    _CollectionItem(
      id: 'effect_sparkle',
      label: 'Glitter',
      icon: Icons.auto_awesome,
      category: _CollectionCategory.effects,
      isUnlocked: false,
      cost: 8000,
    ),
    _CollectionItem(
      id: 'effect_glow',
      label: 'Glow',
      icon: Icons.light_mode_outlined,
      category: _CollectionCategory.effects,
      isUnlocked: false,
      cost: 6000,
    ),
    // Titles
    _CollectionItem(
      id: 'title_king',
      label: 'Class king',
      icon: Icons.emoji_events_outlined,
      category: _CollectionCategory.titles,
      isUnlocked: false,
      cost: 15000,
    ),
    _CollectionItem(
      id: 'title_genius',
      label: 'Genius',
      icon: Icons.lightbulb_outline,
      category: _CollectionCategory.titles,
      isUnlocked: false,
      cost: 12000,
    ),
  ];
}

final _collectionProvider =
    StateNotifierProvider<_CollectionNotifier, _CollectionState>(
  (_) => _CollectionNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colState = ref.watch(_collectionProvider);
    final stars = user?.starsCount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Collection',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _BalanceCard(stars: stars),
          _CategoryChips(
            selected: colState.selectedCategory,
            onSelect: (cat) =>
                ref.read(_collectionProvider.notifier).selectCategory(cat),
          ),
          Expanded(
            child: _ItemsGrid(
              items: colState.filtered,
              onEquip: (id) =>
                  ref.read(_collectionProvider.notifier).equip(id),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.stars});

  final int stars;

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR BALANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _fmt(stars),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('⭐', style: TextStyle(fontSize: 28)),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Use stars to unlock items',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chips
// ---------------------------------------------------------------------------

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.onSelect,
  });

  final _CollectionCategory? selected;
  final ValueChanged<_CollectionCategory?> onSelect;

  static const _labels = {
    _CollectionCategory.frames: 'Frames',
    _CollectionCategory.badges: 'Badges',
    _CollectionCategory.effects: 'Эффекты',
    _CollectionCategory.titles: 'Титулы',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip(
            label: 'Все',
            isSelected: selected == null,
            onTap: () => onSelect(null),
          ),
          ..._CollectionCategory.values.map(
            (cat) => _Chip(
              label: _labels[cat]!,
              isSelected: selected == cat,
              onTap: () => onSelect(cat),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.white
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items grid
// ---------------------------------------------------------------------------

class _ItemsGrid extends StatelessWidget {
  const _ItemsGrid({required this.items, required this.onEquip});

  final List<_CollectionItem> items;
  final ValueChanged<String> onEquip;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Нет предметов',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _CollectionCard(item: items[index], onEquip: onEquip),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.item, required this.onEquip});

  final _CollectionItem item;
  final ValueChanged<String> onEquip;

  String _fmtCost(int cost) {
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(0)}K ⭐';
    return '$cost ⭐';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isEquipped
              ? AppColors.primaryBlue
              : item.isUnlocked
                  ? AppColors.border
                  : AppColors.divider,
          width: item.isEquipped ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / lock
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isUnlocked
                      ? AppColors.primaryBlue.withValues(alpha: 0.12)
                      : AppColors.surface,
                ),
                child: Icon(
                  item.icon,
                  size: 26,
                  color: item.isUnlocked
                      ? AppColors.primaryBlue
                      : AppColors.textHint,
                ),
              ),
              if (!item.isUnlocked)
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: item.isUnlocked
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Action button or equipped badge
          if (item.isEquipped)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Надет',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (item.isUnlocked)
            GestureDetector(
              onTap: () => onEquip(item.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryBlue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Открыть',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Text(
              _fmtCost(item.cost),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
