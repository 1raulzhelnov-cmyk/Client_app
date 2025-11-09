import 'dart:async';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/home/providers/home_providers.dart';
import 'package:eazy_client_mvp/features/home/screens/home_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/main.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(this._user);

  final UserModel _user;

  @override
  FutureOr<UserModel?> build() => _user;
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated users land on home screen', (tester) async {
    final mockAuth = _MockFirebaseAuth();
    when(mockAuth.authStateChanges()).thenAnswer(
      (_) => const Stream<User?>.empty(),
    );
    when(mockAuth.currentUser).thenReturn(null);

    const user = UserModel(
      id: 'user-1',
      name: 'Тестовый пользователь',
      email: 'test@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          authNotifierProvider.overrideWith(() => _StaticAuthNotifier(user)),
          homeRepositoryProvider
              .overrideWithValue(const HomeRepository(delay: Duration.zero)),
        ],
        child: const EazyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final l10n = await S.load(const Locale('ru'));
    expect(find.text(l10n.home), findsWidgets);
  });
}
