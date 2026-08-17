import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/local_game_service.dart';
import '../services/user_service.dart';
import 'service_providers.dart';

// ── State ────────────────────────────────────────────────────────────────────

class UserState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  const UserState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  UserState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return UserState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get hasUser => user != null;
  bool get isProfileComplete => user?.isProfileComplete ?? false;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<UserState> {
  final UserService _userService;

  UserNotifier(this._userService)
      : super(UserState(user: _userService.getCachedUser()));

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.getProfile();
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> saveProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.saveProfile(data);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> saveSchool(String schoolId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.saveSchool(schoolId);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> saveClass(int grade, {String? gradeClass}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.saveClass(grade, gradeClass: gradeClass);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> uploadPhoto(String filePath) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.uploadPhoto(filePath);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _userService.updateProfile(data);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  void clearUser() {
    state = const UserState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final userNotifierProvider =
    StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.watch(userServiceProvider));
});

/// Convenience read-only provider for the current [User] (may be null).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(userNotifierProvider).user;
});

// ── Local registration profile (login + display name + university) ───────────

class LocalProfile {
  const LocalProfile({
    this.username = '',
    this.playerName = '',
    this.university = '',
    this.universityYear,
    this.stars = 0,
    this.peopleCount = 0,
    this.isLoaded = false,
  });

  final String username;
  final String playerName;
  final String university;
  final int? universityYear;
  final int stars;
  final int peopleCount;
  final bool isLoaded;

  String get avatarLetter => LocalGameService.avatarLetter(
        displayName: playerName,
        username: username,
      );

  String get universityLine =>
      LocalGameService.universitySubtitle(university, universityYear);
}

class LocalProfileNotifier extends StateNotifier<LocalProfile> {
  LocalProfileNotifier() : super(const LocalProfile()) {
    refresh();
  }

  Future<void> refresh() async {
    final game = LocalGameService.instance;
    final username = await game.getUsername() ?? '';
    final playerName = await game.getPlayerName() ?? '';
    final university = await game.getUniversity() ?? '';
    final universityYear = await game.getUniversityYear();
    final stars = await game.getStars();
    final peopleCount = (await game.getNames()).length;
    state = LocalProfile(
      username: username,
      playerName: playerName,
      university: university,
      universityYear: universityYear,
      stars: stars,
      peopleCount: peopleCount,
      isLoaded: true,
    );
  }

  Future<void> save({
    required String username,
    required String playerName,
    required String university,
    int? universityYear,
  }) async {
    final game = LocalGameService.instance;
    await game.saveUsername(username);
    await game.savePlayerName(playerName);
    await game.saveUniversity(university);
    await game.saveUniversityYear(universityYear);
    await refresh();
  }
}

final localProfileProvider =
    StateNotifierProvider<LocalProfileNotifier, LocalProfile>((ref) {
  return LocalProfileNotifier();
});
