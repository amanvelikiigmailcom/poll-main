import 'package:flutter/services.dart';

/// A storefront is a country suggestion, never evidence of campus eligibility.
abstract final class StorefrontService {
  static const channel = MethodChannel('flyprox/app_info');
  static const countries = {
    'US': 'United States',
    'CA': 'Canada',
    'GB': 'United Kingdom',
    'NZ': 'New Zealand',
    'SG': 'Singapore',
    'HK': 'Hong Kong',
  };
  static const _codes = {
    'USA': 'US',
    'CAN': 'CA',
    'GBR': 'GB',
    'NZL': 'NZ',
    'SGP': 'SG',
    'HKG': 'HK',
  };
  static String? normalize(String? code) =>
      _codes[code?.toUpperCase()] ??
      (countries.containsKey(code?.toUpperCase()) ? code?.toUpperCase() : null);
  static Future<String?> current() async {
    try {
      return await channel
          .invokeMethod<String>('getStorefrontCountry')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }
}
