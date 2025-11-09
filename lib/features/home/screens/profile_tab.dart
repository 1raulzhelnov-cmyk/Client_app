import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/providers/auth_notifier.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    ref.listen<AsyncValue<UserModel?>>(
      authNotifierProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, _) {
            final message = error is Failure ? error.message : l10n.errorGeneric;
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(message)),
              );
          },
        );
      },
    );

    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;

    if (authState.isLoading && user == null) {
      return const Center(child: LoadingIndicator());
    }

    if (authState.hasError && user == null) {
      final error = authState.error;
      final message = error is Failure ? error.message : l10n.errorGeneric;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      _initialFromName(user?.name ?? ''),
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              user?.name ?? '—',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (user?.phone != null && user!.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.phone!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 32),
            AppButton(
              label: l10n.viewProfileButton,
              onPressed: () {
                if (!context.mounted) {
                  return;
                }
                context.push('/profile');
              },
            ),
            const SizedBox(height: 16),
            AppButton(
              label: l10n.logoutButton,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading
                  ? null
                  : () => ref
                      .read(authNotifierProvider.notifier)
                      .logout(),
            ),
          ],
        ),
      ),
    );
  }

  String _initialFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '•';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }
}
