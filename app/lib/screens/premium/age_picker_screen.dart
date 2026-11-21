import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/age_gate_service.dart';

/// Neutral age wheel in front of the paywall.
///
/// No hints about which ages pass; the wheel starts at the youngest value so
/// the default never preselects a pass. After the choice is saved, the
/// `/premium` gate swaps screens on its own — there is intentionally no
/// navigation back to this wheel from the blocked screen.
class AgePickerScreen extends StatefulWidget {
  const AgePickerScreen({super.key});

  @override
  State<AgePickerScreen> createState() => _AgePickerScreenState();
}

class _AgePickerScreenState extends State<AgePickerScreen> {
  static const Color accentRed = Color(0xFFFF3B5C);
  static const List<String> _ages = [
    '10',
    '11',
    '12',
    '13',
    '14',
    '15',
    '16',
    '17',
    '18+',
  ];

  int _index = 0;
  bool _saving = false;

  int get _selectedAge => _index >= _ages.length - 1 ? 18 : 10 + _index;

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    final svc = AgeGateService.instance;
    if (AgeGateService.passes(_selectedAge)) {
      await svc.verifyAdult();
    } else {
      await svc.blockMinor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A1A4E), Color(0xFF0F3460)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How old are you?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scroll to your age.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: CupertinoPicker(
                  itemExtent: 44,
                  onSelectedItemChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final age in _ages)
                      Center(
                        child: Text(
                          age,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected age: ${_ages[_index]}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
