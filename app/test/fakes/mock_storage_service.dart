import 'package:flyprox_app/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

/// Auth persistence always completes; calls remain verifiable by Mocktail.
class MockStorageService extends Mock implements StorageService {
  MockStorageService() {
    var generation = 0;
    when(() => beginAuthentication()).thenAnswer((_) => ++generation);
    when(() => isAuthenticationCurrent(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.single == generation,
    );
    when(
      () => saveAuthenticatedSession(
        any(),
        token: any(named: 'token'),
        phone: any(named: 'phone'),
        reviewerAccess: any(named: 'reviewerAccess'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.positionalArguments.single != generation) return false;
      await saveToken(invocation.namedArguments[#token] as String);
      await saveReviewerAccess(
        invocation.namedArguments[#reviewerAccess] as bool,
      );
      final phone = invocation.namedArguments[#phone] as String?;
      if (phone != null && phone.trim().isNotEmpty) {
        await savePhone(phone.trim());
      }
      return true;
    });
    when(() => saveToken(any())).thenAnswer((_) async {});
    when(() => saveReviewerAccess(any())).thenAnswer((_) async {});
    when(() => savePhone(any())).thenAnswer((_) async {});
  }
}
