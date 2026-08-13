import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

// Tracks whether a vote round is available right now or the 40-minute
// break timer is still running, using LocalGameService's local state.
enum _HomeTabState { loading, timerActive, voteAvailable }

class MainTab extends ConsumerStatefulWidget {
  const MainTab({super.key});

  @override
  ConsumerState<MainTab> createState() => _MainTabState();
}

class _MainTabState extends ConsumerState<MainTab> {
  _HomeTabState _tabState = _HomeTabState.loading;

  int _secondsRemaining = 0;
  Timer? _ticker;

  int _starsCount = 0;
  final int _votesReceivedToday = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final remaining = await LocalGameService.instance.secondsUntilNextRound();
    final stars = await LocalGameService.instance.getStars();
    if (!mounted) return;
    setState(() {
      _starsCount = stars;
      _secondsRemaining = remaining;
      _tabState =
          remaining > 0 ? _HomeTabState.timerActive : _HomeTabState.voteAvailable;
    });
    _ticker?.cancel();
    if (remaining > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_secondsRemaining <= 1) {
          t.cancel();
          setState(() {
            _secondsRemaining = 0;
            _tabState = _HomeTabState.voteAvailable;
          });
        } else {
          setState(() => _secondsRemaining--);
        }
      });
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Start poll only if login + name + ≥3 friends. No school-wait screen.
  Future<void> _startVote() async {
    final ready = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    if (ready) {
      context.push(AppRoutes.vote);
      return;
    }
    final friends = await LocalGameService.instance.getNames();
    final need = LocalGameService.minFriends - friends.length;
    if (!mounted) return;
    final msg = friends.length < LocalGameService.minFriends
        ? (need > 0
            ? 'Минимум нужно ввести ${LocalGameService.minFriends} друзей. Ещё $need.'
            : 'Минимум нужно ввести ${LocalGameService.minFriends} друзей.')
        : 'Заполни логин и своё имя, затем минимум ${LocalGameService.minFriends} друзей.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Добавить',
          onPressed: () => context.push(AppRoutes.namesEntry),
        ),
      ),
    );
    // Open names so they can add the missing friends
    context.push(AppRoutes.namesEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadState,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildStatsRow(),
              const SizedBox(height: 20),
              if (_tabState == _HomeTabState.loading) _buildLoadingCard(),
              if (_tabState == _HomeTabState.timerActive) _buildTimerCard(),
              if (_tabState == _HomeTabState.voteAvailable) _buildVoteCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFFB800),
            value: '$_starsCount',
            label: 'Звёзды',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite,
            iconColor: const Color(0xFFFF3B5C),
            value: '$_votesReceivedToday',
            label: 'Голосов сегодня',
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF4B6EF5)),
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B6EF5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B6EF5).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Следующий опрос через',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_secondsRemaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push(AppRoutes.timer),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Подробнее'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B5C).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.how_to_vote_outlined, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Опрос доступен!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Проголосуй, чтобы получить звёзды',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF3B5C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Перейти к опросу',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
