import 'package:flutter/material.dart';
import '../../services/age_gate_service.dart';

/// Billing/analytics wait for an eligible answer. Phone auth is initialized
/// separately because verification precedes the declared-age step.
class AgeGatedStartup extends StatefulWidget {
  const AgeGatedStartup({
    super.key,
    required this.initialize,
    required this.child,
  });
  final Future<void> Function() initialize;
  final Widget child;
  @override
  State<AgeGatedStartup> createState() => _AgeGatedStartupState();
}

class _AgeGatedStartupState extends State<AgeGatedStartup> {
  bool _started = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    AgeGateService.instance.statusListenable.addListener(_ageChanged);
    _startIfEligible();
  }

  void _ageChanged() {
    _startIfEligible();
    if (mounted) setState(() {});
  }

  void _startIfEligible() {
    if (_started || AgeGateService.instance.status != AgeGateStatus.verified) {
      return;
    }
    _started = true;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize().timeout(const Duration(seconds: 12));
    } catch (_) {
      /* Optional online services must not prevent local play. */
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    AgeGateService.instance.statusListenable.removeListener(_ageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AgeGateService.instance.status == AgeGateStatus.verified && !_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return widget.child;
  }
}
