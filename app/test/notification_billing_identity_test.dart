import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/fake_gateway.dart';

class IdentityGateway extends FakeGateway {
  final identities = <String>[];
  final operations = <String>[];
  @override
  Future<void> identify(String id) async {
    identities.add(id);
    operations.add('identify');
  }

  @override
  Future<void> reset() async {
    operations.add('reset');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'billing uses the backend UUID and resets SDK aliases between accounts before identifying again',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sub = SubscriptionService.instance;
      await sub.resetForTest();
      final gateway = IdentityGateway();
      sub.debugGateway(gateway);
      const a = '00000000-0000-4000-8000-000000000001',
          b = '00000000-0000-4000-8000-000000000002';
      await sub.bindNotificationBillingIdentity(a);
      await sub.initialize();
      expect(gateway.identities.last, a);
      await sub.bindNotificationBillingIdentity(b);
      expect(gateway.identities.last, b);
      expect(gateway.operations, ['identify', 'reset', 'identify']);
      await sub.bindNotificationBillingIdentity(null);
      expect(gateway.identities.last, isNot(anyOf(a, b)));
      expect(gateway.operations.last, 'identify');
      expect(gateway.operations[gateway.operations.length - 2], 'reset');
      await sub.resetForTest();
      await gateway.events.close();
    },
  );
}
