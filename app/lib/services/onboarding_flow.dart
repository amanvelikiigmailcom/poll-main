import 'package:flutter/foundation.dart';

/// Phone verification (or an explicit guest choice) precedes the age question.
/// This contains no phone number, verification code or selected age.
class OnboardingFlow extends ChangeNotifier {
  OnboardingFlow._();
  static final instance = OnboardingFlow._();
  bool _phoneComplete = false;
  bool get phoneComplete => _phoneComplete;

  void completePhoneStep() {
    _phoneComplete = true;
    notifyListeners();
  }

  void restart() {
    _phoneComplete = false;
    notifyListeners();
  }
}
