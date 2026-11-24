import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

/// Received votes only; the API never includes the voter's identity.
class ReceivedLikesScreen extends ConsumerStatefulWidget {
  const ReceivedLikesScreen({super.key});
  @override
  ConsumerState<ReceivedLikesScreen> createState() =>
      _ReceivedLikesScreenState();
}

class _ReceivedLikesScreenState extends ConsumerState<ReceivedLikesScreen> {
  late final StorageService _storage;
  final _items = <Map<String, dynamic>>[];
  String? _cursor, _error;
  int? _count;
  int _generation = 0;
  bool _loading = true, _guest = false;
  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider)..addListener(_changed);
    _load();
  }

  void _changed() => _load();
  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _cursor = null;
        _count = null;
      }
    });
    try {
      final token = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (token?.isNotEmpty != true) {
        setState(() {
          _guest = true;
          _loading = false;
        });
        return;
      }
      setState(() => _guest = false);
      final data = await ref
          .read(socialServiceProvider)
          .request(
            '/likes${more && _cursor != null ? '?cursor=${Uri.encodeComponent(_cursor!)}' : ''}',
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = data['votesReceived'] as int?;
        _items.addAll(
          (data['items'] as List? ?? []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        _cursor = data['nextCursor'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Couldn’t load Likes. Try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Likes'),
      automaticallyImplyLeading: false,
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_count != null)
            Text(
              '$_count received ${_count == 1 ? 'like' : 'likes'}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          if (_guest) const Text('Sign in to see your Likes.'),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(more: _items.isNotEmpty),
              child: const Text('Retry'),
            ),
          ],
          if (!_loading && !_guest && _error == null && _items.isEmpty)
            Text(
              _count == 0
                  ? 'Your received Likes will appear here.'
                  : 'No available Likes to show.',
            ),
          for (final item in _items)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(
                  Icons.favorite_outline,
                  color: AppColors.primaryBlue,
                ),
                title: Text(item['question'] as String? ?? ''),
                subtitle: Text(_date(item['occurredAt'])),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _cursor != null)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    ),
  );
  String _date(dynamic value) {
    final date = DateTime.tryParse(value is String ? value : '');
    if (date == null) return '';
    return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
  }
}
