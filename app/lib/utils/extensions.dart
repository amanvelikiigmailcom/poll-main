import 'package:flutter/material.dart';

extension ContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get padding => MediaQuery.of(this).padding;
  bool get isSmallScreen => MediaQuery.of(this).size.height < 700;
  void pop([Object? result]) => Navigator.of(this).pop(result);
}

extension StringExt on String {
  bool get isValidPhone {
    final digits = replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10;
  }

  bool get isValidUsername =>
      length >= 3 && length <= 20 && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(this);

  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String get capitalizeWords =>
      split(' ').map((w) => w.capitalize).join(' ');
}

extension DateTimeExt on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '$day.${month.toString().padLeft(2, '0')}.$year';
  }
}

extension ColorExt on Color {
  Color get withOpacity10 => withValues(alpha: 0.1);
  Color get withOpacity20 => withValues(alpha: 0.2);
}
