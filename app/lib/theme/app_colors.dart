import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF4B6EF5);
  static const Color primaryBlueDark = Color(0xFF3A5AE0);
  static const Color accentRed = Color(0xFFFF3B5C);
  static const Color accentRedDark = Color(0xFFE0203F);

  static const Color white = Colors.white;
  static const Color black = Color(0xFF1A1A1A);
  static const Color background = Color(0xFFF8F8F8);
  static const Color cardBg = Colors.white;
  static const Color surface = Color(0xFFF5F5F5);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = Color(0xFF4B6EF5);
  static const Color divider = Color(0xFFF3F4F6);

  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  static const Color premiumGold = Color(0xFFFFD700);
  static const Color premiumPurple = Color(0xFF9B59B6);

  // Gradient for premium dark screens
  static const Color gradientStart = Color(0xFF1A1A2E);
  static const Color gradientMid = Color(0xFF16213E);
  static const Color gradientEnd = Color(0xFF0F3460);

  // Category colors
  static const Color humorCategory = Color(0xFFFFF3CD);
  static const Color humorCategoryText = Color(0xFF856404);
  static const Color normalCategory = Color(0xFFD1ECF1);
  static const Color normalCategoryText = Color(0xFF0C5460);
  static const Color sympathyCategory = Color(0xFFFFD6E7);
  static const Color sympathyCategoryText = Color(0xFF6D2B4B);

  // Shimmer
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMid, gradientEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, Color(0xFF7B9BFF)],
  );
}
