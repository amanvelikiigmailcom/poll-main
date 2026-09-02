import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _background = Color(0xFFF8F8F8);

class _NotificationItem {
  final String title;
  final String subtitle;
  bool enabled;

  _NotificationItem({
    required this.title,
    required this.subtitle,
    required this.enabled,
  });
}

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  late List<_NotificationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      _NotificationItem(
        title: 'Новые лайки',
        subtitle: 'Получайте уведомления, когда кто-то ставит лайк вашему контенту',
        enabled: true,
      ),
      _NotificationItem(
        title: 'Запросы в друзья',
        subtitle: 'Уведомления о новых запросах на добавление в друзья',
        enabled: true,
      ),
      _NotificationItem(
        title: 'Результаты голосований',
        subtitle: 'Узнавайте итоги голосований, в которых вы участвовали',
        enabled: true,
      ),
      _NotificationItem(
        title: 'Новый опрос доступен',
        subtitle: 'Уведомления о появлении новых опросов для вас',
        enabled: false,
      ),
      _NotificationItem(
        title: 'Обновления приложения',
        subtitle: 'Информация о новых функциях и улучшениях приложения',
        enabled: false,
      ),
    ];
  }

  void _save() {
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Настройки уведомлений сохранены'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          'Настройки уведомлений',
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
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: item.enabled,
                        activeThumbColor: _primaryBlue,
                        onChanged: (value) {
                          setState(() {
                            _items[index].enabled = value;
                          });
                        },
                      ),
                    ],
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
