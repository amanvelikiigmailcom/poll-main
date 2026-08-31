import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/poll_questions.dart';

/// A poll question resolved against the locally-saved friend names,
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

/// Fully local (no backend, no auth) game state: the player's own name,
/// friend-name list, star balance, 40-minute round timer, and generation
/// of each 12-question round from [pollQuestionSeeds].
///
/// Gas-style options: each question shows **4 names** =
/// **your name + 3 classmates** (shuffled).
class LocalGameService {
  LocalGameService._();
  static final LocalGameService instance = LocalGameService._();

  static const _usernameKey = 'local_username';
  static const _playerNameKey = 'local_player_name';
  static const _universityKey = 'local_university';
  static const _universityYearKey = 'local_university_year';
  static const _namesKey = 'local_friend_names';
  static const _starsKey = 'local_star_balance';
  static const _lastRoundKey = 'local_last_round_completed_at';
  static const _usedQuestionIdsKey = 'local_used_question_ids';

  static const int roundLength = 12;
  static const int questionsPerCategory = 4;
  static const int starsPerRound = 1000;
  static const int roundBreakSeconds = 40 * 60;
  /// Always 4 cards: self + 3 others (Gas-style).
  static const int optionsPerQuestion = 4;
  static const int minFriends = 3;
  static const int minUsernameLength = 3;
  static const List<String> _categoryOrder = ['sympathy', 'normal', 'humor'];
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

  final Random _random = Random();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Username / login (required first) ────────────────────────────────────

  Future<String?> getUsername() async {
    final prefs = await _prefs;
    final u = prefs.getString(_usernameKey)?.trim();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  Future<void> saveUsername(String username) async {
    final prefs = await _prefs;
    await prefs.setString(_usernameKey, username.trim());
  }

  /// Local rules only (no backend): latin letters, digits, `_`, min length.
  static String? validateUsername(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'Create username';
    if (v.length < minUsernameLength) {
      return 'At least $minUsernameLength characters';
    }
    if (!usernamePattern.hasMatch(v)) {
      return 'Only letters, numbers and _';
    }
    return null;
  }

  // ── Player name (always included in options) ─────────────────────────────

  Future<String?> getPlayerName() async {
    final prefs = await _prefs;
    final name = prefs.getString(_playerNameKey)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
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
    final yearText =
        (year != null && year >= 1 && year <= 4) ? universityYearLabel(year) : '';
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

  /// Ready to play: login + own name + at least [minFriends] classmates.
  Future<bool> hasEnoughNames() async {
    final username = await getUsername();
    final player = await getPlayerName();
    final friends = await getNames();
    return username != null &&
        username.isNotEmpty &&
        player != null &&
        player.isNotEmpty &&
        friends.length >= minFriends;
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
    await prefs.remove(_usernameKey);
    await prefs.remove(_playerNameKey);
    await prefs.remove(_universityKey);
    await prefs.remove(_universityYearKey);
    await prefs.remove(_namesKey);
    await prefs.remove(_starsKey);
    await prefs.remove(_lastRoundKey);
    await prefs.remove(_usedQuestionIdsKey);
  }

  // ── 40-minute round timer ────────────────────────────────────────────────

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

  Future<void> _markRoundCompletedNow() async {
    final prefs = await _prefs;
    await prefs.setInt(_lastRoundKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Called when a 12-question round finishes: awards the flat 1000 stars
  /// and starts the 40-minute break before the next round unlocks.
  Future<int> completeRound() async {
    await _markRoundCompletedNow();
    return addStars(starsPerRound);
  }

  /// Skips the 40-minute wait (e.g. after "inviting a friend").
  Future<void> bypassTimer() async {
    final prefs = await _prefs;
    await prefs.remove(_lastRoundKey);
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

  List<PollQuestionSeed> _pickForCategory(
    String category,
    Set<String> used,
    int count,
  ) {
    var pool = pollQuestionSeeds
        .where((q) => q.category == category && !used.contains(q.id))
        .toList();
    // Every question in this category has been used already — reset the
    // category's history so it can start recycling instead of repeating
    // the exact same handful every round.
    if (pool.length < count) {
      used.removeWhere(
        (id) =>
            pollQuestionSeeds.any((q) => q.id == id && q.category == category),
      );
      pool = pollQuestionSeeds.where((q) => q.category == category).toList();
    }
    pool.shuffle(_random);
    return pool.take(count).toList();
  }

  /// Gas-style: **your name + 3 random friends**, then shuffle so self is
  /// not always in the same card slot.
  List<String> _buildOptions(String playerName, List<String> friends) {
    final others = List<String>.from(friends)
      ..removeWhere(
        (n) => n.toLowerCase() == playerName.toLowerCase(),
      )
      ..shuffle(_random);

    final othersNeeded = optionsPerQuestion - 1; // 3
    final pickedOthers = others.take(othersNeeded).toList();

    // If fewer than 3 friends, pad is impossible — use what we have.
    final options = <String>[playerName, ...pickedOthers];
    options.shuffle(_random);
    return options;
  }

  /// Builds the next 12-question round: 4 sympathy, then 4 normal, then
  /// 4 humor (sympathy always first). Each question has up to 4 names:
  /// always includes the player + classmates.
  Future<List<GeneratedQuestion>> generateRound({
    String languageCode = 'ru',
  }) async {
    final playerName = await getPlayerName();
    final friends = await getNames();
    final used = await _usedQuestionIds();

    if (playerName == null || playerName.isEmpty || friends.isEmpty) {
      return [];
    }

    final seeds = <PollQuestionSeed>[];
    for (final category in _categoryOrder) {
      seeds.addAll(_pickForCategory(category, used, questionsPerCategory));
    }
    used.addAll(seeds.map((s) => s.id));
    await _saveUsedQuestionIds(used);

    return seeds.map((seed) {
      return GeneratedQuestion(
        id: seed.id,
        question: seed.text(languageCode),
        emoji: seed.emoji,
        category: seed.category,
        optionNames: _buildOptions(playerName, friends),
      );
    }).toList();
  }
}
