import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The visual style variant of [AppButton].
enum AppButtonVariant {
  /// Filled blue — primary actions.
  primary,

  /// Outline blue — secondary / alternative actions.
  secondary,

  /// Filled red — destructive actions.
  danger,

  /// Transparent text-only — low-emphasis actions.
  text,
}

/// Reusable button widget with loading state, disabled state, and icon support.
///
/// Usage:
/// ```dart
/// AppButton(
///   label: 'Продолжить',
///   onPressed: _submit,
///   isLoading: state.isLoading,
/// )
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;
  final double fontSize;
  final EdgeInsets? padding;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.height,
    this.fontSize = 16,
    this.padding,
  });

  bool get _disabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final buttonChild = _buildChild();

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = _PrimaryButton(
          onPressed: _disabled ? null : onPressed,
          padding: padding,
          height: height,
          fontSize: fontSize,
          isLoading: isLoading,
          child: buttonChild,
        );
      case AppButtonVariant.secondary:
        button = _SecondaryButton(
          onPressed: _disabled ? null : onPressed,
          disabled: _disabled,
          padding: padding,
          height: height,
          fontSize: fontSize,
          isLoading: isLoading,
          child: buttonChild,
        );
      case AppButtonVariant.danger:
        button = _DangerButton(
          onPressed: _disabled ? null : onPressed,
          padding: padding,
          height: height,
          fontSize: fontSize,
          isLoading: isLoading,
          child: buttonChild,
        );
      case AppButtonVariant.text:
        button = _TextButtonWidget(
          onPressed: _disabled ? null : onPressed,
          padding: padding,
          height: height,
          fontSize: fontSize,
          child: buttonChild,
        );
    }

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildChild() {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary ||
                    variant == AppButtonVariant.danger
                ? Colors.white
                : AppColors.primaryBlue,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}

// ── Style variants ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final double? height;
  final double fontSize;
  final bool isLoading;

  const _PrimaryButton({
    required this.child,
    required this.onPressed,
    this.padding,
    this.height,
    required this.fontSize,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryBlue.withOpacity(0.45),
          disabledForegroundColor: Colors.white70,
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  final EdgeInsets? padding;
  final double? height;
  final double fontSize;
  final bool isLoading;

  const _SecondaryButton({
    required this.child,
    required this.onPressed,
    required this.disabled,
    this.padding,
    this.height,
    required this.fontSize,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: disabled
              ? AppColors.primaryBlue.withOpacity(0.45)
              : AppColors.primaryBlue,
          side: BorderSide(
            color: disabled
                ? AppColors.primaryBlue.withOpacity(0.35)
                : AppColors.primaryBlue,
            width: 1.5,
          ),
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final double? height;
  final double fontSize;
  final bool isLoading;

  const _DangerButton({
    required this.child,
    required this.onPressed,
    this.padding,
    this.height,
    required this.fontSize,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accentRed.withOpacity(0.45),
          disabledForegroundColor: Colors.white70,
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}

class _TextButtonWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final double? height;
  final double fontSize;

  const _TextButtonWidget({
    required this.child,
    required this.onPressed,
    this.padding,
    this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: onPressed == null
              ? AppColors.primaryBlue.withOpacity(0.45)
              : AppColors.primaryBlue,
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          textStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: child,
      ),
    );
  }
}
