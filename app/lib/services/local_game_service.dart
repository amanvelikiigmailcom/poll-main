import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/intro_questions.dart';
import 'question_bank_service.dart';
import '../data/quiz_questions.dart';

/// A quiz question resolved against the locally-saved friend names,
/// ready to hand to the vote screens.
class GeneratedQuestion {
  final String id;
  final String question;
  final String emoji;
  final String category; // sympathy | normal | humor
  final List<String> optionNames;

  const GeneratedQuestion({
    required this.id,
    required this.question,
    required this.emoji,
    required this.category,
    required this.optionNames,
  });
}

/// Saved mid-round position: which round was in progress (as a count of
/// completed rounds), the current question index, and the round's question
/// ids in play order.
class RoundProgress {
  final int round;
  final int questionIndex;
  final List<String> questionIds;
  final List<RoundAnswer>? draftAnswers;
  final Map<String, dynamic>? draft;

  const RoundProgress({
    required this.round,
    required this.questionIndex,
    required this.questionIds,
    this.draftAnswers,
    this.draft,
  });
}

/// One choice made on this device; a null choice represents a skip.
class RoundAnswer {
  const RoundAnswer({
    required this.questionId,
    required this.question,
    required this.voter,
    this.choice,
    this.optionId,
  });
  final String questionId;
  final String question;
  final String voter;
  final String? choice;
  final String? optionId;
  Map<String, dynamic> toJson() => {
    'id': questionId,
    'question': question,
    'voter': voter,
    'choice': choice,
    if (optionId != null) 'optionId': optionId,
  };
  factory RoundAnswer.fromJson(Map<String, dynamic> json) => RoundAnswer(
    questionId: json['id'] as String,
    question: json['question'] as String,
    voter: json['voter'] as String,
    choice: json['choice'] as String?,
    optionId: json['optionId'] as String?,
  );
}

/// Fully local (no backend, no auth) game state: the player's own name,
/// friend-name list, star balance, 60-minute round timer, and generation
/// of each 12-question round from [quizQuestionSeeds].
///
/// Each question shows up to four selected contacts, shuffled.
/// The player profile is never inserted as a voting option.
class LocalGameService {
  LocalGameService._();
  static final LocalGameService instance = LocalGameService._();

  static const _usernameKey = 'local_username';
  static const _usernameSetupPendingKey = 'local_username_setup_pending_v1';
  static const _playerNameKey = 'local_player_name';
  static const _universityKey = 'local_university';
  static const _universityYearKey = 'local_university_year';
  static const _namesKey = 'local_friend_names';
  static const _starsKey = 'local_star_balance';
  static const _lastRoundKey = 'local_last_round_completed_at';
  static const _usedQuestionIdsKey = 'local_used_question_ids';
  static const _completedRoundsKey = 'local_rounds_completed';
  static const _roundProgressKey = 'local_round_progress';

  static const int roundLength = 12;
  static const int questionsPerCategory = 4;

  /// First [introRounds] rounds play the fixed neutral intro
  /// ([introQuestionSeeds]); later rounds use the full pool.
  static const int introRounds = 2;
  static const int starsPerRound = 1000;
  static const int roundBreakSeconds = 60 * 60;

  /// Up to four cards, drawn only from selected contacts.
  static const int optionsPerQuestion = 4;
  static const int minFriends = 4;
  static const int minUsernameLength = 3;
  static const List<String> _categoryOrder = ['sympathy', 'normal', 'humor'];
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

  final Random _random = Random();
  bool _finishingDraft = false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static const _answersKey = 'local_round_answers';
  static const _lastAnswersKey = 'local_last_round_answers';
  static const _avatarKey = 'local_avatar';

  static const _scopeKey = 'local_game_scope_owner_v1';
  static const _scopedKeys = [
    _usernameKey,
    _usernameSetupPendingKey,
    _playerNameKey,
    _universityKey,
    _universityYearKey,
    _namesKey,
    _starsKey,
    _lastRoundKey,
    _usedQuestionIdsKey,
    _completedRoundsKey,
    _roundProgressKey,
    _answersKey,
    _lastAnswersKey,
    _avatarKey,
    'local_first_name_v1',
    'local_last_name_v1',
    'contact_labels_by_hash_v1',
  ];

