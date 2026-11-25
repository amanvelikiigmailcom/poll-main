import 'package:flyprox_app/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

/// Auth persistence always completes; calls remain verifiable by Mocktail.
class MockStorageService extends Mock implements StorageService {
  MockStorageService() {
    when(() => saveToken(any())).thenAnswer((_) async {});
    when(() => saveReviewerAccess(any())).thenAnswer((_) async {});
    when(() => savePhone(any())).thenAnswer((_) async {});
  }
}
