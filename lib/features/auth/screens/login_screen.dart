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
import '../providers/auth_notifier.dart';
import '../widgets/password_field.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginTitle),
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
                  l10n.loginSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: l10n.emailField,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => Validators.email(value, l10n),
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: passwordController,
                  label: l10n.passwordField,
                  validator: (value) => Validators.password(value, l10n),
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: l10n.loginButton,
                  isLoading: isLoading,
                  onPressed: () async {
                    if (isLoading) {
                      return;
                    }
                    final formState = formKey.currentState;
                    if (formState == null ||
                        !formState.validate()) {
                      return;
                    }
                    FocusScope.of(context).unfocus();
                    await ref
                        .read(authNotifierProvider.notifier)
                        .loginEmail(
                          emailController.text.trim(),
                          passwordController.text,
                        );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (!context.mounted) {
                      return;
                    }
                    context.push('/register');
                  },
                  child: Text(l10n.registerPrompt),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
