import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_button.dart';
import '../models/otp_screen_args.dart';
import '../providers/auth_notifier.dart';

class OtpScreen extends HookConsumerWidget {
  const OtpScreen({
    super.key,
    required this.args,
  });

  final OtpScreenArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final codeController = useTextEditingController();
    final verificationId = useState(args.verificationId);
    final resendCooldown = useState(0);

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<UserModel?>>(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final message = error is Failure
              ? error.message
              : l10n.errorGeneric;
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(message)),
            );
        },
        data: (user) async {
          if (user == null) {
            return;
          }
          final wasAuthenticated = previous?.valueOrNull != null;
          if (wasAuthenticated) {
            return;
          }
          if (!context.mounted) {
            return;
          }
          await Future<void>.delayed(Duration.zero);
          if (context.mounted) {
            context.go('/home');
          }
        },
      );
    });

    useEffect(() {
      Timer? timer;
      if (resendCooldown.value > 0) {
        timer = Timer.periodic(const Duration(seconds: 1), (tick) {
          if (resendCooldown.value <= 1) {
            resendCooldown.value = 0;
            tick.cancel();
          } else {
            resendCooldown.value = resendCooldown.value - 1;
          }
        });
      }
      return timer?.cancel;
    }, [resendCooldown.value]);

    Future<void> verifyCode(String code) async {
      FocusScope.of(context).unfocus();
      await ref.read(authNotifierProvider.notifier).verifyOtp(
            code,
            verificationId: verificationId.value,
          );
    }

    Future<void> resendCode() async {
      if (isLoading || resendCooldown.value > 0) {
        return;
      }
      final otpResult = await ref
          .read(authNotifierProvider.notifier)
          .sendOtp(args.phoneNumber, forceResend: true);
      if (!context.mounted) {
        return;
      }
      if (otpResult == null) {
        return;
      }
      if (otpResult.isAutoVerified) {
        return;
      }
      final newVerificationId = otpResult.verificationId;
      if (newVerificationId != null) {
        verificationId.value = newVerificationId;
      }
      resendCooldown.value = 30;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.otpSent)),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.otpTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.otpSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                args.phoneNumber,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: codeController,
                autoFocus: true,
                animationType: AnimationType.fade,
                keyboardType: TextInputType.number,
                enabled: !isLoading,
                onCompleted: verifyCode,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultRadius),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeColor: Theme.of(context).colorScheme.primary,
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  inactiveColor:
                      Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: l10n.verifyCode,
                isLoading: isLoading,
                onPressed: () async {
                  if (isLoading) {
                    return;
                  }
                  final code = codeController.text.trim();
                  if (code.length != 6) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text(l10n.invalidOtp)),
                      );
                    return;
                  }
                  await verifyCode(code);
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: resendCooldown.value > 0 ? null : resendCode,
                child: resendCooldown.value > 0
                    ? Text('${l10n.resendCode} (${resendCooldown.value})')
                    : Text(l10n.resendCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
