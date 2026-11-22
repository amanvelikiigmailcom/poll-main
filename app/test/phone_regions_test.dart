import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/config/phone_regions.dart';

void main() {
  test(
    'all six enabled regions have dialling metadata and US remains default',
    () {
      expect(PhoneRegions.defaultCountry, 'US');
      expect(PhoneRegions.allowed.length, 6);
      final selected = PhoneRegions.countries;
      expect(selected.map((c) => c.code).toSet(), PhoneRegions.allowed);
      for (final c in selected) {
        expect(c.fullCountryCode, isNotEmpty);
      }
      final codes = {for (final c in selected) c.code: c.fullCountryCode};
      expect(codes, {
        'US': '1',
        'GB': '44',
        'CA': '1',
        'NZ': '64',
        'SG': '65',
        'HK': '852',
      });
    },
  );
}
