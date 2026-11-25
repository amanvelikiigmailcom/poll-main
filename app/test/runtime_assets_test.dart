import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/widgets/common/startup_intro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup, native reward sound and navigation font assets remain bundled',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      const requiredAssets = [
        'assets/images/flyprox-logo.png',
        StartupIntro.asset,
        // AppDelegate.swift resolves this exact key for native reward playback.
        'assets/sounds/reward.wav',
        'assets/fonts/phosphor/LICENSE.txt',
        'assets/fonts/phosphor/flyprox-nav-regular.ttf',
        'assets/fonts/phosphor/flyprox-nav-fill.ttf',
      ];

      expect(manifest.listAssets(), containsAll(requiredAssets));
      for (final asset in requiredAssets) {
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
      }
    },
  );

  test(
    'retired local university directory is not part of runtime assets',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets(),
        isNot(contains('assets/data/us_universities.json')),
      );
    },
  );
}
