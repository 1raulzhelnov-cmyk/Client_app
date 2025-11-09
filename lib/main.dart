import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/di/app_router.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await _initStripe();
  await _initFirebase();

  runApp(const ProviderScope(child: EazyApp()));
}

Future<void> _initStripe() async {
  try {
    Stripe.publishableKey = EnvConfig.instance.stripePublishableKey;
    await Stripe.instance.applySettings();
  } catch (error, stackTrace) {
    debugPrint('Stripe init error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
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
    final router = ref.watch(appRouterProvider);
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
}
