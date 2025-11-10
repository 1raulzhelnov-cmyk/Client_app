import 'package:eazy_client_mvp/features/auth/models/otp_screen_args.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/auth/screens/otp_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier();

  bool verifyCalled = false;
  bool resendCalled = false;

  @override
  Future<UserModel?> build() async => null;

  @override
  Future<void> verifyOtp(
    String smsCode, {
    String? verificationId,
  }) async {
    verifyCalled = true;
    state = const AsyncData(null);
  }

  @override
  Future<OtpVerificationResult?> sendOtp(
    String phone, {
    bool forceResend = false,
  }) async {
    resendCalled = true;
    state = const AsyncData(null);
    return const OtpVerificationResult(
      verificationId: 'new-vid',
      resendToken: 2,
    );
  }
}

Future<void> _pumpOtpScreen(
  WidgetTester tester, {
  required _StubAuthNotifier notifier,
  Locale locale = const Locale('ru'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: OtpScreen(
          args: const OtpScreenArgs(
            phoneNumber: '+7 999 000-00-00',
            verificationId: 'vid-123',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C001 — OTP экран', () {
    testWidgets('отображает телефон и переводы RU/EN', (tester) async {
      final notifier = _StubAuthNotifier();

      await _pumpOtpScreen(tester, notifier: notifier, locale: const Locale('ru'));
      final l10nRu = await S.load(const Locale('ru'));
      expect(find.text(l10nRu.otpTitle), findsOneWidget);
      expect(find.text('+7 999 000-00-00'), findsOneWidget);

      await _pumpOtpScreen(tester, notifier: notifier, locale: const Locale('en'));
      final l10nEn = await S.load(const Locale('en'));
      expect(find.text(l10nEn.otpTitle), findsOneWidget);
    });

    testWidgets('валидация предупреждает о коротком коде', (tester) async {
      final notifier = _StubAuthNotifier();
      final l10n = await S.load(const Locale('ru'));

      await _pumpOtpScreen(tester, notifier: notifier);

      await tester.enterText(find.byType(TextField).first, '123');
      await tester.tap(find.text(l10n.verifyCode));
      await tester.pumpAndSettle();

      expect(find.text(l10n.invalidOtp), findsOneWidget);
      expect(notifier.verifyCalled, isFalse);
    });

    testWidgets('отправляет код повторно при нажатии на кнопку', (tester) async {
      final notifier = _StubAuthNotifier();
      final l10n = await S.load(const Locale('ru'));

      await _pumpOtpScreen(tester, notifier: notifier);

      await tester.tap(find.text(l10n.resendCode));
      await tester.pumpAndSettle();

      expect(notifier.resendCalled, isTrue);
      expect(find.textContaining('(30)'), findsOneWidget);
    });
  });
}
