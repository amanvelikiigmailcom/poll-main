import 'package:intl_phone_field/countries.dart' as intl;

/// Enabled Firebase SMS regions; US remains the default.
abstract final class PhoneRegions {
  static const defaultCountry = 'US';
  static const allowed = {'US', 'GB', 'CA', 'NZ', 'SG', 'HK'};
  static List<intl.Country> get countries => intl.countries
      .where((country) => allowed.contains(country.code))
      .toList();
}
