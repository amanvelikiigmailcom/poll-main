import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/poll_service.dart';
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

final pollServiceProvider = Provider<PollService>((ref) {
  return PollService(ref.watch(apiServiceProvider));
});
