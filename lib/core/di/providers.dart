import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api/api_service.dart';
import '../config/env.dart';

class AppState {
  const AppState();
}

final appProvider = Provider<AppState>((ref) {
  return const AppState();
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final env = ref.watch(envConfigProvider);
  final client = ref.watch(httpClientProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ApiService(
    client: client,
    firebaseAuth: auth,
    baseUrl: env.apiBaseUrl,
  );
});

final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.instance;
});
