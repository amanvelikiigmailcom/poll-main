import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

// ── Toast type ────────────────────────────────────────────────────────────────

enum ToastType { success, error, info }

// ── Entry point ───────────────────────────────────────────────────────────────

/// Show a toast notification over the current screen.
///
/// ```dart
/// AppToast.show(context, message: 'Сохранено!', type: ToastType.success);
/// ```
class AppToast {
  AppToast._();

  /// Duration before the toast auto-dismisses.
  static const Duration _defaultDuration = Duration(seconds: 3);

  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = _defaultDuration,
    IconData? customIcon,
  }) {
    // Dismiss any currently visible toast first
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        customIcon: customIcon,
        onDismiss: () {
          if (_current == entry) {
            dismiss();
          }
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);

    // Auto-dismiss after [duration]
    Timer(duration, () {
      if (_current == entry) dismiss();
    });
  }

  /// Immediately dismiss the currently visible toast (if any).
  static void dismiss() {
    _current?.remove();
    _current = null;
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.error);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.info);
}

// ── Internal widget ───────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? customIcon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.customIcon,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  // ── Styling per type ─────────────────────────────────────────────────────

  Color get _backgroundColor {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.accentRed;
      case ToastType.info:
        return AppColors.primaryBlue;
    }
  }

  IconData get _icon {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_outline_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Positioned(
      left: 16,
      right: 16,
      bottom: safeBottom,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              onHorizontalDragEnd: (_) => _dismiss(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _backgroundColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
