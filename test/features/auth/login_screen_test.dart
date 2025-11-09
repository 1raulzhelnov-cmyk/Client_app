import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/auth/screens/login_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _SilentAuthNotifier extends AuthNotifier {
  bool googleCalled = false;
  bool appleCalled = false;

  @override
  FutureOr<UserModel?> build() => null;

  @override
  Future<void> googleSignIn() async {
    googleCalled = true;
  }

  @override
  Future<void> appleSignIn() async {
    appleCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen', () {
    late MockAuthService authService;
    late MockFirebaseAuth firebaseAuth;

    setUp(() {
      authService = MockAuthService();
      firebaseAuth = MockFirebaseAuth();
      when(firebaseAuth.currentUser).thenReturn(null);
    });

    Future<_SilentAuthNotifier> pumpLoginScreen(
      WidgetTester tester,
    ) async {
      late _SilentAuthNotifier notifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            firebaseAuthProvider.overrideWithValue(firebaseAuth),
            authNotifierProvider.overrideWith(() {
              notifier = _SilentAuthNotifier();
              return notifier;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: S.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      return notifier;
    }

    testWidgets('shows required validation messages', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      await pumpLoginScreen(tester);

      await tester.tap(find.text(l10n.loginButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.requiredField), findsWidgets);
    });

    testWidgets('shows invalid email message', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      await pumpLoginScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.emailField),
        'invalid',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.passwordField),
        'Password1',
      );

      await tester.tap(find.text(l10n.loginButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.invalidEmail), findsOneWidget);
    });

    testWidgets('taps Google button and calls notifier', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      final notifier = await pumpLoginScreen(tester);

      await tester.tap(find.text(l10n.googleSignIn));
      await tester.pump();

      expect(notifier.googleCalled, isTrue);
    });

    testWidgets('taps Apple button and calls notifier', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      final notifier = await pumpLoginScreen(tester);

      await tester.tap(find.text(l10n.appleSignIn));
      await tester.pump();

      expect(notifier.appleCalled, isTrue);
    });
  });
}
