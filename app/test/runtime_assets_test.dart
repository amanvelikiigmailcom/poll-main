import 'dart:ui' as ui;

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
    'retired university directory and localization JSON are not bundled',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets(),
        isNot(contains('assets/data/us_universities.json')),
      );
      expect(
        manifest.listAssets().where(
          (asset) => asset.startsWith('assets/l10n/'),
        ),
        isEmpty,
      );
      expect(
        manifest.listAssets().where(
          (asset) =>
              asset.startsWith('assets/images/design/') ||
              asset.startsWith('docs/reference/'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'logo keeps 4x splash resolution within its runtime byte budget',
    () async {
      final data = await rootBundle.load('assets/images/flyprox-logo.png');
      expect(data.lengthInBytes, lessThan(200 * 1024));
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          // The largest call-site is 112 logical pixels, not 112 physical pixels.
          expect(frame.image.width, greaterThanOrEqualTo(112 * 4));
          expect(frame.image.height, frame.image.width);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );
}
