import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  static const _primaryBlue = Color(0xFF4B6EF5);

  static const _faqs = [
    ('Как работает анонимность?', 'Система устроена так, что невозможно отследить, кто за кого голосовал. Голоса анонимны — даже администраторы не могут узнать, кто именно выбрал вас.'),
    ('Можно ли узнать кто за меня голосовал?', 'Бесплатно вы видите только класс и пол голосовавшего. Чтобы узнать имя — оформите подписку Premium. Это единственный способ раскрыть имя.'),
    ('Как добавить друзей?', 'Перейдите в раздел "Поиск" и найдите друга по имени или юзернейму. Нажмите "Добавить в друзья". Когда он примет запрос — вы станете друзьями.'),
    ('Как работает таймер?', 'После прохождения одного опроса (12 вопросов) запускается таймер на 40 минут. После его окончания вам станет доступен следующий опрос.'),
    ('Что такое звёзды?', 'Звёзды — внутренняя валюта приложения. Вы получаете их когда кто-то голосует за вас. Звёзды отображаются в вашем профиле.'),
    ('Почему я не вижу себя в опросах?', 'Это сделано специально — нельзя голосовать за себя. Вы никогда не появляетесь в опросах у себя самого.'),
    ('Как удалить аккаунт?', 'Перейдите в Настройки → прокрутите вниз → нажмите "Удалить аккаунт". Вам потребуется выбрать причину. Это действие необратимо.'),
    ('Как работают голосования в комнатах?', 'Комната — это группа пользователей, которые голосуют друг за друга. Можно присоединиться к публичной комнате или создать свою.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Частые вопросы'),
        backgroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final (question, answer) = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              iconColor: _primaryBlue,
              collapsedIconColor: Colors.grey,
              title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              children: [
                Text(answer, style: const TextStyle(color: Colors.black87, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
