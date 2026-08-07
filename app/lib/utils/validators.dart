import 'constants.dart';

class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите номер телефона';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return 'Неверный номер телефона';
    return null;
  }

  static String? firstName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите имя';
    if (value.trim().length < 2) return 'Имя должно быть не менее 2 символов';
    return null;
  }

  static String? lastName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите фамилию';
    if (value.trim().length < 2) return 'Фамилия должна быть не менее 2 символов';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите логин';
    if (value.length < AppConstants.minUsernameLength) {
      return 'Логин должен быть не менее ${AppConstants.minUsernameLength} символов';
    }
    if (value.length > AppConstants.maxUsernameLength) {
      return 'Логин должен быть не более ${AppConstants.maxUsernameLength} символов';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Только латинские буквы, цифры и _';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return 'Выберите возраст';
    final age = int.tryParse(value);
    if (age == null) return 'Неверный возраст';
    if (age < AppConstants.minAge || age > AppConstants.maxAge) {
      return 'Возраст должен быть от ${AppConstants.minAge} до ${AppConstants.maxAge} лет';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'Введите код';
    if (value.length != 6) return 'Код должен содержать 6 цифр';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'Только цифры';
    return null;
  }
}
