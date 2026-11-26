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
const int _maxPickedContacts = 50;
const int _maxContacts = 50;

/// Selected contacts only; manual nickname/participant input is retired.
class NamesEntryScreen extends ConsumerStatefulWidget {
  const NamesEntryScreen({super.key});
  @override
  ConsumerState<NamesEntryScreen> createState() => _NamesEntryScreenState();
}

class _NamesEntryScreenState extends ConsumerState<NamesEntryScreen> {
  String _playerName = '';
  final List<String> _friends = [];
  bool _loading = true;
  bool _saving = false;
  bool _choosing = false;
  bool _syncing = false;
  bool _checkingCampus = true;
  String? _campusError;
  List<ContactMatch> _matches = [];
  ({bool school, int joined, int threshold})? _campusMode;
  bool get _busy =>
      _loading ||
      _saving ||
      _choosing ||
      _syncing ||
      _checkingCampus ||
      _campusError != null;

  @override
  void initState() {
    super.initState();
    _checkingCampus = !ref.read(storageServiceProvider).reviewerSkipsAllowed;
    _prefill();
    _loadCampusMode();
  }

  Future<void> _loadCampusMode() async {
    final service = ref.read(onboardingDetailsProvider);
    var leaving = false;
    try {
      final storage = ref.read(storageServiceProvider);
      final details = await service.read();
      final registration =
          !storage.reviewerSkipsAllowed &&
          (await storage.getToken())?.isNotEmpty == true &&
          details['status'] == 'selected' &&
          details['stage'] != 'done';
      final mode = registration
          ? await service.contactsDecision()
          : await service.votingMode();
      if (!mounted || mode == null) return;
      if (mode.school) {
        final stage = (await service.read())['stage'];
        if (!mounted) return;
        if (registration || stage == 'contacts') {
          await service.draft({'stage': 'username'});
          if (mounted) {
            leaving = true;
            context.go(AppRoutes.username);
          }
        } else if (stage == 'done') {
          leaving = true;
          context.go(AppRoutes.home);
        }
      } else {
        setState(() => _campusMode = mode);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _campusError = 'Couldn’t check your campus. Please try again.',
        );
      }
    } finally {
      if (mounted && !leaving) setState(() => _checkingCampus = false);
    }
  }

  Future<void> _prefill() async {
    final game = LocalGameService.instance;
    final existingPlayer = await game.ensurePlayerName();
    final existingFriends = await game.getNames();
    if (!mounted) return;
    setState(() {
      if (existingPlayer.isNotEmpty) {
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
      await LocalGameService.instance.setUsernameSetupPending(true);
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: _playerName,
        friends: List<String>.from(_friends),
      );
      if (!mounted) return;
      await ref.read(localProfileProvider.notifier).refresh();
      if (!mounted) return;
      context.go(AppRoutes.username);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your game. Try again.')),
      );
    }
  }

  Future<void> _tryExamples() async {
    if (_busy ||
        !ref.read(storageServiceProvider).reviewerSkipsAllowed ||
        !ContentService.instance.flag('example_names_enabled')) {
      return;
    }
    setState(() {
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
    if (_busy) return;
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
    final region = _defaultRegion();
    final ownPhone = _savedOwnPhone(region);
    setState(() => _choosing = true);
    final picked = await picker.pickEntries(
      maxNames: single ? 1 : remaining,
      excludeLower: exclude,
      single: single,
      isOwnPhone: ownPhone == null
          ? null
          : (raw) =>
                ContactSyncService.normalizePhone(raw, defaultRegion: region) ==
                ownPhone,
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

  String? _savedOwnPhone(IsoCode region) {
    // A guest or an already saved names-only contact has no verified identity.
    // Never guess by name or read more contacts to try to identify them.
    try {
      final phone = ref.read(storageServiceProvider).getPhone();
      return phone == null
          ? null
          : ContactSyncService.normalizePhone(phone, defaultRegion: region);
    } catch (_) {
      return null;
    }
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
      if (_checkingCampus || _campusError != null) {
        return Scaffold(
          backgroundColor: _primaryBlue,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _checkingCampus
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _campusError!,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _checkingCampus = true;
                                _campusError = null;
                              });
                              _loadCampusMode();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      }
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip:
                        ref.read(storageServiceProvider).reviewerSkipsAllowed
                        ? 'Back to login'
                        : 'Back to campus',
                    onPressed: () => context.go(
                      ref.read(storageServiceProvider).reviewerSkipsAllowed
                          ? AppRoutes.phone
                          : AppRoutes.schoolSetup,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  _campusMode == null
                      ? 'Add your contacts'
                      : 'Play with your contacts for now',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _campusMode == null
                      ? 'Choose at least 4 contacts to start your quiz.'
                      : 'Campus quiz rounds open automatically when ${_campusMode!.threshold} students from your campus join Flyprox. Until then, choose at least 4 contacts to play.',
                  style: const TextStyle(
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
                  'Only contacts you choose are used. Selected names stay on your device. When signed in, hashed phone numbers are sent to Flyprox to find friends. Your full address book and raw contact numbers are never uploaded. No invitations are sent.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (ref.read(storageServiceProvider).reviewerSkipsAllowed &&
                    content.flag('example_names_enabled')) ...[
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
