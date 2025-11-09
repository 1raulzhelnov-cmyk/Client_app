import 'dart:async';

import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/home/providers/home_providers.dart';
import 'package:eazy_client_mvp/features/home/screens/home_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(this._user);

  final UserModel _user;

  @override
  FutureOr<UserModel?> build() => _user;

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen', () {
    late UserModel user;

    setUp(() {
      user = const UserModel(
        id: 'user-1',
        name: 'Тестовый пользователь',
        email: 'test@example.com',
      );
    });

    Future<void> pumpHomeScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeRepositoryProvider
                .overrideWithValue(const HomeRepository(delay: Duration.zero)),
            authNotifierProvider.overrideWith(() => _StaticAuthNotifier(user)),
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
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('updates bottom navigation index on tap', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      await pumpHomeScreen(tester);

      final navBarInitial = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBarInitial.currentIndex, 0);

      await tester.tap(find.text(l10n.cart));
      await tester.pumpAndSettle();
      final navBarAfterCart = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBarAfterCart.currentIndex, 1);

      await tester.tap(find.text(l10n.orders));
      await tester.pumpAndSettle();
      final navBarAfterOrders = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBarAfterOrders.currentIndex, 2);

      await tester.tap(find.text(l10n.profileTitle));
      await tester.pumpAndSettle();
      final navBarAfterProfile = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBarAfterProfile.currentIndex, 3);
    });
  });
}
