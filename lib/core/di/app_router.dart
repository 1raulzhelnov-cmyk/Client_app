import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/address/screens/add_address_screen.dart';
import '../../features/address/screens/address_list_screen.dart';
import '../../features/address/screens/edit_address_screen.dart';
import '../../features/auth/models/otp_screen_args.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/venue/screens/venue_detail_screen.dart';
import '../../models/address_model.dart';
import '../../models/user_model.dart';
import '../di/providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);

  final refreshListenable = GoRouterRefreshStream(
    firebaseAuth.authStateChanges(),
  );

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! OtpScreenArgs) {
            return const LoginScreen();
          }
          return OtpScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/',
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/addresses/add',
        builder: (context, state) => const AddAddressScreen(),
      ),
      GoRoute(
        path: '/addresses/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! AddressModel) {
            return const AddressListScreen();
          }
          return EditAddressScreen(address: extra);
        },
      ),
      GoRoute(
        path: '/venue/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) {
            return const HomeScreen();
          }
          return VenueDetailScreen(venueId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      return resolveAuthRedirect(
        location: location,
        authState: authState,
      );
    },
    refreshListenable: refreshListenable,
  );
});

String? resolveAuthRedirect({
  required String location,
  required AsyncValue<UserModel?> authState,
}) {
  final normalizedLocation = location.isEmpty ? '/' : location;
  const authRoutes = <String>{'/login', '/register', '/otp'};
  final isAuthRoute = authRoutes.contains(normalizedLocation);

  if (authState.isLoading) {
    return null;
  }

  final user = authState.valueOrNull;
  if (user == null && !isAuthRoute) {
    return '/login';
  }

  if (user != null && isAuthRoute) {
    return '/';
  }

  return null;
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
