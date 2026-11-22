import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/contact_picker_driver_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const modern = MethodChannel('flyprox/contact_access');
  const legacy = MethodChannel('flutter_native_contact_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(modern, null);
    messenger.setMockMethodCallHandler(legacy, null);
  });

  test('iOS uses modern contact access with a bounded selection', () async {
    messenger.setMockMethodCallHandler(modern, (call) async {
      expect(call.method, 'pickContacts');
      expect(call.arguments, {'limit': 50});
      return [
        {
          'fullName': 'Selected friend',
          'phoneNumbers': ['+16505551234'],
        },
      ];
    });
    messenger.setMockMethodCallHandler(
      legacy,
      (_) async => fail('Legacy picker must not open'),
    );
    final result = await NativeContactPickerDriver(isIOS: true).pickMany();
    expect(result?.single.fullName, 'Selected friend');
    expect(result?.single.phoneNumbers, ['+16505551234']);
  });

  test('modern cancellation never reopens the legacy picker', () async {
    messenger.setMockMethodCallHandler(modern, (_) async => []);
    messenger.setMockMethodCallHandler(
      legacy,
      (_) async => fail('Cancelled selection must stay cancelled'),
    );
    expect(await NativeContactPickerDriver(isIOS: true).pickMany(), isEmpty);
  });

  test(
    'only unsupported iOS falls back to the legacy one-time picker',
    () async {
      messenger.setMockMethodCallHandler(
        modern,
        (_) async => throw PlatformException(code: 'unsupported_ios'),
      );
      messenger.setMockMethodCallHandler(legacy, (call) async {
        expect(call.method, 'selectContact');
        return {'fullName': 'Older iPhone', 'phoneNumbers': <String>[]};
      });
      expect(
        (await NativeContactPickerDriver(isIOS: true).pickOne())?.fullName,
        'Older iPhone',
      );
    },
  );

  test(
    'permission errors never silently switch to a different access model',
    () async {
      messenger.setMockMethodCallHandler(
        modern,
        (_) async => throw PlatformException(code: 'contacts_unavailable'),
      );
      messenger.setMockMethodCallHandler(
        legacy,
        (_) async => fail('Denied access must not open another picker'),
      );
      expect(
        NativeContactPickerDriver(isIOS: true).pickMany(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test(
    'remaining capacity reaches the native picker instead of an old ten-contact cap',
    () async {
      messenger.setMockMethodCallHandler(modern, (call) async {
        expect(call.arguments, {'limit': 4});
        return List.generate(
          4,
          (i) => {'fullName': 'Remaining $i', 'phoneNumbers': <String>[]},
        );
      });
      final result = await NativeContactPickerDriver(
        isIOS: true,
      ).pickMany(maxNames: 4);
      expect(result?.map((c) => c.fullName).toList(), [
        'Remaining 0',
        'Remaining 1',
        'Remaining 2',
        'Remaining 3',
      ]);
    },
  );

  test(
    'single contact mode still requests exactly one native selection',
    () async {
      messenger.setMockMethodCallHandler(modern, (call) async {
        expect(call.arguments, {'limit': 1});
        return [
          {'fullName': 'One person', 'phoneNumbers': <String>[]},
        ];
      });
      expect(
        (await NativeContactPickerDriver(isIOS: true).pickOne())?.fullName,
        'One person',
      );
    },
  );

  test(
    'native selection never exceeds the server fifty-contact capacity',
    () async {
      messenger.setMockMethodCallHandler(modern, (call) async {
        expect(call.arguments, {'limit': 50});
        return List.generate(
          50,
          (i) => {'fullName': 'Friend $i', 'phoneNumbers': <String>[]},
        );
      });
      final result = await NativeContactPickerDriver(
        isIOS: true,
      ).pickMany(maxNames: 200);
      expect(result, hasLength(50));
    },
  );
}
