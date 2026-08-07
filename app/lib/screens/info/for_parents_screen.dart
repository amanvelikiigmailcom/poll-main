import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ForParentsScreen extends ConsumerWidget {
  const ForParentsScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'parents@oister.app',
      query: 'subject=Вопрос от родителя&body=Здравствуйте,\n\nУ меня есть вопрос об использовании OISTER моим ребёнком:\n\n',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Для родителей'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              Icons.info_rounded,
              'Как работает приложение',
              'OISTER — это анонимное приложение для школьников, где ученики голосуют друг за друга в шуточных опросах. Голосование полностью анонимно — невозможно узнать кто за кого голосовал.',
            ),
            _section(
              Icons.lock_rounded,
              'Анонимность и безопасность',
              '• Нельзя голосовать за себя\n• Голосование только внутри своей школы\n• Контакты обрабатываются локально на устройстве\n• Мы не продаём данные третьим лицам\n• Все данные хранятся зашифрованно',
            ),
            _section(
              Icons.child_care_rounded,
              'Возрастные ограничения',
              'Приложение предназначено для школьников 14–19 лет. При регистрации пользователь указывает возраст. Контент проходит модерацию.',
            ),
            _section(
              Icons.privacy_tip_rounded,
              'Политика конфиденциальности',
              'Мы соблюдаем требования GDPR и законодательства о защите данных несовершеннолетних (COPPA). Полная политика доступна на сайте oister.app/privacy',
            ),
            _section(
              Icons.supervisor_account_rounded,
              'Как контролировать активность',
              '• Попросите ребёнка показать приложение\n• Обсудите правила безопасного общения онлайн\n• При необходимости можно удалить аккаунт через Настройки',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mail_rounded, color: _primaryBlue, size: 36),
                  const SizedBox(height: 12),
                  const Text('Поддержка для родителей', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  const Text('parents@oister.app', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('Написать нам'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: Colors.black87, height: 1.5)),
        ],
      ),
    );
  }
}
