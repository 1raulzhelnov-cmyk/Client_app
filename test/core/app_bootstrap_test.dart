import 'dart:async';

import 'package:eazy_client_mvp/core/config/env.dart';
import 'package:eazy_client_mvp/core/di/app_router.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C000 — Инициализация приложения', () {
    tearDown(() {
      dotenv.reset();
    });

    test('EnvConfig.load читает ключи из .env', () async {
      dotenv.testLoad(fileInput: '''
API_BASE_URL=https://api.eazy.test
FIREBASE_WEB_API_KEY=firebase-key
STRIPE_PUBLISHABLE_KEY=stripe-key
GOOGLE_MAPS_API_KEY=gmaps-key
''');

      await EnvConfig.load();

      final env = EnvConfig.instance;
      expect(env.apiBaseUrl, 'https://api.eazy.test');
      expect(env.firebaseWebApiKey, 'firebase-key');
      expect(env.stripePublishableKey, 'stripe-key');
      expect(env.googleMapsApiKey, 'gmaps-key');
    });

    test('resolveAuthRedirect перенаправляет гостя на /login', () {
      const location = '/checkout';
      const AsyncValue<UserModel?> authState = AsyncData(null);

      final redirect = resolveAuthRedirect(
        location: location,
        authState: authState,
      );

      expect(redirect, '/login');
    });

    test('GoRouterRefreshStream нотифицирует слушателей при событии', () async {
      final controller = StreamController<void>();
      final refresh = GoRouterRefreshStream(controller.stream);

      addTearDown(() async {
        await controller.close();
        refresh.dispose();
      });

      var notifications = 0;
      refresh.addListener(() {
        notifications += 1;
      });

      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
