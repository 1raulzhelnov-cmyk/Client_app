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
    final router = _createRouter(ref);
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

  GoRouter _createRouter(WidgetRef ref) {
    final auth = ref.watch(firebaseAuthProvider);
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _BootstrapScreen(),
        ),
      ],
      redirect: (context, state) {
        final user = auth.currentUser;
        if (user == null && state.location != '/') {
          return '/';
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.of(context).appTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
