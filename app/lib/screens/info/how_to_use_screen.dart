import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HowToUseScreen extends ConsumerWidget {
  const HowToUseScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  static const _steps = [
    (Icons.person_add_rounded, 'Регистрация', 'Введите номер телефона и получите код подтверждения. Заполните профиль: имя, возраст, школу и класс.'),
    (Icons.contacts_rounded, 'Добавьте контакты', 'Разрешите доступ к контактам — это поможет найти одноклассников. Контакты хешируются и не загружаются на сервер.'),
    (Icons.how_to_vote_rounded, 'Участвуйте в голосованиях', 'Каждый день доступно до 50 опросов по 12 вопросов. Голосуйте за одноклассников анонимно!'),
    (Icons.favorite_rounded, 'Получайте лайки', 'Когда кто-то выбирает вас в голосовании — вы получаете лайк. Вкладка "Лайки" показывает кто голосовал за вас.'),
    (Icons.star_rounded, 'Зарабатывайте звёзды', 'За каждый голос в вашу пользу вы получаете звёзды. Они отображаются в вашем профиле.'),
    (Icons.group_add_rounded, 'Приглашайте друзей', 'Чем больше одноклассников в приложении — тем интереснее голосования! Пригласите друзей по реферальной ссылке.'),
    (Icons.workspace_premium_rounded, 'Premium подписка', 'Хотите узнать кто именно за вас проголосовал? Оформите Premium и раскрывайте имена голосовавших.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Как пользоваться'),
        backgroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final (icon, title, desc) = _steps[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _primaryBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(color: _primaryBlue, shape: BoxShape.circle),
                            child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 8),
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(desc, style: const TextStyle(color: Colors.black54, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
