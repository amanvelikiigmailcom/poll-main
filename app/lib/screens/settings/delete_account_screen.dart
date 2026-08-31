import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _primaryBlue = Color(0xFF4B6EF5);
  static const _accentRed = Color(0xFFFF3B5C);

  int? _selectedReason;
  final _otherController = TextEditingController();

  final List<String> _reasons = [
    'I created a duplicate account',
    'Security concerns',
    'Too many notifications',
    'I do not find the app useful',
    'Other reason',
  ];

  bool get _canDelete {
    if (_selectedReason == null) return false;
    if (_selectedReason == 4 && _otherController.text.trim().length < 10) return false;
    return true;
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('All your data will be deleted permanently. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await LocalGameService.instance.clearAll();
              if (!mounted) return;
              context.go(AppRoutes.namesEntry);
            },
            style: TextButton.styleFrom(foregroundColor: _accentRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Delete account'),
        foregroundColor: _accentRed,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentRed.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Color(0xFFFF3B5C)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ This action is irreversible. All your data will be deleted.',
                      style: TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Why do you want to delete your account?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(_reasons.length, (i) => Column(
              children: [
                RadioListTile<int>(
                  value: i,
                  groupValue: _selectedReason,
                  activeColor: _primaryBlue,
                  title: Text(_reasons[i]),
                  onChanged: (v) => setState(() => _selectedReason = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (i == 4 && _selectedReason == 4)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: TextField(
                      controller: _otherController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Describe reason (min. 10 chars)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _primaryBlue),
                        ),
                      ),
                    ),
                  ),
              ],
            )),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canDelete ? _confirmDelete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentRed,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Delete permanently',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
