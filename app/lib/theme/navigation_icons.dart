import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Eight glyphs from Phosphor: four matching regular/fill navigation pairs.
/// Source revision and MIT notice are bundled with the fonts.
abstract final class NavigationIcons {
  static const _regular = 'FlyproxNavRegular';
  static const _fill = 'FlyproxNavFill';

  static const home = IconData(0xe2c2, fontFamily: _regular);
  static const homeFill = IconData(0xe2c2, fontFamily: _fill);
  static const quiz = IconData(0xe0f8, fontFamily: _regular);
  static const quizFill = IconData(0xe0f8, fontFamily: _fill);
  static const profile = IconData(0xe4c4, fontFamily: _regular);
  static const profileFill = IconData(0xe4c4, fontFamily: _fill);
  static const settings = IconData(0xe272, fontFamily: _regular);
  static const settingsFill = IconData(0xe272, fontFamily: _fill);

  static void registerLicense() {
    LicenseRegistry.addLicense(() async* {
      final notice = await rootBundle.loadString(
        'assets/fonts/phosphor/LICENSE.txt',
      );
      yield LicenseEntryWithLineBreaks(['Phosphor Icons'], notice);
    });
  }
}
