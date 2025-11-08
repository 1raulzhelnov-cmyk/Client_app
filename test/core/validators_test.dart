import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eazy_client_mvp/core/utils/validators.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';

void main() {
  group('Validators', () {
    late S l10n;

    setUp(() async {
      l10n = await S.load(const Locale('ru'));
    });

    test('valid email returns null', () {
      final result = Validators.email('test@example.com', l10n);
      expect(result, isNull);
    });

    test('invalid email returns message', () {
      final result = Validators.email('invalid', l10n);
      expect(result, l10n.invalidEmail);
    });

    test('empty password validation', () {
      final result = Validators.password('', l10n);
      expect(result, l10n.requiredField);
    });
  });
}
