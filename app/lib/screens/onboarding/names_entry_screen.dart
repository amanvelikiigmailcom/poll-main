import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const int _minFriends = LocalGameService.minFriends;

/// Gas-style onboarding:
/// 1) Your own name (always appears as one of 4 answer cards)
/// 2) At least 3 classmates — the other three cards each round
class NamesEntryScreen extends StatefulWidget {
  const NamesEntryScreen({super.key});

  @override
  State<NamesEntryScreen> createState() => _NamesEntryScreenState();
}

class _NamesEntryScreenState extends State<NamesEntryScreen> {
  /// 0 = own name, 1 = friends list
  int _step = 0;

  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();
  String? _playerName;
  final List<String> _friends = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final existingPlayer = await LocalGameService.instance.getPlayerName();
    final existingFriends = await LocalGameService.instance.getNames();
    if (!mounted) return;
    if (existingPlayer != null && existingPlayer.isNotEmpty) {
      setState(() {
        _playerName = existingPlayer;
        _playerController.text = existingPlayer;
        _friends
          ..clear()
          ..addAll(existingFriends);
        // If already complete, still show friends step so they can edit.
        _step = 1;
      });
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    _friendController.dispose();
    super.dispose();
  }

  void _goToFriendsStep() {
    final name = _playerController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _playerName = name;
      _step = 1;
    });
  }

  void _addFriend() {
    final name = _friendController.text.trim();
    if (name.isEmpty) return;
    final player = (_playerName ?? '').toLowerCase();
    if (name.toLowerCase() == player) {
      _friendController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Это уже твоё имя — добавь одноклассников')),
      );
      return;
    }
    if (_friends.any((n) => n.toLowerCase() == name.toLowerCase())) {
      _friendController.clear();
      return;
    }
    setState(() {
      _friends.add(name);
      _friendController.clear();
    });
  }

  void _removeFriend(String name) {
    setState(() => _friends.remove(name));
  }

  Future<void> _continue() async {
    final player = _playerName?.trim() ?? '';
    if (player.isEmpty || _friends.length < _minFriends || _saving) return;
    setState(() => _saving = true);
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: player,
      friends: List<String>.from(_friends),
    );
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: _step == 0 ? _buildPlayerStep() : _buildFriendsStep(),
        ),
      ),
    );
  }

  Widget _buildPlayerStep() {
    final canNext = _playerController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Как тебя зовут?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Твоё имя будет в опросах вместе с одноклассниками — '
          'на каждый вопрос 4 карточки: ты + трое других',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _playerController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _goToFriendsStep(),
          autofocus: true,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Твоё имя',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canNext ? _goToFriendsStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              disabledBackgroundColor: Colors.white.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Дальше',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsStep() {
    final canContinue = _friends.length >= _minFriends && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                'Привет, ${_playerName ?? ''}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Кого добавим в класс?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Минимум $_minFriends имени — на вопрос выпадут трое из них + ты',
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _friendController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addFriend(),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Имя одноклассника',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              width: 52,
              child: ElevatedButton(
                onPressed: _addFriend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: const Icon(Icons.add_rounded, size: 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Always show self chip so user sees they are in the pool
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Chip(
              avatar: const Icon(Icons.person, size: 18, color: Colors.white),
              label: Text(
                _playerName ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: const Color(0xFF2F4FD6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            ..._friends.map(
              (name) => Chip(
                label: Text(
                  name,
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.white,
                deleteIcon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _primaryBlue,
                ),
                onDeleted: () => _removeFriend(name),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _friends.isEmpty
              ? Center(
                  child: Text(
                    'Добавь минимум $_minFriends друзей',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canContinue ? _continue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              disabledBackgroundColor: Colors.white.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              _friends.length >= _minFriends
                  ? 'Начать'
                  : 'Ещё ${_minFriends - _friends.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
