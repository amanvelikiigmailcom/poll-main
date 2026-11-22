import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/age_gate_service.dart';

/// Final introductory step. No accepted answer or passing age is preselected.
class AgePickerScreen extends StatefulWidget {
  const AgePickerScreen({super.key});
  @override
  State<AgePickerScreen> createState() => _AgePickerScreenState();
}

class _AgePickerScreenState extends State<AgePickerScreen> {
  static const ages = ['12 or younger', '13', '14', '15', '16', '17', '18+'];
  int? selected;
  bool saving = false;

  Future<void> _continue() async {
    if (selected == null || saving) return;
    setState(() => saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    if (selected == 0) {
      await AgeGateService.instance.blockMinor();
    } else {
      await AgeGateService.instance.verifyAdult();
    }
    // The router observes the saved result; there is no path around this gate.
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFF4B6EF5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'How old are you?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your age to continue.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    for (var i = 0; i < ages.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => setState(() => selected = i),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selected == i
                                ? const Color(0xFF4B6EF5)
                                : Colors.white,
                            backgroundColor: selected == i
                                ? Colors.white
                                : Colors.transparent,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ages[i],
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ),
                              Icon(
                                selected == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: selected == null || saving ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4B6EF5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(saving ? 'Please wait…' : 'Continue'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.privacy),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
