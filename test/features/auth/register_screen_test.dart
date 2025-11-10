import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/auth/screens/register_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier();

  String? lastRegisteredEmail;
  String? lastRegisteredPassword;
  String? lastSentPhone;
  bool googleCalled = false;
  bool appleCalled = false;

  @override
  Future<UserModel?> build() async => null;

  @override
  Future<void> registerEmail(String email, String password) async {
    lastRegisteredEmail = email;
    lastRegisteredPassword = password;
    state = AsyncData(
      UserModel(id: 'uid-new', email: email, name: 'New User'),
    );
  }

  @override
  Future<OtpVerificationResult?> sendOtp(
    String phone, {
    bool forceResend = false,
  }) async {
    lastSentPhone = phone;
    state = const AsyncData(null);
    return const OtpVerificationResult(verificationId: 'vid-123');
  }

  @override
  Future<void> googleSignIn() async {
    googleCalled = true;
    state = const AsyncData(null);
  }

  @override
  Future<void> appleSignIn() async {
    appleCalled = true;
    state = const AsyncData(null);
  }
}

Future<void> _pumpRegisterScreen(
  WidgetTester tester, {
  required _StubAuthNotifier notifier,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const Scaffold(body: Text('OTP Screen')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp.router(
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        routeInformationProvider: router.routeInformationProvider,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C001 — Экран регистрации', () {
    testWidgets('переключает формы email/телефон', (tester) async {
      final notifier = _StubAuthNotifier();
      final l10n = await S.load(const Locale('ru'));

      await _pumpRegisterScreen(tester, notifier: notifier);

      expect(find.text(l10n.emailField), findsWidgets);
      expect(find.text(l10n.phoneField), findsOneWidget);

      await tester.tap(find.text(l10n.phoneField));
      await tester.pumpAndSettle();

      // После переключения должна отображаться кнопка отправки кода
      expect(find.text(l10n.sendCode), findsOneWidget);
      expect(find.text(l10n.registerButton), findsNothing);
    });

    testWidgets('валидация сообщает о несовпадении паролей', (tester) async {
      final notifier = _StubAuthNotifier();
      final l10n = await S.load(const Locale('ru'));

      await _pumpRegisterScreen(tester, notifier: notifier);

      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.emailField),
        'user@example.com',
      );
      await tester.enterText(
        find.bySemanticsLabel(l10n.passwordField),
        'Password1',
      );
      await tester.enterText(
        find.bySemanticsLabel(l10n.confirmPasswordField),
        'Password2',
      );

      await tester.tap(find.text(l10n.registerButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.passwordMismatch), findsOneWidget);
      expect(notifier.lastRegisteredEmail, isNull);
    });

    testWidgets('отправляет OTP и вызывает соц-кнопки', (tester) async {
      final notifier = _StubAuthNotifier();
      final l10n = await S.load(const Locale('ru'));

      await _pumpRegisterScreen(tester, notifier: notifier);

      await tester.tap(find.text(l10n.phoneField));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.phoneField),
        '+79991234567',
      );
      await tester.tap(find.text(l10n.sendCode));
      await tester.pumpAndSettle();

      expect(notifier.lastSentPhone, '+79991234567');

      await tester.tap(find.text(l10n.googleSignIn));
      await tester.pump();
      await tester.tap(find.text(l10n.appleSignIn));
      await tester.pump();

      expect(notifier.googleCalled, isTrue);
      expect(notifier.appleCalled, isTrue);
    });
  });
}
