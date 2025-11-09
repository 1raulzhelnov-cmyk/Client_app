import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../generated/l10n.dart';
import '../../../models/user_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/profile_notifier.dart';

class EditProfileScreen extends HookConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final profileState = ref.watch(profileNotifierProvider);
    final user = profileState.valueOrNull;

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final nameController = useTextEditingController(text: user?.name ?? '');
    final phoneController = useTextEditingController(text: user?.phone ?? '');
    final isSubmitting = useState(false);
    final isUploading = useState(false);

    useEffect(() {
      if (user != null) {
        nameController.text = user.name;
        phoneController.text = user.phone ?? '';
      }
      return null;
    }, [user?.id, user?.name, user?.phone]);

    ref.listen<AsyncValue<UserModel>>(profileNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (!context.mounted) {
            return;
          }
          if (isUploading.value) {
            isUploading.value = false;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.photoUpdated)),
              );
            return;
          }
          if (isSubmitting.value) {
            isSubmitting.value = false;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.accountUpdated)),
              );
            context.pop();
          }
        },
        error: (error, _) {
          if (!context.mounted) {
            return;
          }
          isSubmitting.value = false;
          isUploading.value = false;
          final message = error is Failure ? error.message : l10n.errorGeneric;
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
        title: Text(l10n.editProfileTitle),
      ),
      body: SafeArea(
        child: profileState.when(
          data: (profile) => _EditProfileForm(
            profile: profile,
            formKey: formKey,
            nameController: nameController,
            phoneController: phoneController,
            isSubmitting: isSubmitting,
            isUploading: isUploading,
          ),
          loading: () => const Center(child: LoadingIndicator()),
          error: (error, _) => _ProfileErrorMessage(
            message: error is Failure ? error.message : l10n.errorGeneric,
          ),
        ),
      ),
    );
  }
}

class _EditProfileForm extends HookConsumerWidget {
  const _EditProfileForm({
    required this.profile,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.isSubmitting,
    required this.isUploading,
  });

  final UserModel profile;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final ValueNotifier<bool> isSubmitting;
  final ValueNotifier<bool> isUploading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final isLoading = ref.watch(profileNotifierProvider).isLoading;
    final theme = Theme.of(context);
    final avatarInitial = _initialFromName(profile.name);

    Future<void> pickPhoto(ImageSource source) async {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      final picker = ref.read(imagePickerProvider);
      try {
        final xFile = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1024,
        );
        if (xFile == null) {
          return;
        }
        final file = File(xFile.path);
        isUploading.value = true;
        await ref.read(profileNotifierProvider.notifier).uploadPhoto(file);
      } on PlatformException catch (error) {
        isUploading.value = false;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(error.message ?? l10n.errorGeneric)),
          );
      } catch (error) {
        isUploading.value = false;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
      }
    }

    Future<void> showPhotoOptions() async {
      if (!context.mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.photoSourceGallery),
                  onTap: () => pickPhoto(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text(l10n.photoSourceCamera),
                  onTap: () => pickPhoto(ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );
    }

    Future<void> submit() async {
      final formState = formKey.currentState;
      if (formState == null || !formState.validate()) {
        return;
      }
      isSubmitting.value = true;
      await ref.read(profileNotifierProvider.notifier).updateProfile({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
      });
    }

    Future<void> confirmDelete() async {
      if (!context.mounted) {
        return;
      }
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(l10n.confirmDeletionTitle),
            content: Text(l10n.confirmDeletionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      );
      if (shouldDelete != true) {
        return;
      }
      await ref.read(profileNotifierProvider.notifier).deleteAccount();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? Text(
                            avatarInitial,
                            style: theme.textTheme.headlineMedium,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        color: theme.colorScheme.onPrimary,
                        tooltip: l10n.changePhoto,
                        onPressed: isLoading ? null : showPhotoOptions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.fullNameField),
              validator: (value) => Validators.nonEmpty(value, l10n),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: InputDecoration(labelText: l10n.phoneField),
              validator: (value) => Validators.optionalPhone(value, l10n),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: l10n.saveChanges,
              isLoading: isLoading && !isUploading.value,
              onPressed: isLoading ? null : submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isLoading ? null : confirmDelete,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text(l10n.deleteAccount),
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

class _ProfileErrorMessage extends StatelessWidget {
  const _ProfileErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
