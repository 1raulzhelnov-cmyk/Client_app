import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/user_model.dart';
import '../../../services/auth/auth_service.dart';

final authNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);

class AuthNotifier extends AutoDisposeAsyncNotifier<UserModel?> {
  OtpVerificationResult? _otpState;

  OtpVerificationResult? get otpState => _otpState;

  @override
  FutureOr<UserModel?> build() {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      return null;
    }
    return UserModel.fromFirebase(firebaseUser);
  }

  Future<void> registerEmail(String email, String password) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authServiceProvider).registerWithEmail(email, password);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  Future<void> loginEmail(String email, String password) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authServiceProvider).loginWithEmail(email, password);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }

  Future<OtpVerificationResult?> sendOtp(
    String phone, {
    bool forceResend = false,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).sendOtp(
          phone: phone,
          forceResendToken: forceResend ? _otpState?.resendToken : null,
        );

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (otpResult) {
        if (otpResult.user != null) {
          _otpState = null;
          state = AsyncData(otpResult.user);
        } else {
          _otpState = otpResult;
          state = AsyncData(state.valueOrNull);
        }
        return otpResult;
      },
    );
  }

  Future<void> verifyOtp(
    String smsCode, {
    String? verificationId,
  }) async {
    final resolvedVerificationId =
        verificationId ?? _otpState?.verificationId;
    if (resolvedVerificationId == null) {
      state = AsyncError(
        const AuthFailure(
          message: 'Отсутствует идентификатор подтверждения. Отправьте код ещё раз.',
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).verifyOtp(
          verificationId: resolvedVerificationId,
          smsCode: smsCode,
        );
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) {
        _otpState = null;
        return AsyncData(user);
      },
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).logout();
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );
  }

  void clearOtpState() {
    _otpState = null;
  }
}
