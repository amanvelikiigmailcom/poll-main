import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Центр безопасности'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: _primaryBlue, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'OISTER заботится о безопасности каждого пользователя',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _primaryBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSection('Документы', [
            _DocItem(Icons.privacy_tip_rounded, 'Политика конфиденциальности', () => _openUrl('https://oister.app/privacy')),
            _DocItem(Icons.gavel_rounded, 'Условия использования', () => _openUrl('https://oister.app/terms')),
            _DocItem(Icons.people_rounded, 'Правила сообщества', () => _openUrl('https://oister.app/rules')),
          ]),
          const SizedBox(height: 16),
          _buildSection('Безопасность', [
            _DocItem(Icons.security_rounded, 'Рекомендации по безопасности', () => _showInfo(context, 'Рекомендации', '• Не делитесь личными данными\n• Не встречайтесь с незнакомцами\n• Сообщайте о подозрительных пользователях')),
            _DocItem(Icons.report_rounded, 'Как пожаловаться на пользователя', () => _showInfo(context, 'Жалоба', 'Откройте профиль пользователя → нажмите "..." → выберите "Пожаловаться" → укажите причину. Мы рассмотрим жалобу в течение 24 часов.')),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_DocItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: items.map((item) => ListTile(
              leading: Icon(item.icon, color: _primaryBlue),
              title: Text(item.title),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: item.onTap,
            )).toList(),
          ),
        ),
      ],
    );
  }

  void _showInfo(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
      ),
    );
  }
}

class _DocItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _DocItem(this.icon, this.title, this.onTap);
}
