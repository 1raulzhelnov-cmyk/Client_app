import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final profileState = ref.watch(profileNotifierProvider);

    ref.listen<AsyncValue<UserModel>>(profileNotifierProvider, (previous, next) {
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
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: profileState.hasValue
                ? () => context.push('/profile/edit')
                : null,
            tooltip: l10n.editProfileButton,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: profileState.when(
            data: (user) => _ProfileContent(user: user),
            loading: () => const Center(child: LoadingIndicator()),
            error: (error, _) => _ProfileError(
              message: error is Failure ? error.message : l10n.errorGeneric,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final avatarRadius = 48.0;
    final avatarInitial = _initialFromName(user.name);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(
                  avatarInitial,
                  style: theme.textTheme.headlineMedium,
                )
              : null,
        ),
        const SizedBox(height: 24),
        Text(
          user.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.email,
          style: theme.textTheme.bodyLarge,
        ),
        if (user.phone != null && user.phone!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            user.phone!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const Spacer(),
        AppButton(
          label: l10n.editProfileButton,
          onPressed: () => context.push('/profile/edit'),
        ),
      ],
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

class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: l10n.retry,
            onPressed: () => ref.invalidate(profileNotifierProvider),
          ),
        ],
      ),
    );
  }
}
