import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useFakeSecureStorage);
  test(
    'old install reviewer flag and reviewer phone never grant a new session skips',
    () async {
      SharedPreferences.setMockInitialValues({
        'reviewer_seen_v1': true,
        'registered_phone': '+16505551234',
      });
      final storage = StorageService();
      await storage.init();
      expect(storage.reviewerSkipsAllowed, isFalse);
      await storage.saveToken('reviewer-session');
      await storage.saveReviewerAccess(true);
      expect(storage.reviewerSkipsAllowed, isTrue);
      await storage.saveToken('ordinary-session');
      await storage.savePhone('+16505550137');
      expect(storage.reviewerSkipsAllowed, isFalse);
      await storage.saveReviewerAccess(false);
      final restored = StorageService();
      await restored.init();
      expect(restored.reviewerSkipsAllowed, isFalse);
      await storage.clearToken();
      expect(storage.reviewerSkipsAllowed, isFalse);
    },
  );
  test(
    'reviewer capability survives restart only for the same authenticated session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveToken('verified-reviewer');
      await storage.saveReviewerAccess(true);
      final restarted = StorageService();
      await restarted.init();
      expect(restarted.reviewerSkipsAllowed, isTrue);
      await restarted.saveToken('new-user');
      expect(restarted.reviewerSkipsAllowed, isFalse);
    },
  );
}
