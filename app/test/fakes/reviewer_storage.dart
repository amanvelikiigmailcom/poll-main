import 'package:flyprox_app/services/storage_service.dart';

// UI-only fixture. Real session ownership is covered in reviewer_session_test.
class ReviewerStorageService extends StorageService {
  @override
  bool get reviewerSkipsAllowed => true;
}
