import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Predefined size variants for [UserAvatar].
enum AvatarSize { xsmall, small, medium, large, xlarge }

/// Circular avatar widget using [CachedNetworkImage].
///
/// Falls back to a coloured circle with the user's initials when:
/// - [avatarUrl] is null or empty
/// - the image fails to load
///
/// Optionally shows a verified badge overlay at the bottom-right corner.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;

  /// Full name or display name — used to derive initials and avatar colour.
  final String? name;

  final AvatarSize size;

  /// When true, a blue check-mark badge is shown at the bottom-right.
  final bool showVerifiedBadge;

  /// Optional explicit diameter in pixels — overrides [size].
  final double? customDiameter;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.size = AvatarSize.medium,
    this.showVerifiedBadge = false,
    this.customDiameter,
  });

  // ── Sizing ──────────────────────────────────────────────────────────────────

  double get _diameter {
    if (customDiameter != null) return customDiameter!;
    switch (size) {
      case AvatarSize.xsmall:
        return 24;
      case AvatarSize.small:
        return 36;
      case AvatarSize.medium:
        return 48;
      case AvatarSize.large:
        return 72;
      case AvatarSize.xlarge:
        return 96;
    }
  }

  double get _badgeDiameter => _diameter * 0.30;

  double get _fontSize {
    final d = _diameter;
    if (d <= 24) return 9;
    if (d <= 36) return 13;
    if (d <= 48) return 17;
    if (d <= 72) return 24;
    return 32;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _initials() {
    final raw = name?.trim() ?? '';
    if (raw.isEmpty) return '?';
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return raw[0].toUpperCase();
  }

  Color _colorFromName() {
    const palette = [
      Color(0xFF4B6EF5), // primary blue
      Color(0xFF8B5CF6), // violet
      Color(0xFFEC4899), // pink
      Color(0xFFEF4444), // red
      Color(0xFFF97316), // orange
      Color(0xFF10B981), // emerald
      Color(0xFF06B6D4), // cyan
      Color(0xFFF59E0B), // amber
      Color(0xFF3B82F6), // blue 500
      Color(0xFF14B8A6), // teal
    ];
    final raw = name?.trim() ?? '';
    if (raw.isEmpty) return AppColors.textSecondary;
    int hash = 0;
    for (final code in raw.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final diameter = _diameter;
    final avatar = _buildAvatar(diameter);

    if (showVerifiedBadge) {
      return _withVerifiedBadge(avatar, diameter);
    }
    return avatar;
  }

  Widget _buildAvatar(double diameter) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        imageBuilder: (_, imageProvider) => _circle(
          diameter: diameter,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        placeholder: (_, __) => _initialsCircle(diameter),
        errorWidget: (_, __, ___) => _initialsCircle(diameter),
      );
    }
    return _initialsCircle(diameter);
  }

  Widget _initialsCircle(double diameter) {
    return _circle(
      diameter: diameter,
      color: _colorFromName(),
      child: Center(
        child: Text(
          _initials(),
          style: TextStyle(
            color: Colors.white,
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _circle({
    required double diameter,
    Color? color,
    required Widget child,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      clipBehavior: color == null ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }

  Widget _withVerifiedBadge(Widget avatar, double diameter) {
    final badgeDiameter = _badgeDiameter;
    final iconSize = badgeDiameter * 0.65;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: badgeDiameter,
            height: badgeDiameter,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              Icons.check,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ],
    );
  }
}
