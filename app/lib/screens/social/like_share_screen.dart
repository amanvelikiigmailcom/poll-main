import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/received_vote.dart';
import '../../providers/service_providers.dart';
import '../../services/storage_service.dart';
import '../../services/story_share_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/vote_result_content.dart';

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
                  'Choose where to share. You confirm the post in that app.',
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

/// The same result as Quiz result, without private reveal controls or chrome.
class LikeStoryCard extends StatelessWidget {
  const LikeStoryCard({super.key, required this.vote});
  final ReceivedVote vote;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.all(20),
      color: AppColors.background,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              VoteResultContent(vote: vote),
              const SizedBox(height: 24),
              const Text(
                'FLYPROX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
