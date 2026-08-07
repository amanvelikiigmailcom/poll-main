import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

String formatTimer(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  if (diff.inDays < 7) return '${diff.inDays} дн назад';
  return '${dateTime.day}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
}

String hashPhone(String phone) {
  final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final bytes = utf8.encode(normalized);
  return sha256.convert(bytes).toString();
}

Color generateAvatarColor(String name) {
  const colors = [
    Color(0xFF4B6EF5),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFF96CEB4),
    Color(0xFFDDA0DD),
    Color(0xFFFFB347),
    Color(0xFF98D8C8),
    Color(0xFFF7DC6F),
    Color(0xFFAED6F1),
  ];
  int hash = 0;
  for (final c in name.codeUnits) {
    hash = (hash * 31 + c) & 0xFFFFFFFF;
  }
  return colors[hash % colors.length];
}

String getInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Color getCategoryColor(String category) {
  switch (category) {
    case 'humor':
      return AppColors.humorCategory;
    case 'sympathy':
      return AppColors.sympathyCategory;
    default:
      return AppColors.normalCategory;
  }
}

Color getCategoryTextColor(String category) {
  switch (category) {
    case 'humor':
      return AppColors.humorCategoryText;
    case 'sympathy':
      return AppColors.sympathyCategoryText;
    default:
      return AppColors.normalCategoryText;
  }
}

String getCategoryLabel(String category) {
  switch (category) {
    case 'humor':
      return 'Юмор';
    case 'sympathy':
      return 'Симпатия';
    default:
      return 'Обычное';
  }
}
