import 'package:collection/collection.dart';

import '../../generated/l10n.dart';

class Validators {
  const Validators._();

  static String? email(String? value, S l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) {
      return l10n.invalidEmail;
    }
    return null;
  }

  static String? password(String? value, S l10n) {
    if (value == null || value.isEmpty) {
      return l10n.requiredField;
    }
    final regex = RegExp(r'^(?=.*?[A-Z])(?=.*?[0-9]).{8,}$');
    if (!regex.hasMatch(value)) {
      return l10n.invalidPassword;
    }
    return null;
  }

  static String? confirmPassword(
    String? value,
    String? original,
    S l10n,
  ) {
    if (value == null || value.isEmpty) {
      return l10n.requiredField;
    }
    if (value != original) {
      return l10n.passwordMismatch;
    }
    return null;
  }

  static String? phone(String? value, S l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!regex.hasMatch(value.trim())) {
      return l10n.invalidPhone;
    }
    return null;
  }

  static String? nonEmpty(String? value, S l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    return null;
  }

  static String? listNonEmpty(
    Iterable<Object?>? values,
    S l10n,
  ) {
    if (values == null || values.isEmpty || values.all((element) => element == null)) {
      return l10n.requiredField;
    }
    return null;
  }

  static String? optionalPhone(String? value, S l10n) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!regex.hasMatch(value.trim())) {
      return l10n.invalidPhone;
    }
    return null;
  }
}
