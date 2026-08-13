import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Instagram-style tab bar. Always at the bottom of the logged-in app.
/// 0 Home · 1 Activity · 2 Vote · 3 Likes · 4 Profile
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _TabIcon(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabIcon(
                icon: Icons.public_outlined,
                activeIcon: Icons.public,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _VoteTab(
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _TabIcon(
                icon: Icons.favorite_border_rounded,
                activeIcon: Icons.favorite_rounded,
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _TabIcon(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Icon(
            selected ? activeIcon : icon,
            size: 28,
            color: selected ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _VoteTab extends StatelessWidget {
  const _VoteTab({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBlue : AppColors.textPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_vote_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
