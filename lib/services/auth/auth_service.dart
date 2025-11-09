import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/errors/failure.dart';
import '../../models/user_model.dart';
import '../api/api_service.dart';

class OtpVerificationResult {
  const OtpVerificationResult({
    this.verificationId,
    this.resendToken,
    this.user,
  });

  final String? verificationId;
  final int? resendToken;
  final UserModel? user;

  bool get isAutoVerified => user != null;
}

class AppleSignInFacade {
  const AppleSignInFacade();

  Future<AuthorizationCredentialAppleID> requestCredential({
    required String nonce,
  }) {
    return SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
  }
}

class AuthService {
  AuthService({
    required FirebaseAuth firebaseAuth,
    required ApiService apiService,
    required GoogleSignIn googleSignIn,
    required AppleSignInFacade appleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _apiService = apiService,
        _googleSignIn = googleSignIn,
        _appleSignIn = appleSignIn;

  final FirebaseAuth _firebaseAuth;
  final ApiService _apiService;
  final GoogleSignIn _googleSignIn;
  final AppleSignInFacade _appleSignIn;

  Future<Either<Failure, UserModel>> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return left(
          const AuthFailure(message: 'Не удалось создать пользователя'),
        );
      }

      final apiResult = await _apiService.post<JsonMap>(
        '/auth/register',
        body: {
          'uid': user.uid,
          'email': email,
        },
      );

      return apiResult.fold(
        (failure) => left(failure),
        (_) => right(UserModel.fromFirebase(user)),
      );
    } on FirebaseAuthException catch (error) {
      return left(_mapFirebaseError(error));
    } catch (error) {
      return left(
        AuthFailure(message: error.toString()),
      );
    }
  }

  Future<Either<Failure, UserModel>> loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return left(
          const AuthFailure(message: 'Не удалось выполнить вход'),
        );
      }
      return right(UserModel.fromFirebase(user));
    } on FirebaseAuthException catch (error) {
      return left(_mapFirebaseError(error));
    } catch (error) {
      return left(
        AuthFailure(message: error.toString()),
      );
    }
  }

  Future<Either<Failure, UserModel>> googleSignIn() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return left(
          const AuthFailure(
            message: 'Вход через Google отменён пользователем',
            code: 'google_sign_in_cancelled',
          ),
        );
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        return left(
          const AuthFailure(
            message: 'Не удалось получить токен Google',
            code: 'google_sign_in_no_token',
          ),
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _signInOrLink(credential);
    } on PlatformException catch (error) {
      return left(
        AuthFailure(
          message: error.message ??
              'Не удалось выполнить вход через Google. Попробуйте снова.',
          code: error.code,
        ),
      );
    } catch (error) {
      return left(AuthFailure(message: error.toString()));
    }
  }

  Future<Either<Failure, UserModel>> appleSignIn() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential =
          await _appleSignIn.requestCredential(nonce: nonce);
      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        return left(
          const AuthFailure(
            message: 'Не удалось получить токен Apple ID',
            code: 'apple_sign_in_no_token',
          ),
        );
      }
      final credential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      return _signInOrLink(credential);
    } on SignInWithAppleAuthorizationException catch (error) {
      return left(_mapAppleError(error));
    } on PlatformException catch (error) {
      return left(
        AuthFailure(
          message: error.message ??
              'Не удалось выполнить вход через Apple. Попробуйте снова.',
          code: error.code,
        ),
      );
    } catch (error) {
      return left(AuthFailure(message: error.toString()));
    }
  }

  Future<Either<Failure, Unit>> logout() async {
    try {
      await _firebaseAuth.signOut();
      return right(unit);
    } on FirebaseAuthException catch (error) {
      return left(_mapFirebaseError(error));
    } catch (error) {
      return left(AuthFailure(message: error.toString()));
    }
  }

  Future<Either<Failure, OtpVerificationResult>> sendOtp({
    required String phone,
    int? forceResendToken,
  }) async {
    final completer =
        Completer<Either<Failure, OtpVerificationResult>>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: forceResendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            final result =
                await _firebaseAuth.signInWithCredential(credential);
            final user = result.user;
            if (user != null && !completer.isCompleted) {
              completer.complete(
                right(
                  OtpVerificationResult(
                    user: UserModel.fromFirebase(user),
                  ),
                ),
              );
            }
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete(
                left(AuthFailure(message: error.toString())),
              );
            }
          }
        },
        verificationFailed: (exception) {
          if (!completer.isCompleted) {
            completer.complete(left(_mapFirebaseError(exception)));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) {
            completer.complete(
              right(
                OtpVerificationResult(
                  verificationId: verificationId,
                  resendToken: resendToken,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete(
              right(
                OtpVerificationResult(
                  verificationId: verificationId,
                ),
              ),
            );
          }
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!completer.isCompleted) {
        completer.complete(left(_mapFirebaseError(error)));
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(
          left(AuthFailure(message: error.toString())),
        );
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () => left(
        const AuthFailure(
          message: 'Время ожидания истекло. Попробуйте снова.',
        ),
      ),
    );
  }

  Future<Either<Failure, UserModel>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        return left(
          const AuthFailure(
            message: 'Не удалось подтвердить код. Попробуйте снова.',
          ),
        );
      }
      return right(UserModel.fromFirebase(user));
    } on FirebaseAuthException catch (error) {
      return left(_mapFirebaseError(error));
    } catch (error) {
      return left(
        AuthFailure(message: error.toString()),
      );
    }
  }

  AuthFailure _mapFirebaseError(FirebaseAuthException exception) {
    final message = exception.message ??
        switch (exception.code) {
          'invalid-email' => 'Некорректный email',
          'user-disabled' => 'Пользователь заблокирован',
          'user-not-found' => 'Пользователь не найден',
          'wrong-password' => 'Неверный пароль',
          'email-already-in-use' => 'Email уже используется',
          'weak-password' => 'Слишком простой пароль',
          'invalid-verification-code' => 'Неверный код подтверждения',
          'invalid-verification-id' => 'Истек срок действия кода',
          'account-exists-with-different-credential' =>
            'Аккаунт с этим email уже существует. Войдите с привязанным провайдером и свяжите учетные записи.',
          'credential-already-in-use' =>
            'Эти учетные данные уже привязаны к другому аккаунту.',
          'provider-already-linked' =>
            'Этот провайдер уже привязан к вашему аккаунту.',
          'requires-recent-login' =>
            'Требуется повторный вход. Перелогиньтесь и попробуйте снова.',
          'too-many-requests' =>
            'Слишком много попыток. Попробуйте позже.',
          _ => 'Ошибка аутентификации. Повторите попытку позже.',
        };
    return AuthFailure(
      message: message,
      code: exception.code,
    );
  }

  Future<Either<Failure, UserModel>> _signInOrLink(
    AuthCredential credential,
  ) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      User? user;
      if (currentUser != null) {
        try {
          final result = await currentUser.linkWithCredential(credential);
          user = result.user ?? currentUser;
        } on FirebaseAuthMultiFactorException catch (error) {
          return left(
            AuthFailure(
              message:
                  'Требуется многофакторная аутентификация. Завершите подтверждение и попробуйте снова.',
              code: error.code,
            ),
          );
        } on FirebaseAuthException catch (error) {
          if (error.code == 'provider-already-linked') {
            user = currentUser;
          } else if (error.code == 'credential-already-in-use') {
            final signInResult =
                await _firebaseAuth.signInWithCredential(credential);
            user = signInResult.user;
          } else if (error.code == 'requires-recent-login') {
            return left(
              AuthFailure(
                message:
                    'Пожалуйста, выполните повторный вход и попробуйте снова.',
                code: error.code,
              ),
            );
          } else {
            rethrow;
          }
        }
      } else {
        final result = await _firebaseAuth.signInWithCredential(credential);
        user = result.user;
      }

      if (user == null) {
        return left(
          const AuthFailure(
            message: 'Не удалось выполнить вход. Попробуйте снова.',
          ),
        );
      }
      return right(UserModel.fromFirebase(user));
    } on FirebaseAuthMultiFactorException catch (error) {
      return left(
        AuthFailure(
          message:
              'Требуется многофакторная аутентификация. Завершите подтверждение и попробуйте снова.',
          code: error.code,
        ),
      );
    } on FirebaseAuthException catch (error) {
      return left(_mapFirebaseError(error));
    } catch (error) {
      return left(AuthFailure(message: error.toString()));
    }
  }

  AuthFailure _mapAppleError(
    SignInWithAppleAuthorizationException exception,
  ) {
    final message = switch (exception.code) {
      AuthorizationErrorCode.canceled =>
        'Вход через Apple отменён пользователем',
      AuthorizationErrorCode.failed =>
        'Не удалось выполнить вход через Apple.',
      AuthorizationErrorCode.invalidResponse =>
        'Получен некорректный ответ от сервиса Apple.',
      AuthorizationErrorCode.notHandled =>
        'Сервис Apple не обработал операцию входа.',
      AuthorizationErrorCode.unknown =>
        'Неизвестная ошибка при входе через Apple.',
    };
    return AuthFailure(
      message: message,
      code: exception.code.name,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
