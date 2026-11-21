import 'package:flutter_riverpod/flutter_riverpod.dart';
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
