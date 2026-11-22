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
const int _maxPickedContacts = 10;
const int _maxContacts = 50;

/// Selected contacts only; manual nickname/participant input is retired.
class NamesEntryScreen extends ConsumerStatefulWidget {
  const NamesEntryScreen({super.key});
  @override
  ConsumerState<NamesEntryScreen> createState() => _NamesEntryScreenState();
}

class _NamesEntryScreenState extends ConsumerState<NamesEntryScreen> {
  String _playerName = 'Michael';
  final List<String> _friends = [];
  bool _loading = true;
  bool _saving = false;
  bool _choosing = false;
  bool _syncing = false;
  List<ContactMatch> _matches = [];
  bool get _busy => _loading || _saving || _choosing || _syncing;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final game = LocalGameService.instance;
    final existingPlayer = await game.getPlayerName();
    final existingFriends = await game.getNames();
    if (!mounted) return;
    setState(() {
      if (existingPlayer != null && existingPlayer.isNotEmpty) {
        _playerName = existingPlayer;
      }
      _friends.addAll(existingFriends);
      _loading = false;
    });
  }

  Future<void> _continue() async {
    if (_friends.length < _minFriends || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: _playerName,
        friends: List<String>.from(_friends),
      );
      if (!mounted) return;
      await ref.read(localProfileProvider.notifier).refresh();
      if (!mounted) return;
      final loggedIn = await ref.read(authServiceProvider).isLoggedIn();
      final needsPush =
          loggedIn && await ref.read(pushServiceProvider).needsPrompt();
      if (!mounted) return;
      context.go(needsPush ? AppRoutes.pushPrompt : AppRoutes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your game. Try again.')),
      );
    }
  }

  Future<void> _tryExamples() async {
    if (_busy || !ContentService.instance.flag('example_names_enabled')) return;
    setState(() {
      _playerName = 'Michael';
      _friends
        ..clear()
        ..addAll(['Alex', 'Sam', 'Jordan', 'Taylor']);
    });
    await _continue();
  }

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
    if (_saving || _choosing || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picker = ContactPickerService.instance;
    if (!picker.isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contacts aren’t available here. Try example names or enable Contacts in iPhone Settings.',
          ),
        ),
      );
      return;
    }
    final exclude = <String>{..._friends.map((n) => n.toLowerCase())}
      ..remove('');
    final remaining = (_maxContacts - _friends.length).clamp(
      0,
      _maxPickedContacts,
    );
    if (remaining == 0) return;
    setState(() => _choosing = true);
    final picked = await picker.pickEntries(
      maxNames: single ? 1 : remaining,
      excludeLower: exclude,
      single: single,
    );
    if (!mounted) return;
    setState(() => _choosing = false);
    if (picked.isEmpty) return;
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ContentService.instance,
    builder: (context, _) {
      final content = ContentService.instance;
      final enough = _friends.length >= _minFriends;
      return Scaffold(
        backgroundColor: _primaryBlue,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add your contacts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose at least 4 contacts to start your quiz.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (content.flag('contacts_enabled')) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFromContacts,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    icon: const Icon(Icons.contacts_outlined),
                    label: Text(
                      _choosing ? 'Opening contacts…' : 'Choose from contacts',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickFromContacts(single: true),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.search),
                    label: const Text('Find one contact'),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  enough
                      ? '${_friends.length} contacts selected · Ready to play'
                      : '${_friends.length} / $_minFriends contacts · Add ${_minFriends - _friends.length} more',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_friends.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _friends)
                        InputChip(
                          label: Text(name),
                          onDeleted: _busy
                              ? null
                              : () => setState(() {
                                  _friends.remove(name);
                                  _matches.removeWhere(
                                    (match) => match.displayName == name,
                                  );
                                }),
                        ),
                    ],
                  ),
                ],
                _matchesBanner(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: enough && !_busy ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryBlue,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  child: Text(_saving ? 'Please wait…' : 'Continue'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Only contacts you choose are used. When signed in, selected names and hashed phone numbers are sent to Flyprox to find friends. Your full address book and raw contact numbers are never uploaded. No invitations are sent.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (content.flag('example_names_enabled')) ...[
                  const SizedBox(height: 28),
                  Text(
                    content.text('example_names_description'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _tryExamples,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(content.text('example_names_button')),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
