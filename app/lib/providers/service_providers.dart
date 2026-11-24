import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_balance_service.dart';
import '../services/local_game_service.dart';
import '../services/notification_preferences_service.dart';
import '../services/activity_service.dart';
import '../services/onboarding_details_service.dart';
import '../services/social_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/contact_sync_service.dart';
import '../services/phone_auth_driver_firebase.dart';
import '../services/phone_auth_service.dart';
import '../services/push_driver_firebase.dart';
import '../services/push_service.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../services/invitation_service.dart';

/// Single [StorageService] instance shared across the app.
/// Must be overridden in [ProviderScope] after [StorageService.init()] is called.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be overridden in ProviderScope. '
    'Call StorageService.init() and provide the instance before app start.',
  );
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(storageServiceProvider));
});

final invitationServiceProvider = ChangeNotifierProvider<InvitationService>((
  ref,
) {
  return InvitationService(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final quizServiceProvider = Provider<QuizService>((ref) {
  return QuizService(ref.watch(apiServiceProvider));
});

final phoneAuthServiceProvider = Provider<PhoneAuthService>((ref) {
  return PhoneAuthService(
    api: ref.watch(apiServiceProvider),
    storage: ref.watch(storageServiceProvider),
    driver: FirebasePhoneAuthDriver(),
  );
});

final contactSyncServiceProvider = Provider<ContactSyncService>((ref) {
  return ContactSyncService(ref.watch(apiServiceProvider));
});

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    driver: FirebasePushDriver(),
    api: ref.watch(apiServiceProvider),
  );
});

final socialServiceProvider = Provider<SocialService>(
  (ref) => SocialService(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);

/// Server counts are never substituted with local participant counts.
final socialSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) async {
    final storage = ref.watch(storageServiceProvider);
    void changed() => ref.invalidateSelf();
    storage.addListener(changed);
    ref.onDispose(() => storage.removeListener(changed));
    if ((await storage.getToken())?.isNotEmpty != true) return null;
    return ref.watch(socialServiceProvider).request('/summary');
  },
);

final onboardingDetailsProvider =
    ChangeNotifierProvider<OnboardingDetailsService>(
      (ref) => OnboardingDetailsService(
        ref.watch(apiServiceProvider),
        ref.watch(storageServiceProvider),
      ),
    );

final notificationPreferencesProvider =
    ChangeNotifierProvider<NotificationPreferencesService>(
      (ref) => NotificationPreferencesService(
        ref.watch(apiServiceProvider),
        ref.watch(storageServiceProvider),
      ),
    );

final activityServiceProvider = Provider<ActivityService>(
  (ref) => ActivityService(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);


final starBalanceProvider = FutureProvider.autoDispose<int?>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  void changed() => ref.invalidateSelf();
  storage.addListener(changed);
  ref.onDispose(() => storage.removeListener(changed));
  final api = ref.watch(apiServiceProvider);
  String key(String token) => 'verified_stars_v1_${sha256.convert(utf8.encode(token))}';
  return AccountBalanceService(
    readToken: storage.getToken,
    fetchBalance: (token) async => (await api.get<Map<String,dynamic>>(
      '/api/users/profile', options: Options(headers: {'Authorization':'Bearer $token'}),
    )).data?['starsCount'],
    readCached: (token) async => (await SharedPreferences.getInstance()).getInt(key(token)),
    writeCached: (token, value) async { await (await SharedPreferences.getInstance()).setInt(key(token),value); },
    guestBalance: LocalGameService.instance.getStars,
  ).load();
});
