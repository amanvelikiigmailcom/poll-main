import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/received_vote.dart';
import '../../providers/service_providers.dart';
import '../../services/storage_service.dart';
import '../../services/story_share_service.dart';
import '../../theme/app_colors.dart';

/// Only an owned, freshly authorized received vote can be shared.
class LikeShareScreen extends ConsumerStatefulWidget {
  const LikeShareScreen({super.key, this.voteId, this.storyShare});
  final String? voteId;
  final StoryShareService? storyShare;

  @override
  ConsumerState<LikeShareScreen> createState() => _LikeShareScreenState();
}

class _LikeShareScreenState extends ConsumerState<LikeShareScreen> {
  final _imageKey = GlobalKey();
  late final StorageService _storage;
  late final StoryShareService _sharing;
  ReceivedVote? _vote;
  String? _error;
  String? _ownerToken;
  int _generation = 0;
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider)..addListener(_accountChanged);
    _sharing = widget.storyShare ?? StoryShareService();
    _load();
  }

  void _accountChanged() {
    _generation++;
    if (!mounted) return;
    setState(() {
      _vote = null;
      _ownerToken = null;
      _loading = false;
      _busy = false;
      _error = 'Your account changed. Reopen this Like from your Likes list.';
    });
  }

  @override
  void didUpdateWidget(covariant LikeShareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voteId != widget.voteId) _load();
  }

  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _vote = null;
      _ownerToken = null;
      _busy = false;
    });
    try {
      final id = widget.voteId;
      if (id == null || id.isEmpty) throw StateError('Missing quiz result.');
      final token = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (token?.isNotEmpty != true) throw StateError('Signed out.');
      final data = await ref
          .read(socialServiceProvider)
          .request('/likes/${Uri.encodeComponent(id)}');
      final currentToken = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (currentToken != token) {
        _accountChanged();
        return;
      }
      final vote = ReceivedVote.fromJson(data);
      if (vote.id != id || vote.question.trim().isEmpty) {
        throw StateError('Invalid quiz result.');
      }
      setState(() {
        _vote = vote;
        _ownerToken = token;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Couldn’t load this Like. It may no longer be available.';
        });
      }
    }
  }

  Future<void> _share(StoryShareTarget target, Rect origin) async {
    if (_busy || _vote == null) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      // Recheck permissions/blocks immediately before creating a public image.
      final token = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (token != _ownerToken || token == null) {
        _accountChanged();
        return;
      }
      final data = await ref
          .read(socialServiceProvider)
          .request('/likes/${Uri.encodeComponent(widget.voteId!)}');
      final currentToken = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (currentToken != token) {
        _accountChanged();
        return;
      }
      final vote = ReceivedVote.fromJson(data);
      if (vote.id != widget.voteId || vote.question.trim().isEmpty) {
        throw StateError('Invalid quiz result.');
      }
      setState(() => _vote = vote);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _generation) return;
      final png = await _sharing.capture(_imageKey);
      final handoffToken = await _storage.getToken();
      if (!mounted || generation != _generation) return;
      if (handoffToken != token) {
        _accountChanged();
        return;
      }
      if (png == null || png.isEmpty) throw StateError('Image unavailable.');
      final result = await _sharing.share(
        png: png,
        target: target,
        origin: origin,
      );
      if (!mounted || generation != _generation) return;
      if (result == StoryShareOutcome.failed) {
        _notice('Couldn’t share the image. Please try again.');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _vote = null;
          _error = 'Couldn’t prepare this Like. Refresh and try again.';
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Share your Like')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _vote == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ?? 'Like not available.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Fixed capture resolution: 360x640 logical => 1080x1920 PNG.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _imageKey,
                    child: LikeStoryCard(vote: _vote!),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Share the moment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final target in StoryShareTarget.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Builder(
                      builder: (buttonContext) => SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  final box =
                                      buttonContext.findRenderObject()!
                                          as RenderBox;
                                  _share(
                                    target,
                                    box.localToGlobal(Offset.zero) & box.size,
                                  );
                                },
                          child: Text(switch (target) {
                            StoryShareTarget.instagram => 'Instagram',
                            StoryShareTarget.snapchat => 'Snapchat',
                            StoryShareTarget.tiktok => 'TikTok',
                          }),
                        ),
                      ),
                    ),
                  ),
                const Text(
                  'Instagram and Snapchat open their editor when configured. '
                  'Otherwise, including TikTok, choose an available app in the share menu. '
                  'You decide where to post and confirm publication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
  );
}

/// The capture boundary contains ONLY this explicit public projection.
/// Participant names are candidates, NOT identities of the people who voted.
class LikeStoryCard extends StatelessWidget {
  const LikeStoryCard({super.key, required this.vote});
  final ReceivedVote vote;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.all(26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2E6C), AppColors.primaryBlue],
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontFamily: 'sans-serif',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'FLYPROX',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 28),
            const Icon(Icons.favorite, color: Colors.white, size: 46),
            const SizedBox(height: 12),
            const Text(
              'Someone picked me',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 308,
                    child: Text(
                      vote.question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              vote.voterLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (vote.participants.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'In this quiz',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final participant in vote.participants.take(12))
                    SizedBox(
                      width: 150,
                      child: Text(
                        '${participant.name}${participant.graduationYear == null ? '' : ' · ${participant.graduationYear}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
              if (vote.participants.length > 12)
                Text('+${vote.participants.length - 12} more participants'),
            ],
            const SizedBox(height: 24),
            const Text(
              'A little kindness goes a long way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
