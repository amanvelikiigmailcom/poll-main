import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPollScreen extends ConsumerStatefulWidget {
  const SettingsPollScreen({super.key});

  @override
  ConsumerState<SettingsPollScreen> createState() => _SettingsPollScreenState();
}

class _SettingsPollScreenState extends ConsumerState<SettingsPollScreen> {
  static const _primaryBlue = Color(0xFF4B6EF5);

  String _selected = 'Все';
  final List<String> _options = ['Все', 'Девочки', 'Мальчики', 'Небинарный'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Настройки опроса'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Кого показывать в голосованиях?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Выберите, участников какого пола вы хотите видеть в опросах.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ...(_options.map((option) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selected == option ? _primaryBlue : Colors.grey.shade200,
                      width: _selected == option ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: option,
                    groupValue: _selected,
                    activeColor: _primaryBlue,
                    title: Text(option, style: const TextStyle(fontWeight: FontWeight.w500)),
                    onChanged: (v) => setState(() => _selected = v!),
                  ),
                ))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(_selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Выбрать', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
