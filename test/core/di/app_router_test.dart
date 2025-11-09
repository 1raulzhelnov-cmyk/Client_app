import 'package:eazy_client_mvp/core/di/app_router.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('resolveAuthRedirect', () {
    const locationHome = '/';
    const locationLogin = '/login';
    const locationProfile = '/profile';

    test('returns null while auth state is loading', () {
      const authState = AsyncLoading<UserModel?>();
      final redirect = resolveAuthRedirect(
        location: locationHome,
        authState: authState,
      );
      expect(redirect, isNull);
    });

    test('redirects to login when user is null and route is protected', () {
      const authState = AsyncData<UserModel?>(null);
      final redirect = resolveAuthRedirect(
        location: locationProfile,
        authState: authState,
      );
      expect(redirect, '/login');
    });

    test('allows auth routes when user is null', () {
      const authState = AsyncData<UserModel?>(null);
      final redirect = resolveAuthRedirect(
        location: locationLogin,
        authState: authState,
      );
      expect(redirect, isNull);
    });

    test('redirects authenticated user away from auth screens', () {
      const user = UserModel(
        id: 'user-1',
        name: 'Tester',
        email: 'test@example.com',
      );
      const authState = AsyncData<UserModel?>(user);

      final redirect = resolveAuthRedirect(
        location: locationLogin,
        authState: authState,
      );

      expect(redirect, '/');
    });

    test('allows navigation for authenticated user on protected route', () {
      const user = UserModel(
        id: 'user-1',
        name: 'Tester',
        email: 'test@example.com',
      );
      const authState = AsyncData<UserModel?>(user);

      final redirect = resolveAuthRedirect(
        location: locationProfile,
        authState: authState,
      );

      expect(redirect, isNull);
    });
  });
}
