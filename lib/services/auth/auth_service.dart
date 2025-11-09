import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class AuthService {
  AuthService({
    required FirebaseAuth firebaseAuth,
    required ApiService apiService,
  })  : _firebaseAuth = firebaseAuth,
        _apiService = apiService;

  final FirebaseAuth _firebaseAuth;
  final ApiService _apiService;

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
          'too-many-requests' =>
            'Слишком много попыток. Попробуйте позже.',
          _ => 'Ошибка аутентификации. Повторите попытку позже.',
        };
    return AuthFailure(
      message: message,
      code: exception.code,
    );
  }
}