  /// Keep drafts, participants and timers with their backend account, not device.
  /// Unowned legacy data is archived, never assigned to a newly signed-in user.
  Future<void> activateAccount(String accountId, {String? legacyOwner}) async {
    final prefs = await _prefs;
    final prior = prefs.getString(_scopeKey);
    if (prior == accountId) return;
    final owner =
        prior ??
        legacyOwner ??
        (await loadRoundProgress())?.draft?['ownerId'] as String? ??
        'legacy';
    final saved = <String, dynamic>{
      for (final key in _scopedKeys)
        if (prefs.containsKey(key)) key: prefs.get(key),
    };
    await prefs.setString('local_game_account_v1_$owner', jsonEncode(saved));
    final raw = prefs.getString('local_game_account_v1_$accountId');
    final restored = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    for (final key in _scopedKeys) {
      final value = restored[key];
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
      } else {
        await prefs.remove(key);
      }
    }
    await prefs.setString(_scopeKey, accountId);
  }

  Future<List<RoundAnswer>> getRoundAnswers({bool completed = false}) async {
    if (!completed) {
      final draft = (await loadRoundProgress())?.draftAnswers;
      if (draft != null) return draft;
    }
    final raw = (await _prefs).getString(
      completed ? _lastAnswersKey : _answersKey,
    );
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => RoundAnswer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> beginRoundAnswers() async => (await _prefs).remove(_answersKey);

  Future<void> recordAnswer(RoundAnswer answer) async {
    final answers = await getRoundAnswers();
    final index = answers.indexWhere((a) => a.questionId == answer.questionId);
    if (index < 0) {
      answers.add(answer);
    } else {
      answers[index] = answer;
    }
    await (await _prefs).setString(
      _answersKey,
      jsonEncode(answers.map((a) => a.toJson()).toList()),
    );
  }

  Future<String> exportLocalData() async =>
      const JsonEncoder.withIndent('  ').convert({
        'nickname': await getPlayerName(),
        'handle': await getUsername(),
        'participantNames': await getNames(),
        'university': await getUniversity(),
        'universityYear': await getUniversityYear(),
        'stars': await getStars(),
        'completedRounds': await getCompletedRounds(),
        'currentRound': (await getRoundAnswers())
            .map((a) => a.toJson())
            .toList(),
        'lastRound': (await getRoundAnswers(
          completed: true,
        )).map((a) => a.toJson()).toList(),
      });

  /// Remove only the retired app-owned Base64 avatar, never gallery originals.
  Future<void> removeLegacyAvatar() async {
    final prefs = await _prefs;
    if (prefs.containsKey(_avatarKey)) await prefs.remove(_avatarKey);
  }

  // ── Optional local profile handle ────────────────────────────────────

  Future<String?> getUsername() async {
    final prefs = await _prefs;
    final u = prefs.getString(_usernameKey)?.trim();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  /// Names and handles are separate: a full name must never prefill @username.
  Future<String> ensureUsername() async {
    final existing = await getUsername();
    if (existing != null) return existing;
    final player = await getPlayerName();
    final handle = player != null && validateUsername(player) == null
        ? player
        : 'user${100000 + _random.nextInt(900000)}';
    await saveUsername(handle);
    return handle;
  }

  Future<void> saveUsername(String username) async {
    final prefs = await _prefs;
    await prefs.setString(_usernameKey, username.trim());
  }

  /// Local rules only (no backend): latin letters, digits, `_`, min length.
  static String? validateUsername(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'Enter a username';
    if (v.length > 32) return 'Use 32 characters or fewer';
    if (v.length < minUsernameLength) {
      return 'At least $minUsernameLength characters';
    }
    if (!usernamePattern.hasMatch(v)) {
      return 'Use A–Z, numbers or _';
    }
    return null;
  }

  // ── Player profile name (never inserted into voting options) ─────────────────────────────

  Future<String?> getPlayerName() async {
    final prefs = await _prefs;
    final name = prefs.getString(_playerNameKey)?.trim();
    if (name == null || name.isEmpty) return null;
    // Retire the old automatic example/self labels for existing installations.
    if ((name == 'Michael' || name == 'You') &&
        prefs.getString(_usernameKey) != name) {
      return _saveGeneratedPlayerName();
    }
    return name;
  }

  Future<String> ensurePlayerName() async =>
      await getPlayerName() ?? await _saveGeneratedPlayerName();

  Future<String> _saveGeneratedPlayerName() async {
    final name = 'user${100000 + _random.nextInt(900000)}';
    await savePlayerName(name);
    return name;
  }

  Future<bool> isUsernameSetupPending() async =>
      (await _prefs).getBool(_usernameSetupPendingKey) ?? false;

  Future<void> setUsernameSetupPending(bool pending) async {
    await (await _prefs).setBool(_usernameSetupPendingKey, pending);
  }

  Future<void> savePlayerName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_playerNameKey, name.trim());
  }

  // ── University / year (typed by the user; not school/class) ───────────────

  Future<String?> getUniversity() async {
    final prefs = await _prefs;
    final v = prefs.getString(_universityKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> saveUniversity(String university) async {
    final prefs = await _prefs;
    final v = university.trim();
    if (v.isEmpty) {
      await prefs.remove(_universityKey);
    } else {
      await prefs.setString(_universityKey, v);
    }
  }

  /// 1–4, or null if the user has not picked a year.
  Future<int?> getUniversityYear() async {
    final prefs = await _prefs;
    final y = prefs.getInt(_universityYearKey);
    if (y == null || y < 1 || y > 4) return null;
    return y;
  }

  Future<void> saveUniversityYear(int? year) async {
    final prefs = await _prefs;
    if (year == null || year < 1 || year > 4) {
      await prefs.remove(_universityYearKey);
    } else {
      await prefs.setInt(_universityYearKey, year);
    }
  }

  /// English ordinal label for a persisted year (1–4).
  static String universityYearLabel(int year) {
    switch (year) {
      case 1:
        return '1st year';
      case 2:
        return '2nd year';
      case 3:
        return '3rd year';
      case 4:
        return '4th year';
      default:
        return '';
    }
  }

  /// Header line: "University name · 2nd year", or empty if neither is set.
  static String universitySubtitle(String? university, int? year) {
    final uni = university?.trim() ?? '';
    final yearText = (year != null && year >= 1 && year <= 4)
        ? universityYearLabel(year)
        : '';
    if (uni.isNotEmpty && yearText.isNotEmpty) return '$uni · $yearText';
    if (uni.isNotEmpty) return uni;
    return yearText;
  }

  /// Round avatar letter: first letter of display name, else login, else "?".
  static String avatarLetter({String? displayName, String? username}) {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name[0].toUpperCase();
    final login = username?.trim() ?? '';
    if (login.isNotEmpty) return login[0].toUpperCase();
    return '?';
  }

  // ── Friend names ──────────────────────────────────────────────────────────

  Future<List<String>> getNames() async {
    final prefs = await _prefs;
    return prefs.getStringList(_namesKey) ?? [];
  }

  Future<void> saveNames(List<String> names) async {
    final prefs = await _prefs;
    await prefs.setStringList(_namesKey, names);
  }

  /// Ready to play: a display name and at least [minFriends] participants.
  Future<bool> hasEnoughNames() async {
    final player = await getPlayerName();
    final friends = await getNames();
    return player != null && player.isNotEmpty && friends.length >= minFriends;
  }

  Future<void> savePlayerAndFriends({
    required String playerName,
    required List<String> friends,
    String? username,
  }) async {
    if (username != null && username.trim().isNotEmpty) {
      await saveUsername(username);
    }
    await savePlayerName(playerName);
    await saveNames(friends);
  }

  // ── Stars ─────────────────────────────────────────────────────────────────

  Future<int> getStars() async {
    final prefs = await _prefs;
    return prefs.getInt(_starsKey) ?? 0;
  }

  Future<int> addStars(int amount) async {
    final prefs = await _prefs;
    final next = (await getStars()) + amount;
    await prefs.setInt(_starsKey, next);
    return next;
  }

  /// Wipe every local quiz field. There is no server account in this build.
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_answersKey);
    await prefs.remove(_lastAnswersKey);
    await prefs.remove(_avatarKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_usernameSetupPendingKey);
    await prefs.remove(_playerNameKey);
    await prefs.remove('local_first_name_v1');
    await prefs.remove('local_last_name_v1');
    await prefs.remove(_universityKey);
    await prefs.remove(_universityYearKey);
    await prefs.remove(_namesKey);
    await prefs.remove(_starsKey);
    await prefs.remove(_lastRoundKey);
    await prefs.remove(_usedQuestionIdsKey);
    await prefs.remove(_completedRoundsKey);
    await prefs.remove(_roundProgressKey);
  }

  // ── 60-minute round timer ────────────────────────────────────────────────

  Future<int> secondsUntilNextRound() async {
    final prefs = await _prefs;
    final lastMillis = prefs.getInt(_lastRoundKey);
    if (lastMillis == null) return 0;
    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMillis))
        .inSeconds;
    final remaining = roundBreakSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Future<String?> cooldownKey() async =>
      (await _prefs).getInt(_lastRoundKey)?.toString();

  /// A late server response must never clear a newer round's waiting period.
  Future<void> bypassTimerFor(String key) async {
    if (await cooldownKey() == key) await bypassTimer();
  }

  Future<(String, String)> getFullName() async {
    final prefs = await _prefs;
    return (
      prefs.getString('local_first_name_v1') ?? '',
      prefs.getString('local_last_name_v1') ?? '',
    );
  }

  Future<void> saveFullName(String first, String last) async {
    final prefs = await _prefs;
    await prefs.setString('local_first_name_v1', first.trim());
    await prefs.setString('local_last_name_v1', last.trim());
    await savePlayerName('${first.trim()} ${last.trim()}');
  }

  static String? validateProfileName(String value, String label) {
    final name = value.trim();
    if (name.isEmpty) return 'Enter your $label';
    if (name.length > 64) return 'Use 64 characters or fewer for your $label';
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      return 'Enter your $label without line breaks or tabs';
    }
    return null;
  }

  Future<void> _markRoundCompletedNow() async {
    final prefs = await _prefs;
    await prefs.setInt(_lastRoundKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Called when a 12-question round finishes: awards the flat 1000 stars,
  /// saves the latest reveal, counts the round, clears mid-round progress and
  /// starts the 60-minute break before the next round unlocks.
  Future<int> completeRound({
    bool bonus = false,
    bool awardStars = true,
  }) async {
    final answers = await getRoundAnswers();
    await (await _prefs).setString(
      _lastAnswersKey,
      jsonEncode(answers.map((a) => a.toJson()).toList()),
    );
    await beginRoundAnswers();
    await _markRoundCompletedNow();
    final prefs = await _prefs;
    final done = await getCompletedRounds();
    await prefs.setInt(_completedRoundsKey, done + 1);
    await _clearRoundProgress();
    return awardStars
        ? addStars(bonus ? starsPerRound * 2 : starsPerRound)
        : getStars();
  }

  Future<void> finishRoundDraft(
    int round, {
    required bool bonus,
    bool awardStars = true,
  }) async {
    if (_finishingDraft) {
      throw StateError('Round completion already in progress');
    }
    _finishingDraft = true;
    try {
      final completed = await getCompletedRounds();
      if (completed == round + 1) return;
      final progress = await loadRoundProgress();
      if (completed != round ||
          progress?.round != round ||
          progress?.draft?['sealed'] != true ||
          progress?.draftAnswers?.length != roundLength) {
        throw StateError('Round draft is no longer active');
      }
      await completeRound(bonus: bonus, awardStars: awardStars);
    } finally {
      _finishingDraft = false;
    }
  }

  Future<void> discardRoundDraft() async {
    await beginRoundAnswers();
    await _clearRoundProgress();
  }

  /// Skips the 60-minute wait (e.g. after "inviting a friend").
  Future<void> bypassTimer() async {
    final prefs = await _prefs;
    await prefs.remove(_lastRoundKey);
  }

  // ── Completed rounds + mid-round progress ──────────────────────────────

  /// How many full 12-question rounds were completed on this device.
  /// Drives the intro flow: rounds below [introRounds] play the fixed
  /// neutral intro; the counter survives app restarts and is cleared
  /// together with the other game records by [clearAll].
  Future<int> getCompletedRounds() async {
    final prefs = await _prefs;
    final n = prefs.getInt(_completedRoundsKey);
    if (n == null || n < 0) return 0;
    return n;
  }

  /// Remembers where the player stopped inside the current intro round so
  /// an app restart resumes the same round instead of returning to its
  /// start. All rounds use this so saved choices stay attached to their round.
  Future<void> saveRoundProgress({
    required int round,
    required int questionIndex,
    required List<String> questionIds,
    List<RoundAnswer>? draftAnswers,
    Map<String, dynamic>? draft,
  }) async {
    final prefs = await _prefs;
    final saved = await prefs.setString(
      _roundProgressKey,
      jsonEncode({
        'round': round,
        'index': questionIndex,
        'ids': questionIds,
        if (draftAnswers != null)
          'answers': draftAnswers.map((a) => a.toJson()).toList(),
        if (draft != null) 'draft': draft,
      }),
    );
    if (!saved) throw StateError('Could not save round progress');
  }

  Future<RoundProgress?> loadRoundProgress() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_roundProgressKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final round = map['round'] as int;
      final index = map['index'] as int;
      final ids = (map['ids'] as List<dynamic>).cast<String>().toList();
      if (round < 0 || index < 0 || ids.isEmpty) return null;
      return RoundProgress(
        round: round,
        questionIndex: index,
        questionIds: ids,
        draftAnswers: (map['answers'] as List?)
            ?.map((a) => RoundAnswer.fromJson(a as Map<String, dynamic>))
            .toList(),
        draft: map['draft'] as Map<String, dynamic>?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearRoundProgress() async {
    final prefs = await _prefs;
    await prefs.remove(_roundProgressKey);
  }

  List<QuizQuestionSeed> get _mainBank {
    final remote = QuestionBankService.instance.seeds(intro: false);
    return remote.isNotEmpty ? remote : quizQuestionSeeds;
  }

  List<QuizQuestionSeed> get _introBank {
    final remote = QuestionBankService.instance.seeds(intro: true);
    return QuestionBankService.instance.seeds(intro: false).isNotEmpty
        ? remote
        : introQuestionSeeds;
  }

  /// Build cards from selected local names, including unmatched contacts.
  Future<List<String>> selectedOptions() async =>
      _buildOptions(await getNames());

  QuizQuestionSeed? _seedById(String id) {
    for (final seed in _introBank) {
      if (seed.id == id) return seed;
    }
    for (final seed in _mainBank) {
      if (seed.id == id) return seed;
    }
    return null;
  }

  /// Rebuilds the questions for previously saved [ids] (mid-round resume).
  /// Returns null when the setup is gone or any id is unknown, so the
  /// caller generates a fresh round instead.
  Future<List<GeneratedQuestion>?> restoreRound({
    required List<String> ids,
    String languageCode = 'ru',
  }) async {
    final playerName = await getPlayerName();
    final friends = await getNames();
    if (playerName == null || playerName.isEmpty || friends.isEmpty) {
      return null;
    }
    final seeds = <QuizQuestionSeed>[];
    for (final id in ids) {
      final seed = _seedById(id);
      if (seed == null) return null;
      seeds.add(seed);
    }
    return seeds.map((s) => _toGenerated(s, friends, languageCode)).toList();
  }

  // ── Round generation ─────────────────────────────────────────────────────

  Future<Set<String>> _usedQuestionIds() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_usedQuestionIdsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveUsedQuestionIds(Set<String> ids) async {
    final prefs = await _prefs;
    await prefs.setString(_usedQuestionIdsKey, jsonEncode(ids.toList()));
  }

  List<QuizQuestionSeed> _pickForCategory(
    String category,
    Set<String> used,
    int count,
  ) {
    var pool = _mainBank
        .where((q) => q.category == category && !used.contains(q.id))
        .toList();
    // Every question in this category has been used already — reset the
    // category's history so it can start recycling instead of repeating
    // the exact same handful every round.
    if (pool.length < count) {
      final categoryIds = _mainBank
          .where((q) => q.category == category)
          .map((q) => q.id)
          .toSet();
      used.removeWhere(categoryIds.contains);
      pool = _mainBank.where((q) => q.category == category).toList();
    }
    pool.shuffle(_random);
    return pool.take(count).toList();
  }

  /// Only selected contacts can appear; never add the voter's own profile.
  List<String> _buildOptions(List<String> friends) {
    final contacts = List<String>.from(friends)..shuffle(_random);
    return contacts.take(optionsPerQuestion).toList();
  }

  GeneratedQuestion _toGenerated(
    QuizQuestionSeed seed,
    List<String> friends,
    String languageCode,
  ) {
    return GeneratedQuestion(
      id: seed.id,
      question: seed.text(languageCode),
      emoji: seed.emoji,
      category: seed.category,
      optionNames: _buildOptions(friends),
    );
  }

  /// Builds the next 12-question round.
  ///
  /// Rounds 1–2 ([introRounds]) play the fixed neutral intro from
  /// [introQuestionSeeds] in order. Round 3+ keeps the previous behavior:
  /// 4 sympathy, then 4 normal, then 4 humor (sympathy always first),
  /// picked at random excluding already-used pool questions.
  /// Each question has up to four selected contacts; no player card.
  Future<List<GeneratedQuestion>> generateRound({
    String languageCode = 'ru',
  }) async {
    final playerName = await getPlayerName();
    final friends = await getNames();

    if (playerName == null || playerName.isEmpty || friends.isEmpty) {
      return [];
    }

    final completed = await getCompletedRounds();
    if (completed < introRounds) {
      final seeds = _introBank
          .skip(completed * roundLength)
          .take(roundLength)
          .toList();
      if (seeds.length == roundLength) {
        return seeds
            .map((s) => _toGenerated(s, friends, languageCode))
            .toList();
      }
      // Truncated intro data — fall through to the pool instead of
      // stranding the player on an empty round.
    }

    final used = await _usedQuestionIds();
    final seeds = <QuizQuestionSeed>[];
    for (final category in _categoryOrder) {
      seeds.addAll(_pickForCategory(category, used, questionsPerCategory));
    }
    used.addAll(seeds.map((s) => s.id));
    await _saveUsedQuestionIds(used);

    return seeds.map((s) => _toGenerated(s, friends, languageCode)).toList();
  }
}
