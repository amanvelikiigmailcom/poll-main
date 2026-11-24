import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flyprox_app/services/contact_picker_service.dart';
import 'fakes/fake_contact_picker_driver.dart';

Contact _c(String? name) => Contact(fullName: name);

void main() {
  group('namesFromContacts', () {
    test('trims, drops empties, dedupes case-insensitively, keeps order', () {
      final names = ContactPickerService.namesFromContacts([
        _c('  Sam '),
        _c(''),
        _c(null),
        _c('sam'),
        _c('Jordan'),
        _c('JORDAN'),
      ]);
      expect(names, ['Sam', 'Jordan']);
    });

    test('respects excludeLower', () {
      final names = ContactPickerService.namesFromContacts(
        [_c('Alex'), _c('Sam')],
        excludeLower: {'alex'},
      );
      expect(names, ['Sam']);
    });
  });

  group('pickNames', () {
    test('multi session maps and caps at maxNames', () async {
      final svc = ContactPickerService.instance
        ..debugDriver(
          FakeContactPickerDriver(
            manyResult: [_c('Sam'), _c('Jordan'), _c('Taylor'), _c('Casey')],
          ),
        );
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 3), ['Sam', 'Jordan', 'Taylor']);
    });

    test(
      'single contact fallback uses single picker once, even on multi-pick iOS',
      () async {
        final fake = FakeContactPickerDriver(
          oneResults: [_c('Found friend'), _c('Other')],
        );
        final svc = ContactPickerService.instance..debugDriver(fake);
        addTearDown(svc.resetDriverForTest);
        final picked = await svc.pickEntries(maxNames: 10, single: true);
        expect(picked.map((c) => c.name), ['Found friend']);
        expect(fake.pickOneCalls, 1);
        expect(fake.pickManyCalls, 0);
      },
    );

    test('cancelled multi session yields empty', () async {
      final svc = ContactPickerService.instance
        ..debugDriver(FakeContactPickerDriver(manyResult: null));
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 4), isEmpty);
    });

    test(
      'own secondary number is excluded before deduping a namesake',
      () async {
        final svc = ContactPickerService.instance
          ..debugDriver(
            FakeContactPickerDriver(
              manyResult: [
                Contact(
                  fullName: 'Alex',
                  phoneNumbers: ['other', 'own-number'],
                ),
                Contact(fullName: 'Alex', phoneNumbers: ['friend-number']),
                Contact(fullName: 'Sam'),
              ],
            ),
          );
        addTearDown(svc.resetDriverForTest);
        final picked = await svc.pickEntries(
          maxNames: 3,
          isOwnPhone: (phone) => phone == 'own-number',
        );
        expect(picked.map((contact) => contact.name), ['Alex', 'Sam']);
        expect(picked.first.phone, 'friend-number');
      },
    );

    test('single sessions loop until maxNames or cancel', () async {
      final fake = FakeContactPickerDriver(
        multiPick: false,
        oneResults: [_c('Sam'), _c('sam'), _c(null), _c('Jordan')],
      );
      final svc = ContactPickerService.instance..debugDriver(fake);
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 2), ['Sam', 'Jordan']);
      expect(fake.pickOneCalls, 4);
      expect(fake.pickManyCalls, 0);
    });

    test('single sessions stop early when the user cancels', () async {
      final svc = ContactPickerService.instance
        ..debugDriver(
          FakeContactPickerDriver(
            multiPick: false,
            oneResults: [_c('Sam'), null],
          ),
        );
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 4), ['Sam']);
    });

    test('never throws when the driver fails', () async {
      final svc = ContactPickerService.instance
        ..debugDriver(ThrowingContactPickerDriver());
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 4), isEmpty);
    });

    test('non-positive maxNames picks nothing', () async {
      final fake = FakeContactPickerDriver(manyResult: [_c('Sam')]);
      final svc = ContactPickerService.instance..debugDriver(fake);
      addTearDown(svc.resetDriverForTest);
      expect(await svc.pickNames(maxNames: 0), isEmpty);
      expect(fake.pickManyCalls, 0);
    });
  });
}
