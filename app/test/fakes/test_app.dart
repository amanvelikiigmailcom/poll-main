import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fake_secure_storage.dart';

late GoRouter testAppRouter;

/// Register with setUp: no navigation state or native storage crosses tests.
void setUpTestApp() {
  useFakeSecureStorage();
  testAppRouter = createAppRouter();
  addTearDown(testAppRouter.dispose);
}
