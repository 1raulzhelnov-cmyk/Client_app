import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/address_notifier.dart';

class AddressListScreen extends HookConsumerWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final addresses = ref.watch(addressNotifierProvider);
    final notifier = ref.read(addressNotifierProvider.notifier);
    final isLoading = useState<bool>(true);
    final deletingId = useState<String?>(null);

    useEffect(() {
      Future<void>(() async {
        isLoading.value = true;
        final failure = await notifier.fetchAddresses();
        if (failure != null && context.mounted) {
          _showFailure(context, failure);
        }
        if (context.mounted) {
          isLoading.value = false;
        }
      });
      return null;
    }, const []);

    Future<void> refresh() async {
      final failure = await notifier.fetchAddresses();
      if (failure != null && context.mounted) {
        _showFailure(context, failure);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addressesTitle),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!context.mounted) {
            return;
          }
          context.push('/addresses/add');
        },
        tooltip: l10n.addAddress,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: Builder(
            builder: (context) {
              if (isLoading.value) {
                return const LoadingIndicator();
              }
              if (addresses.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Text(
                          l10n.addressListEmpty,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  final subtitle = (address.instructions ?? '').trim().isEmpty
                      ? l10n.addressNoInstructions
                      : address.instructions!;
                  final isDeleting = deletingId.value == address.id;
                  return Card(
                    child: ListTile(
                      title: Text(
                        address.formatted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(subtitle),
                      onTap: () {
                        context.push('/addresses/edit', extra: address);
                      },
                      trailing: IconButton(
                        tooltip: l10n.delete,
                        onPressed: isDeleting
                            ? null
                            : () async {
                                final id = address.id;
                                if (id == null || id.isEmpty) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  _showFailure(
                                    context,
                                    const Failure(
                                      message: 'Address identifier is missing',
                                    ),
                                  );
                                  return;
                                }
                                deletingId.value = id;
                                final failure =
                                    await notifier.deleteAddress(id);
                                if (context.mounted) {
                                  deletingId.value = null;
                                  if (failure != null) {
                                    _showFailure(context, failure);
                                  } else {
                                    _showSnackBar(
                                      context,
                                      l10n.addressDeleted,
                                    );
                                  }
                                }
                              },
                        icon: isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFailure(BuildContext context, Failure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
