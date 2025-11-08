import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._({
    required this.apiBaseUrl,
    required this.firebaseWebApiKey,
    required this.stripePublishableKey,
    required this.googleMapsApiKey,
  });

  final String apiBaseUrl;
  final String firebaseWebApiKey;
  final String stripePublishableKey;
  final String googleMapsApiKey;

  static EnvConfig? _instance;

  static EnvConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError(
        'EnvConfig has not been initialized. Call EnvConfig.load() before accessing.',
      );
    }
    return config;
  }

  static Future<void> load() async {
    if (dotenv.isInitialized) {
      _instance = EnvConfig._(
        apiBaseUrl: _readEnv('API_BASE_URL'),
        firebaseWebApiKey: _readEnv('FIREBASE_WEB_API_KEY'),
        stripePublishableKey: _readEnv('STRIPE_PUBLISHABLE_KEY'),
        googleMapsApiKey: _readEnv('GOOGLE_MAPS_API_KEY'),
      );
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (error, stackTrace) {
      debugPrint('Env load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    _instance = EnvConfig._(
      apiBaseUrl: _readEnv('API_BASE_URL'),
      firebaseWebApiKey: _readEnv('FIREBASE_WEB_API_KEY'),
      stripePublishableKey: _readEnv('STRIPE_PUBLISHABLE_KEY'),
      googleMapsApiKey: _readEnv('GOOGLE_MAPS_API_KEY'),
    );
  }

  static String _readEnv(String key) {
    final value = dotenv.maybeGet(key) ?? '';
    if (value.isEmpty) {
      debugPrint('Warning: environment key $key is missing.');
    }
    return value;
  }
}
