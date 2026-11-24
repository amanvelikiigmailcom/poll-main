/// Launch gate: exactly one open region per school directory country.
///
/// Users who pick a campus outside the open region see the
/// "not available yet" dialog with the support email and cannot continue.
/// Only [openRegions] values may register until launch expands.
abstract final class SchoolLaunch {
  /// Open region server values by country, matching
  /// `school_directory.region` (compared case-insensitively).
  ///
  /// US accepts both CCD full names (`TEXAS`) and PSS 2-letter codes (`TX`).
  /// GB uses `West Midlands`: Birmingham-city rows mostly carry that value.
  /// CA/NZ/SG/HK have no imported rows yet: their values are provisional and
  /// must be re-checked against the source file before the first import.
  static const openRegions = <String, Set<String>>{
    'US': {'TEXAS', 'TX'},
    'GB': {'West Midlands'},
    'CA': {'ONTARIO'},
    'NZ': {'Auckland'},
    'SG': {'Central'},
    'HK': {'Hong Kong Island'},
  };

  /// Display label of the open region for [country]. Null when the country
  /// has no gated region.
  static String? openLabel(String country) {
    switch (country) {
      case 'US':
        return 'Texas';
      case 'GB':
        return 'West Midlands';
      case 'CA':
        return 'Ontario';
      case 'NZ':
        return 'Auckland';
      case 'SG':
        return 'Central Singapore';
      case 'HK':
        return 'Hong Kong Island';
      default:
        return null;
    }
  }

  /// True when [school] may register under its own country's launch gate.
  /// [fallbackCountry] covers rows without a country value.
  /// Unknown countries fail open so a new directory never bricks onboarding.
  static bool isOpen(
    Map<String, dynamic> school, {
    String fallbackCountry = 'US',
  }) {
    final country = school['country'] as String?;
    final allowed = openRegions[country ?? fallbackCountry];
    if (allowed == null) return true;
    final region = (school['region'] as String? ?? '').trim().toLowerCase();
    return allowed.any((value) => value.toLowerCase() == region);
  }

  /// "Not available yet" dialog body naming the open region and support email.
  static String closedMessage({
    required String country,
    required String schoolName,
    required String email,
  }) {
    final label = openLabel(country);
    final scope = label == null ? '' : ' We’re currently open in $label only.';
    return 'Sorry, $schoolName isn’t open for registration yet.$scope\n\n'
        'You can write to our support team at $email and we’ll let you know when your campus opens.';
  }
}
