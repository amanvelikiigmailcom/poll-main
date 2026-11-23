import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/screens/premium/age_blocked_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';

class MockApiService extends Mock implements ApiService {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data) => Response(
  data: data,
  requestOptions: RequestOptions(path: '/api/content'),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
  });

  tearDown(() => ContentService.instance.debugClear());

  test('defaults retain required product settings and non-empty values', () {
    expect(
      ContentService.defaults.keys,
      containsAll([
        'guest_enabled',
        'contacts_enabled',
        'example_names_enabled',
        'paywall_features_v2',
        'paywall_term',
        'paywall_cta',
        'url_privacy',
        'url_terms',
        'url_support',
      ]),
    );
    for (final entry in ContentService.defaults.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
    }
  });

  test('text returns default, override wins, empty override ignored', () {
    final content = ContentService.instance;
    expect(content.text('paywall_title'), 'Premium');
    content.debugSetOverrides({'paywall_title': 'VIP'});
    expect(content.text('paywall_title'), 'VIP');
    content.debugSetOverrides({'paywall_title': ''});
    expect(content.text('paywall_title'), 'Premium');
    expect(content.text('missing_key'), '');
  });

  test('flag parses booleans and defaults to enabled', () {
    final content = ContentService.instance;
    expect(content.flag('guest_enabled'), isTrue);
    for (final value in ['false', '0', 'no', 'off', ' False ']) {
      content.debugSetOverrides({'guest_enabled': value});
      expect(content.flag('guest_enabled'), isFalse, reason: value);
    }
    content.debugSetOverrides({'guest_enabled': 'yes'});
    expect(content.flag('guest_enabled'), isTrue);
  });

  test('template replaces placeholders', () {
    final content = ContentService.instance;
    expect(
      content.template('paywall_cta', {'price': '\$9.99'}),
      'Get Premium · \$9.99',
    );
    expect(
      content.template('upsell_reveal_note', {'shown': '3', 'total': '12'}),
      'First 3 of 12 shown. Go Premium to reveal the whole round.',
    );
  });

  test('stringList parses and pads short overrides from defaults', () {
    final content = ContentService.instance;
    final features = content.stringList('paywall_features');
    expect(features.length, 3);
    expect(features.first, contains('Full Reveal'));
    content.debugSetOverrides({'paywall_features': '["Only one"]'});
    final padded = content.stringList('paywall_features');
    expect(padded.length, 3);
    expect(padded.first, 'Only one');
    content.debugSetOverrides({'paywall_features': 'not json'});
    expect(content.stringList('paywall_features').length, 3);
  });

  test('load applies fresh cache', () async {
    SharedPreferences.setMockInitialValues({
      'content_cache_json': jsonEncode({'paywall_title': 'Cached'}),
      'content_cache_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    await ContentService.instance.load();
    expect(ContentService.instance.text('paywall_title'), 'Cached');
  });

  test('load ignores stale cache', () async {
    SharedPreferences.setMockInitialValues({
      'content_cache_json': jsonEncode({'paywall_title': 'Stale'}),
      'content_cache_at_ms':
          DateTime.now().millisecondsSinceEpoch - 13 * 3600 * 1000,
    });
    await ContentService.instance.load();
    expect(ContentService.instance.text('paywall_title'), 'Premium');
  });

  test('load never throws on garbage', () async {
    SharedPreferences.setMockInitialValues({'content_cache_json': '{oops'});
    await ContentService.instance.load();
    expect(ContentService.instance.text('paywall_title'), 'Premium');
  });

  test('refresh stores the server map and persists cache', () async {
    final api = MockApiService();
    when(() => api.get<Map<String, dynamic>>('/api/content')).thenAnswer(
      (_) async => _response({
        'content': {'paywall_title': 'Server'},
      }),
    );
    await ContentService.instance.refresh(api);
    expect(ContentService.instance.text('paywall_title'), 'Server');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('content_cache_json'), contains('Server'));
  });

  test('refresh never throws and keeps previous values', () async {
    final api = MockApiService();
    when(
      () => api.get<Map<String, dynamic>>('/api/content'),
    ).thenThrow(Exception('offline'));
    ContentService.instance.debugSetOverrides({'paywall_title': 'Kept'});
    await ContentService.instance.refresh(api);
    expect(ContentService.instance.text('paywall_title'), 'Kept');
  });

  test('refresh ignores non-map payloads', () async {
    final api = MockApiService();
    when(
      () => api.get<Map<String, dynamic>>('/api/content'),
    ).thenAnswer((_) async => _response({'content': 'nope'}));
    await ContentService.instance.refresh(api);
    expect(ContentService.instance.text('paywall_title'), 'Premium');
  });

  testWidgets(
    'global age restriction cannot inherit old Premium-only server text',
    (tester) async {
      ContentService.instance.debugSetOverrides({
        'blocked_title': 'Server title',
      });
      await tester.pumpWidget(const MaterialApp(home: AgeBlockedScreen()));
      expect(find.text('Server title'), findsNothing);
      expect(find.text('Flyprox isn’t available for your age'), findsOneWidget);
    },
  );
}
