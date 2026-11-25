import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/billing_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final method in ['identify', 'reset']) {
    test('real gateway propagates native $method failure', () async {
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.superwallkit_flutter.PSuperwallHostApi.$method',
        const StandardMessageCodec(),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler<Object?>(
        channel,
        (_) async => <Object?>[
          'identity_failure',
          'Native identity change failed',
          null,
        ],
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
      );
      final gateway = SuperwallGateway();
      await expectLater(
        method == 'identify' ? gateway.identify('account-b') : gateway.reset(),
        throwsA(isA<PlatformException>()),
      );
    });
  }
}
