import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _background = Color(0xFFF8F8F8);

class _Language {
  final String flag;
  final String name;
  final String code;

  const _Language({required this.flag, required this.name, required this.code});
}

const _languages = [
  _Language(flag: '🇷🇺', name: 'Русский', code: 'ru'),
  _Language(flag: '🇬🇧', name: 'English', code: 'en'),
  _Language(flag: '🇯🇵', name: '日本語', code: 'ja'),
  _Language(flag: '🇰🇷', name: '한국어', code: 'ko'),
  _Language(flag: '🇪🇸', name: 'Español', code: 'es'),
  _Language(flag: '🇧🇷', name: 'Português', code: 'pt'),
  _Language(flag: '🇹🇭', name: 'ภาษาไทย', code: 'th'),
  _Language(flag: '🇮🇳', name: 'हिन्दी', code: 'hi'),
];

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  String _selectedCode = 'ru';

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');
    if (saved != null && mounted) {
      setState(() {
        _selectedCode = saved;
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _selectedCode);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Выбор языка',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _languages.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = lang.code == _selectedCode;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCode = lang.code;
                    });
                  },
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          lang.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            lang.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected ? _primaryBlue : Colors.black87,
                            ),
                          ),
                        ),
                        Radio<String>(
                          value: lang.code,
                          groupValue: _selectedCode,
                          activeColor: _primaryBlue,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCode = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
