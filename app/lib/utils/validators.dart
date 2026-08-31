import 'constants.dart';

class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter phone number';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return 'Invalid phone number';
    return null;
  }

  static String? firstName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter first name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? lastName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter last name';
    if (value.trim().length < 2) return 'Last name must be at least 2 characters';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter username';
    if (value.length < AppConstants.minUsernameLength) {
      return 'Username must be at least ${AppConstants.minUsernameLength} characters';
    }
    if (value.length > AppConstants.maxUsernameLength) {
      return 'Username must be at most ${AppConstants.maxUsernameLength} characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers and _';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return 'Select age';
    final age = int.tryParse(value);
    if (age == null) return 'Invalid age';
    if (age < AppConstants.minAge || age > AppConstants.maxAge) {
      return 'Age must be 18+';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'Enter code';
    if (value.length != 6) return 'Code must be 6 digits';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'Digits only';
    return null;
  }
}
