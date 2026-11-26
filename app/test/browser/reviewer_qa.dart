// Browser acceptance entrypoint only. Production lib/main.dart never imports it.
// Real app/router/API; only native phone/contacts/push handoffs are replaced.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flyprox_app/app.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/phone_auth_driver.dart';
import 'package:flyprox_app/services/contact_picker_driver.dart';
import 'package:flyprox_app/services/contact_picker_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/game_settings.dart';
import '../fakes/fake_push_driver.dart';

const bridge = String.fromEnvironment('API_BASE_URL');

class BrowserPhoneDriver implements PhoneAuthDriver {
  String? _phone;
  @override
  bool get isAvailable => true;
  @override
  Future<CodeSent> sendCode(String phoneNumber) async {
    _phone = phoneNumber;
    return const CodeSent(verificationId: 'browser-native-phone-handoff');
  }

  @override
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final r = await Dio().post<Map<String, dynamic>>(
      '$bridge/qa/firebase-token',
      data: {'phone': _phone, 'code': smsCode},
    );
    return r.data!['idToken'] as String;
  }
}

class BrowserContacts implements ContactPickerDriver {
  @override
  bool get isAvailable => true;
  @override
  bool get supportsMultiPick => true;
  @override
  Future<List<Contact>?> pickMany({int maxNames = 50}) async => [
    for (var i = 0; i < 6; i++)
      Contact(
        fullName: [
          'Alex Contact',
          'Sam Contact',
          'Jordan Contact',
          'Taylor Contact',
          'Morgan Contact',
          'Casey Contact',
        ][i],
        phoneNumbers: ['+1650555008$i'],
      ),
  ];
  @override
  Future<Contact?> pickOne() async => (await pickMany())!.first;
}

Future<void> main() async {
  if (!const bool.fromEnvironment('FLYPROX_BROWSER_QA')) {
    throw StateError('QA build only');
  }
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final storage = StorageService();
  await storage.init();
  await AgeGateService.instance.load();
  await ContentService.instance.load();
  await GameSettings.instance.load();
  ContactPickerService.instance.debugDriver(BrowserContacts());
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        phoneAuthServiceProvider.overrideWith(
          (ref) => PhoneAuthService(
            api: ref.watch(apiServiceProvider),
            storage: storage,
            driver: BrowserPhoneDriver(),
          ),
        ),
        pushServiceProvider.overrideWith(
          (ref) => PushService(
            api: ref.watch(apiServiceProvider),
            driver: FakePushDriver(available: false),
          ),
        ),
      ],
      child: const FlyproxApp(),
    ),
  );
}
