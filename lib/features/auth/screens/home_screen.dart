import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../../widgets/app_button.dart';
import '../providers/auth_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? '—',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (user?.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.phone!,
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
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () async {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .logout();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
