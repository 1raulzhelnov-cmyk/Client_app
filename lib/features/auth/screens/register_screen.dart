import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../generated/l10n.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_button.dart';
import '../models/otp_screen_args.dart';
import '../providers/auth_notifier.dart';
import '../widgets/password_field.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);

    final useEmail = useState(true);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final phoneController = useTextEditingController();

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
      ref.read(authNotifierProvider.notifier).clearOtpState();
      return null;
    }, [useEmail.value]);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.registerTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                ToggleButtons(
                  isSelected: [
                    useEmail.value,
                    !useEmail.value,
                  ],
                  onPressed: (index) {
                    useEmail.value = index == 0;
                  },
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultRadius,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(l10n.emailField),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(l10n.phoneField),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (useEmail.value) ...[
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: l10n.emailField,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => Validators.email(value, l10n),
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: passwordController,
                    label: l10n.passwordField,
                    validator: (value) => Validators.password(value, l10n),
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: confirmPasswordController,
                    label: l10n.confirmPasswordField,
                    validator: (value) => Validators.confirmPassword(
                      value,
                      passwordController.text,
                      l10n,
                    ),
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: l10n.registerButton,
                    isLoading: isLoading,
                    onPressed: () async {
                      if (isLoading) {
                        return;
                      }
                      final formState = formKey.currentState;
                      if (formState == null || !formState.validate()) {
                        return;
                      }
                      FocusScope.of(context).unfocus();
                      await ref
                          .read(authNotifierProvider.notifier)
                          .registerEmail(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneField,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) => Validators.phone(value, l10n),
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: l10n.sendCode,
                    isLoading: isLoading,
                    onPressed: () async {
                      if (isLoading) {
                        return;
                      }
                      final formState = formKey.currentState;
                      if (formState == null || !formState.validate()) {
                        return;
                      }
                      FocusScope.of(context).unfocus();
                      final phone = phoneController.text.trim();
                      final otpResult = await ref
                          .read(authNotifierProvider.notifier)
                          .sendOtp(phone);
                      if (!context.mounted) {
                        return;
                      }
                      if (otpResult == null) {
                        return;
                      }
                      if (otpResult.isAutoVerified) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(l10n.successGeneric)),
                          );
                        return;
                      }
                      final verificationId = otpResult.verificationId;
                      if (verificationId == null) {
                        return;
                      }
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.otpSent)),
                        );
                      context.push(
                        '/otp',
                        extra: OtpScreenArgs(
                          phoneNumber: phone,
                          verificationId: verificationId,
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (!context.mounted) {
                      return;
                    }
                    context.pop();
                  },
                  child: Text(l10n.loginButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
