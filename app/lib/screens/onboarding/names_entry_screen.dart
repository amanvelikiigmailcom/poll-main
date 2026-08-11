import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../services/local_game_service.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const int _minFriends = LocalGameService.minFriends;

/// Gas-style onboarding:
/// 0) Username / login (required)
/// 1) Your display name (always on answer cards)
/// 2) At least 3 classmates
class NamesEntryScreen extends StatefulWidget {
  const NamesEntryScreen({super.key});

  @override
  State<NamesEntryScreen> createState() => _NamesEntryScreenState();
}

class _NamesEntryScreenState extends State<NamesEntryScreen> {
  /// 0 = login, 1 = own name, 2 = friends
  int _step = 0;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _playerFocus = FocusNode();
  final FocusNode _friendFocus = FocusNode();

  String? _username;
  String? _playerName;
  final List<String> _friends = [];
  bool _saving = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _refocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      node.requestFocus();
    });
  }

  Future<void> _prefill() async {
    final existingUser = await LocalGameService.instance.getUsername();
    final existingPlayer = await LocalGameService.instance.getPlayerName();
    final existingFriends = await LocalGameService.instance.getNames();
    if (!mounted) return;

    if (existingUser != null && existingUser.isNotEmpty) {
      _username = existingUser;
      _usernameController.text = existingUser;
    }
    if (existingPlayer != null && existingPlayer.isNotEmpty) {
      _playerName = existingPlayer;
      _playerController.text = existingPlayer;
    }
    if (existingFriends.isNotEmpty) {
      _friends
        ..clear()
        ..addAll(existingFriends);
    }

    // Resume at the first incomplete step when editing.
    int step = 0;
    if (existingUser != null && existingUser.isNotEmpty) {
      step = 1;
      if (existingPlayer != null && existingPlayer.isNotEmpty) {
        step = 2;
      }
    }
    setState(() => _step = step);
    if (step == 0) {
      _refocus(_usernameFocus);
    } else if (step == 1) {
      _refocus(_playerFocus);
    } else {
      _refocus(_friendFocus);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _playerController.dispose();
    _friendController.dispose();
    _usernameFocus.dispose();
    _playerFocus.dispose();
    _friendFocus.dispose();
    super.dispose();
  }

  bool get _usernameValid {
    return LocalGameService.validateUsername(_usernameController.text) == null;
  }

  void _goToNameStep() {
    final err = LocalGameService.validateUsername(_usernameController.text);
    setState(() => _usernameError = err);
    if (err != null) {
      _refocus(_usernameFocus);
      return;
    }
    setState(() {
      _username = _usernameController.text.trim();
      _step = 1;
    });
    _refocus(_playerFocus);
  }

  void _goToFriendsStep() {
    final name = _playerController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _playerName = name;
      _step = 2;
    });
    _refocus(_friendFocus);
  }

  void _addFriend() {
    final name = _friendController.text.trim();
    if (name.isEmpty) {
      _refocus(_friendFocus);
      return;
    }
    final player = (_playerName ?? '').toLowerCase();
    if (name.toLowerCase() == player) {
      _friendController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Это уже твоё имя — добавь одноклассников')),
      );
      _refocus(_friendFocus);
      return;
    }
    if (_friends.any((n) => n.toLowerCase() == name.toLowerCase())) {
      _friendController.clear();
      _refocus(_friendFocus);
      return;
    }
    setState(() {
      _friends.add(name);
      _friendController.clear();
    });
    _refocus(_friendFocus);
  }

  void _removeFriend(String name) {
    setState(() => _friends.remove(name));
  }

  Future<void> _continue() async {
    final user = _username?.trim() ?? '';
    final player = _playerName?.trim() ?? '';
    if (user.isEmpty ||
        player.isEmpty ||
        _friends.length < _minFriends ||
        _saving) {
      return;
    }
    setState(() => _saving = true);
    await LocalGameService.instance.savePlayerAndFriends(
      username: user,
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
          child: switch (_step) {
            0 => _buildUsernameStep(),
            1 => _buildPlayerStep(),
            _ => _buildFriendsStep(),
          },
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Придумай логин',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Обязательно. Латиница, цифры и _ · минимум 3 символа. '
          'Так тебя будут видеть в профиле.',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            setState(() {
              _usernameError =
                  LocalGameService.validateUsername(_usernameController.text);
            });
          },
          onSubmitted: (_) => _goToNameStep(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            LengthLimitingTextInputFormatter(24),
          ],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'например: aman_07',
            prefixText: '@',
            prefixStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
            errorText: _usernameError,
            errorStyle: const TextStyle(color: Color(0xFFFFCDD2)),
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
            onPressed: _usernameValid ? _goToNameStep : null,
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

  Widget _buildPlayerStep() {
    final canNext = _playerController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _step = 0);
                _refocus(_usernameFocus);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                '@${_username ?? ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          'Имя на карточках в опросах — ты + трое одноклассников',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _playerController,
          focusNode: _playerFocus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _goToFriendsStep(),
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
              onPressed: () {
                setState(() => _step = 1);
                _refocus(_playerFocus);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                'Привет, ${_playerName ?? ''} · @${_username ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
                focusNode: _friendFocus,
                autofocus: true,
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
