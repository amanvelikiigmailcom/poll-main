import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Server-issued presentation only. Expiry removes a badge even on an open page.
class PremiumBadge extends StatefulWidget {
  const PremiumBadge({super.key, required this.active, this.until});
  final bool active;
  final String? until;
  @override
  State<PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<PremiumBadge> {
  Timer? _expiry;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PremiumBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _expiry?.cancel();
    final end = DateTime.tryParse(widget.until ?? '');
    _expired = end == null || !end.isAfter(DateTime.now());
    if (end != null && end.isAfter(DateTime.now())) {
      _expiry = Timer(end.difference(DateTime.now()), () {
        if (mounted) setState(() => _expired = true);
      });
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(widget.until ?? '');
    if (!widget.active ||
        _expired ||
        end == null ||
        !end.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Tooltip(
        message: 'Premium member',
        child: Icon(Icons.verified, color: AppColors.primaryBlue, size: 18),
      ),
    );
  }
}
