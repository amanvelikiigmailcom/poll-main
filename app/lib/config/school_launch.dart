/// Launch gate: exactly one open region per school directory country.
///
/// Users who pick a campus outside the open region see the
/// "not available yet" dialog with the support email and cannot continue.
/// Only [openRegions] values and [testSchoolIds]/[testSchools] may register
/// until launch expands.
library;

import 'package:flutter/material.dart';

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

  /// Team test campuses, always open in every country group.
  /// Directory row ids (`US-CCD-<extId>` / `US-PSS-<extId>`).
  static const testSchoolIds = <String>{
    // New Horizon Alternative School, Bessemer AL.
    'US-CCD-010033001264',
  };

  /// Name-based fallback so a test campus survives directory re-imports
  /// (row ids change, the source name/state do not).
  static const testSchools = <({String name, String country, Set<String> regions})>[
    (
      name: 'New Horizon Alternative School',
      country: 'US',
      regions: {'ALABAMA', 'AL'},
    ),
  ];

  /// True when [school] is a team test campus (see [testSchoolIds]).
  static bool isTestSchool(Map<String, dynamic> school) {
    if (testSchoolIds.contains(school['id'])) return true;
    final name = (school['name'] as String? ?? '').trim().toLowerCase();
    final country = school['country'] as String?;
    final region = (school['region'] as String? ?? '').trim().toLowerCase();
    return testSchools.any(
      (test) =>
          test.name.toLowerCase() == name &&
          test.country == country &&
          test.regions.any((value) => value.toLowerCase() == region),
    );
  }

  /// True when [school] may register under its own country's launch gate.
  /// [fallbackCountry] covers rows without a country value.
  /// Unknown countries fail open so a new directory never bricks onboarding.
  static bool isOpen(
    Map<String, dynamic> school, {
    String fallbackCountry = 'US',
  }) {
    if (isTestSchool(school)) return true;
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

  /// Shows the shared "not available yet" dialog for [schoolName].
  static Future<void> showUnavailableDialog(
    BuildContext context, {
    required String country,
    required String schoolName,
    required String email,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Campus not available yet'),
        content: Text(
          closedMessage(
            country: country,
            schoolName: schoolName,
            email: email,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
