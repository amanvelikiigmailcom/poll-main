import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../../providers/user_provider.dart';
import '../../services/contact_picker_service.dart';
import '../../services/local_game_service.dart';

const Color _primaryBlue = Color(0xFF4B6EF5);
const int _minFriends = LocalGameService.minFriends;

/// Upper bound for one contacts-picking round: plenty for quiz variety
/// without stuffing the friends list from a large multi-select.
const int _maxPickedContacts = 10;

/// Local quiz setup: a display name or nickname and at least 4 participants.
class NamesEntryScreen extends ConsumerStatefulWidget {
  const NamesEntryScreen({super.key});

  @override
  ConsumerState<NamesEntryScreen> createState() => _NamesEntryScreenState();
}

class _NamesEntryScreenState extends ConsumerState<NamesEntryScreen> {
  /// 0 = own name, 1 = participants
  int _step = 0;

  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _friendController = TextEditingController();
  final FocusNode _playerFocus = FocusNode();
  final FocusNode _friendFocus = FocusNode();

  String? _playerName;
  final List<String> _friends = [];
  bool _saving = false;

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
    final existingPlayer = await LocalGameService.instance.getPlayerName();
    final existingFriends = await LocalGameService.instance.getNames();
    if (!mounted) return;

    if (existingPlayer != null && existingPlayer.isNotEmpty) {
      _playerName = existingPlayer;
      _playerController.text = existingPlayer;
    }
    if (existingFriends.isNotEmpty) {
      _friends
        ..clear()
        ..addAll(existingFriends);
    }

    final step = existingPlayer != null && existingPlayer.isNotEmpty ? 1 : 0;
    setState(() => _step = step);
    _refocus(step == 0 ? _playerFocus : _friendFocus);
  }

  @override
  void dispose() {
    _playerController.dispose();
    _friendController.dispose();
    _playerFocus.dispose();
    _friendFocus.dispose();
    super.dispose();
  }

  void _goToFriendsStep() {
    final name = _playerController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _playerName = name;
      _step = 1;
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
        const SnackBar(
            content: Text("That is your game name. Add another participant.")),
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
    setState(() {
      _friends.remove(name);
    });
  }

  Future<void> _continue() async {
    final player = _playerName?.trim() ?? '';
    if (player.isEmpty || _friends.length < _minFriends || _saving) return;
    setState(() => _saving = true);
    try {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: player,
        friends: List<String>.from(_friends),
      );
      if (!mounted) return;
      await ref.read(localProfileProvider.notifier).refresh();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your game. Try again.')),
      );
    }
  }

  Future<void> _tryExamples() async {
    if (_saving) return;
    setState(() {
      _playerName = _playerController.text.trim().isEmpty
          ? 'Player'
          : _playerController.text.trim();
      _friends
        ..clear()
        ..addAll(['Alex', 'Sam', 'Jordan', 'Taylor', 'Casey']
            .where((name) => name.toLowerCase() != _playerName!.toLowerCase())
            .take(_minFriends));
    });
    await _continue();
  }

  Widget _exampleButton() => OutlinedButton.icon(
        onPressed: _saving ? null : _tryExamples,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        icon: const Icon(Icons.play_circle_outline),
        label: const Text('Try with example names'),
      );

  Future<void> _pickFromContacts() async {
    if (_saving) return;
    final svc = ContactPickerService.instance;
    if (!svc.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Contacts aren’t available here — type the names instead.')),
      );
      return;
    }
    final exclude = <String>{
      (_playerName ?? '').trim().toLowerCase(),
      ..._friends.map((n) => n.toLowerCase()),
    }..remove('');
    final picked =
        await svc.pickNames(maxNames: _maxPickedContacts, excludeLower: exclude);
    if (!mounted || picked.isEmpty) return;
    setState(() => _friends.addAll(picked));
  }

  Widget _contactsButton() => OutlinedButton.icon(
        onPressed: _saving ? null : _pickFromContacts,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        icon: const Icon(Icons.contacts_outlined),
        label: const Text('Choose from contacts'),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: switch (_step) {
            0 => _buildPlayerStep(),
            _ => _buildFriendsStep(),
          },
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
          'What should we call you?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use a nickname or game name. No account or real name needed.',
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
            hintText: 'Your nickname',
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
            onPressed: canNext && !_saving ? _goToFriendsStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        _exampleButton(),
      ],
    );
  }

  Widget _buildFriendsStep() {
    final canContinue = _friends.length >= _minFriends && !_saving;
    final enough = _friends.length >= _minFriends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _step = 0);
                _refocus(_playerFocus);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                'Hi, ${_playerName ?? ''}',
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
          'Choose your friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nicknames or fictional names are welcome, or pick real first '
          'names from your contacts. Only the names you choose are used, '
          'and they stay on this device. No invitations needed.',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (!enough)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white38),
            ),
            child: Text(
              'Add at least $_minFriends participants. '
              'You have ${_friends.length}. '
              '${_minFriends - _friends.length} more to go.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB9F6CA).withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF69F0AE)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Four is enough',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Continue, or add more names for the quiz cards.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          hintText: 'Participant name',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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
                      avatar: const Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        _playerName ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: const Color(0xFF2F4FD6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_friends.isEmpty) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Add at least $_minFriends participants',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
                if (enough) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'They will not get a notification. These names are only on your quiz cards.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canContinue ? _continue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              enough
                  ? 'Continue'
                  : 'At least $_minFriends participants '
                      '(${_minFriends - _friends.length} more)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        _contactsButton(),
        _exampleButton(),
      ],
    );
  }
}
