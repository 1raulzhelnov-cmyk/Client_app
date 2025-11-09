import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api/api_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/firestore/firestore_service.dart';
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

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
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

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: const <String>[
      'email',
    ],
  );
});

final appleSignInProvider = Provider<AppleSignInFacade>((ref) {
  return const AppleSignInFacade();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final apiService = ref.watch(apiServiceProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  final appleSignIn = ref.watch(appleSignInProvider);
  return AuthService(
    firebaseAuth: firebaseAuth,
    apiService: apiService,
    googleSignIn: googleSignIn,
    appleSignIn: appleSignIn,
  );
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return FirestoreService(
    firestore: firestore,
    storage: storage,
    firebaseAuth: firebaseAuth,
  );
});

final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.instance;
});
