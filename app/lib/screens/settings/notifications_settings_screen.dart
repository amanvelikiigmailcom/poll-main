import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/notification_preferences_service.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});
  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  Map<String, bool>? values;
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final result = await ref.read(notificationPreferencesProvider).load();
      if (mounted) setState(() => values = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t load notification settings. Sign in or try again.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (saving || values == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(notificationPreferencesProvider).save(values!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved')),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t save. Your changes are still here. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationPreferencesProvider, (_, service) {
      if (service.preferences == null && values != null) {
        setState(() {
          values = null;
          error = 'Your account changed. Reload settings.';
        });
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose which notifications Flyprox sends. iPhone notification permission is managed in system Settings. Next-round and sign-in notices stay enabled in Flyprox. All notifications require iOS permission.',
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(error!),
            TextButton(
              onPressed: saving ? null : _load,
              child: const Text('Retry'),
            ),
          ],
          if (values == null && error == null)
            const Center(child: CircularProgressIndicator()),
          if (values != null) ...[
            for (final entry in notificationCategories.entries)
              SwitchListTile(
                key: Key('notification-${entry.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: values![entry.key]!,
                onChanged: saving
                    ? null
                    : (v) => setState(() => values![entry.key] = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ],
      ),
    );
  }
}
