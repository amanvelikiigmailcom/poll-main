import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

class VoterRevealCard extends ConsumerStatefulWidget {
  const VoterRevealCard({super.key, required this.voteId, this.onShare});
  final String? voteId;
  final VoidCallback? onShare;
  @override
  ConsumerState<VoterRevealCard> createState() => _VoterRevealCardState();
}

class _VoterRevealCardState extends ConsumerState<VoterRevealCard> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  int _generation = 0;
  late final StorageService _storage;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _storage.addListener(_accountChanged);
    if (widget.voteId?.isNotEmpty == true) _load();
  }

  void _accountChanged() {
    _generation++;
    _expiry?.cancel();
    if (mounted) {
      setState(() {
        _data = null;
        _error = null;
        _busy = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant VoterRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voteId != widget.voteId) {
      _accountChanged();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_accountChanged);
    _expiry?.cancel();
    super.dispose();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Couldn’t load this vote. Please try again.';
  void _accept(Map<String, dynamic> result) {
    _expiry?.cancel();
    setState(() {
      _data = result;
      _error = null;
    });
    final end = DateTime.tryParse(result['premiumExpiry'] as String? ?? '');
    if (result['active'] == true && end != null) {
      _expiry = Timer(end.difference(DateTime.now()), () {
        if (mounted) {
          setState(() {
            _data = null;
            _error = 'Premium expired. Refresh your subscription status.';
          });
        }
      });
    }
  }

  Future<void> _load() async {
    final id = widget.voteId;
    if (id == null || id.isEmpty) return;
    final generation = ++_generation;
    try {
      final result = await ref.read(premiumServiceProvider).vote(id);
      if (mounted && generation == _generation) _accept(result);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _data = null;
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, dynamic> status;
      try {
        status = await ref.read(premiumServiceProvider).status();
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        status = {'active': false};
      }
      if (!mounted || generation != _generation) return;
      if (status['active'] != true) {
        await context.push(AppRoutes.premium);
        if (mounted && generation == _generation) await _load();
        return;
      }
      final id = widget.voteId;
      if (id == null || id.isEmpty) {
        throw const ApiException(
          'This vote is not available for identity reveals.',
        );
      }
      final current = await ref.read(premiumServiceProvider).vote(id);
      if (!mounted || generation != _generation) return;
      _accept(current);
      final remaining = current['remaining'] as Map? ?? {};
      final reset = DateTime.tryParse(current['resetsAt'] as String? ?? '');
      final kind = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reveal your voter',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: const Text('Reveal full name'),
                subtitle: Text('${remaining['full'] ?? 0} left this week'),
                enabled:
                    (remaining['full'] as int? ?? 0) > 0 ||
                    current['revealed'] == 'full',
                onTap: () => Navigator.pop(context, 'full'),
              ),
              ListTile(
                title: const Text('Reveal first initial'),
                subtitle: Text('${remaining['initial'] ?? 0} left this week'),
                enabled:
                    (remaining['initial'] as int? ?? 0) > 0 ||
                    current['revealed'] != null,
                onTap: () => Navigator.pop(context, 'initial'),
              ),
              if (reset != null)
                Text(
                  'Weekly limits reset ${DateFormat.yMMMd().add_jm().format(reset.toLocal())}.',
                ),
              const Text('No reveals left? Wait for your weekly reset.'),
            ],
          ),
        ),
      );
      if (kind == null || !mounted || generation != _generation) return;
      final result = await ref.read(premiumServiceProvider).reveal(id, kind);
      if (mounted && generation == _generation) {
        _accept(result);
        if (result['status'] == 'PROTECTED_BY_PREMIUM') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This user also has Premium. Their votes are protected. Your reveal was not used.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        // Do not retain previously displayed private data after a failed recheck.
        setState(() {
          _data = null;
          _error = _message(error);
        });
        if (error is ApiException && error.statusCode == 403) {
          await context.push(AppRoutes.premium);
          if (mounted && generation == _generation) await _load();
        }
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final year = data?['graduationYear'];
    final gender = switch (data?['gender']) {
      'female' => 'girl',
      'male' => 'boy',
      'nonbinary' || 'non-binary' => 'non-binary student',
      _ => 'student',
    };
    final name = data?['revealed'] == 'full'
        ? (data?['name'] as String?)
        : data?['revealed'] == 'initial'
        ? '${data?['initial'] ?? ''}.'
        : null;
    final protected = data?['status'] == 'PROTECTED_BY_PREMIUM';
    final label =
        'From ${name == null ? 'a $gender' : '$name ($gender)'}'
        '${year is int ? ' · Graduating in $year' : ''}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voter', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  protected
                      ? 'This user also has Premium'
                      : data == null
                      ? 'Voter identity is hidden'
                      : label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (protected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Their votes are protected from name and first-initial reveals. Your reveal was not used.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(
                _busy ? 'Please wait…' : 'Find out who voted for you',
              ),
            ),
          ),
          if (widget.onShare != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onShare,
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
