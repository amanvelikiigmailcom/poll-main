import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  late final StorageService _storage;
  String? _next, _error;
  bool _loading = true, _more = false, _campusRequired = false, _guest = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _storage.addListener(_accountChanged);
    _scroll.addListener(_onScroll);
    unawaited(_load());
  }

  void _accountChanged() {
    _generation++;
    if (!mounted) return;
    setState(() {
      _items.clear();
      _next = null;
      _error = null;
      _more = false;
    });
    unawaited(_load());
  }

  void _onScroll() {
    if (_scroll.position.userScrollDirection == ScrollDirection.reverse &&
        _scroll.position.extentAfter < 240 &&
        !_loading &&
        !_more &&
        _next != null &&
        _error == null &&
        _items.length < 200) {
      unawaited(_load(more: true));
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_more || _next == null)) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final data = await ref
          .read(activityServiceProvider)
          .page(cursor: more ? _next : null);
      if (!mounted || generation != _generation) return;
      final rows = (data['items'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      setState(() {
        if (!more) _items.clear();
        final known = _items.map((row) => row['id']).toSet();
        _items.addAll(
          rows.where((row) => known.add(row['id'])).take(200 - _items.length),
        );
        _next = _items.length >= 200 ? null : data['nextCursor'] as String?;
        _campusRequired = data['campusRequired'] == true;
        _guest = false;
        _loading = _more = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _guest = error is ApiException && error.statusCode == 401;
        if (error is ApiException &&
            (error.statusCode == 401 || error.statusCode == 409)) {
          _items.clear();
          _next = null;
        }
        _error = error is ApiException
            ? error.message
            : 'Couldn’t load activity. Please try again.';
        _loading = _more = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_accountChanged);
    _scroll.dispose();
    super.dispose();
  }

  String _timeAgo(String timestamp) {
    final time = DateTime.tryParse(timestamp);
    if (time == null) return '';
    final age = DateTime.now().difference(time);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Activity'), centerTitle: true),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView.builder(
              key: const Key('activity-list'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index < _items.length) return _card(_items[index]);
                if (_more) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        if (!_guest)
                          TextButton(
                            onPressed: () =>
                                _load(more: _items.isNotEmpty && _next != null),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  );
                }
                if (_items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 72,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 48,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _campusRequired
                              ? 'Choose your campus first'
                              : 'No campus activity yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _campusRequired
                              ? 'Campus activity appears after you select a campus.'
                              : 'Completed campus votes will appear here.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox(height: 24);
              },
            ),
          ),
  );
  Widget _card(Map<String, dynamic> item) => Container(
    key: ValueKey('activity-${item['id']}'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star_rounded,
            color: AppColors.primaryBlue,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['chosenName']} was chosen',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item['question'] as String,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              if (item['graduationYear'] is int) ...[
                const SizedBox(height: 10),
                Text(
                  'From a student graduating in ${item['graduationYear']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _timeAgo(item['occurredAt'] as String),
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
