import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/navigation_icons.dart';

/// Five equal tabs with matching Phosphor regular/fill icons.
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
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _TabIcon(
                label: 'Home',
                icon: NavigationIcons.home,
                activeIcon: NavigationIcons.homeFill,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabIcon(
                label: 'Search',
                icon: NavigationIcons.search,
                activeIcon: NavigationIcons.searchFill,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _TabIcon(
                label: 'Likes',
                icon: NavigationIcons.likes,
                activeIcon: NavigationIcons.likesFill,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _TabIcon(
                label: 'Profile',
                icon: NavigationIcons.profile,
                activeIcon: NavigationIcons.profileFill,
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _TabIcon(
                label: 'Settings',
                icon: NavigationIcons.settings,
                activeIcon: NavigationIcons.settingsFill,
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
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        child: SizedBox.expand(
          child: IconButton(
            tooltip: label,
            onPressed: onTap,
            iconSize: 28,
            color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
            icon: Icon(selected ? activeIcon : icon),
          ),
        ),
      ),
    );
  }
}
