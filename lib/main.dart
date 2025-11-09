import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n.dart';
import 'models/user_model.dart';
import 'features/auth/models/otp_screen_args.dart';
import 'features/auth/providers/auth_notifier.dart';
import 'features/auth/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'widgets/loading_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await _initFirebase();

  runApp(const ProviderScope(child: EazyApp()));
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    debugPrint('Firebase init error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class EazyApp extends ConsumerWidget {
  const EazyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final router = _createRouter(ref, authState);
    final locale = const Locale('ru');

    return MaterialApp.router(
      title: AppConstants.appTitle,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  GoRouter _createRouter(WidgetRef ref, AsyncValue<UserModel?> authState) {
    final auth = ref.watch(firebaseAuthProvider);
    final firebaseUser = auth.currentUser;
    final user = authState.valueOrNull ??
        (firebaseUser != null ? UserModel.fromFirebase(firebaseUser) : null);
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(
        auth.authStateChanges(),
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _BootstrapScreen(),
        ),
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
              return const _BootstrapScreen();
            }
            return OtpScreen(args: extra);
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
        ),
      ],
      redirect: (context, state) {
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/otp';

        if (authState.isLoading) {
          return null;
        }

        if (user == null) {
          if (isAuthRoute) {
            return null;
          }
          return '/login';
        }

        if (isAuthRoute) {
          return '/home';
        }

        return null;
      },
    );
  }
}

class _BootstrapScreen extends ConsumerWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: isLoading
              ? const LoadingIndicator()
              : Text(
                  S.of(context).loading,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
        ),
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
