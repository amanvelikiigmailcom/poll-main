import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../router/app_router.dart';
import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../services/contact_picker_service.dart';
import '../../services/contact_sync_service.dart';
import '../../services/local_game_service.dart';
import '../../services/content_service.dart';

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
  bool _syncing = false;
  List<ContactMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _refocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _saving || ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
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

  Future<void> _goToFriendsStep() async {
    final name = _playerController.text.trim();
    if (name.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Move to the friends step first: the phone screens sit on top, and
    // popping back must reveal this step (go() would reuse this same state).
    setState(() {
      _playerName = name;
      _step = 1;
    });
    await LocalGameService.instance.savePlayerName(name);
    if (!mounted) return;
    final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      _refocus(_friendFocus);
    } else {
      context.push(AppRoutes.phone);
    }
  }

  void _addFriend({bool keepKeyboard = true}) {
    final name = _friendController.text.trim();
    if (name.isEmpty) {
      if (keepKeyboard) _refocus(_friendFocus);
      return;
    }
    final player = (_playerName ?? '').toLowerCase();
    if (name.toLowerCase() == player) {
      _friendController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("That is your game name. Add another participant."),
        ),
      );
      if (keepKeyboard) _refocus(_friendFocus);
      return;
    }
    if (_friends.any((n) => n.toLowerCase() == name.toLowerCase())) {
      _friendController.clear();
      if (keepKeyboard) _refocus(_friendFocus);
      return;
    }
    setState(() {
      _friends.add(name);
      _friendController.clear();
    });
    if (keepKeyboard) {
      _refocus(_friendFocus);
    } else {
      _friendFocus.unfocus();
    }
  }

  void _removeFriend(String name) {
    setState(() {
      _friends.remove(name);
    });
  }

  Future<void> _continue() async {
    final player = _playerName?.trim() ?? '';
    if (player.isEmpty || _friends.length < _minFriends || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
        ..addAll(
          ['Alex', 'Sam', 'Jordan', 'Taylor', 'Casey']
              .where((name) => name.toLowerCase() != _playerName!.toLowerCase())
              .take(_minFriends),
        );
    });
    await _continue();
  }

  Widget _exampleButton() => OutlinedButton.icon(
    onPressed: _saving ? null : _tryExamples,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    icon: const Icon(Icons.play_circle_outline),
    label: const Text('Try with example names'),
  );

  IsoCode _defaultRegion() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    if (code == null || code.isEmpty) return IsoCode.US;
    try {
      return IsoCode.fromJson(code);
    } catch (_) {
      return IsoCode.US;
    }
  }

  Future<void> _pickFromContacts({bool single = false}) async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picker = ContactPickerService.instance;
    if (!picker.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contacts aren’t available here — type the names instead.',
          ),
        ),
      );
      return;
    }
    final exclude = <String>{
      (_playerName ?? '').trim().toLowerCase(),
      ..._friends.map((n) => n.toLowerCase()),
    }..remove('');
    final picked = await picker.pickEntries(
      maxNames: single ? 1 : _maxPickedContacts,
      excludeLower: exclude,
      single: single,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _friends.addAll(picked.map((e) => e.name));
      _matches = [];
    });
    await _syncMatches(picked);
  }

  /// Uploads hashes of picked numbers (logged-in users only) and shows which
  /// friends already play. Guests keep the local names with no upload.
  Future<void> _syncMatches(List<PickedContact> picked) async {
    final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
    if (!mounted || !loggedIn) return;
    setState(() => _syncing = true);
    final matches = await ref
        .read(contactSyncServiceProvider)
        .syncContacts(picked, defaultRegion: _defaultRegion());
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _matches = matches;
    });
  }

  Widget _matchesBanner() {
    if (_syncing) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Finding friends…',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }
    if (_matches.isEmpty) return const SizedBox.shrink();
    final names = _matches.map((m) => m.displayName).join(', ');
    final verb = _matches.length == 1 ? 'plays' : 'play';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700)),
      ),
      child: Text(
        '⭐ $names already $verb Flyprox',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _contactsButton() => OutlinedButton.icon(
    onPressed: _saving ? null : _pickFromContacts,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    icon: const Icon(Icons.contacts_outlined),
    label: const Text('Choose from contacts'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: switch (_step) {
              0 => _buildPlayerStep(),
              _ => _buildFriendsStep(),
            },
          ),
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
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _goToFriendsStep(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Your nickname',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
    final enough = _friends.length >= _minFriends;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
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
            'Add nicknames or choose contacts for your quiz cards.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendController,
                  focusNode: _friendFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addFriend(keepKeyboard: false),
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
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    semanticLabel: 'Add participant',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            enough
                ? '${_friends.length} participants · Ready to play'
                : '${_friends.length} / $_minFriends participants · Add ${_minFriends - _friends.length} more',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text(_playerName ?? ''),
              ),
              ..._friends.map(
                (name) => Chip(
                  label: Text(name),
                  onDeleted: () => _removeFriend(name),
                ),
              ),
            ],
          ),
          _matchesBanner(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: enough && !_saving ? _continue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Continue'),
          ),
          if (ContentService.instance.flag('contacts_enabled')) ...[
            const SizedBox(height: 12),
            _contactsButton(),
            TextButton.icon(
              onPressed: _saving ? null : () => _pickFromContacts(single: true),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.search),
              label: const Text('Find one contact'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only contacts you select are used. If signed in, selected '
              'names and hashed phone numbers are sent to Flyprox to find friends. '
              'Your full address book and raw contact numbers are never uploaded. '
              'No invitations are sent.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _exampleButton(),
        ],
      ),
    );
  }
}
