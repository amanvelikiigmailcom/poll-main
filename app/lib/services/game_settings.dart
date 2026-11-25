import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettings extends ChangeNotifier {
  GameSettings._();
  static final instance = GameSettings._();
  bool sound = true;
  bool haptics = true;
  bool reduceMotion = false;

  bool get effectiveReduceMotion =>
      reduceMotion ||
      PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    sound = prefs.getBool('settings_sound') ?? true;
    haptics = prefs.getBool('settings_haptics') ?? true;
    reduceMotion = prefs.getBool('settings_reduce_motion') ?? false;
    notifyListeners();
  }

  Future<void> setOption(String name, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_$name', value);
    switch (name) {
      case 'sound':
        sound = value;
      case 'haptics':
        haptics = value;
      case 'reduce_motion':
        reduceMotion = value;
      default:
        throw ArgumentError.value(name);
    }
    notifyListeners();
  }

  Future<void> rewardFeedback() async {
    if (haptics) await HapticFeedback.lightImpact();
    if (!sound) return;
    try {
      final played = await const MethodChannel(
        'flyprox/app_info',
      ).invokeMethod<bool>('playRewardSound');
      if (played != true) await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  void rewardComplete() {
    if (haptics) HapticFeedback.mediumImpact();
  }

  void feedback({bool strong = false, bool selection = false}) {
    if (haptics) {
      if (strong) {
        HapticFeedback.heavyImpact();
      } else if (selection) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (sound) SystemSound.play(SystemSoundType.click);
  }
}
