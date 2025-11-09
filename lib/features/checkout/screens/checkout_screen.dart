import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/address_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../widgets/app_button.dart';
import '../../address/providers/address_notifier.dart';
import '../../home/providers/home_providers.dart';
import '../providers/checkout_notifier.dart';

class CheckoutScreen extends HookConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final checkoutState = ref.watch(checkoutProvider);
    final addresses = ref.watch(addressNotifierProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final termsAccepted = useState(false);
    final isLoadingAddresses = useState(false);
    final selectedAddress = useState<AddressModel?>(
      checkoutState.hasSelectedAddress ? checkoutState.order.address : null,
    );

    useEffect(() {
      Future<void>(() async {
        isLoadingAddresses.value = true;
        final failure =
            await ref.read(addressNotifierProvider.notifier).fetchAddresses();
        if (context.mounted) {
          isLoadingAddresses.value = false;
          if (failure != null) {
            _showFailure(context, failure);
          }
        }
      });
      return null;
    }, const []);

    useEffect(() {
      if (!checkoutState.hasSelectedAddress) {
        return null;
      }
      final current = checkoutState.order.address;
      final selected = selectedAddress.value;
      final isSame = selected != null &&
          selected.id == current.id &&
          selected.formatted == current.formatted;
      if (!isSame) {
        selectedAddress.value = current;
      }
      return null;
    }, [checkoutState.order.address]);

    useEffect(() {
      if (addresses.isEmpty || selectedAddress.value != null) {
        return null;
      }
      final defaultAddress = _resolveInitialAddress(addresses);
      if (defaultAddress != null) {
        selectedAddress.value = defaultAddress;
        Future<void>(() {
          ref.read(checkoutProvider.notifier).setAddress(defaultAddress);
        });
      }
      return null;
    }, [addresses.length]);

    ref.listen<CheckoutState>(
      checkoutProvider,
      (previous, next) {
        final error = next.error;
        if (error != null && error != previous?.error) {
          _showFailure(context, error);
        }
      },
    );

    final items = checkoutState.order.items;
    final total = checkoutState.order.total +
        checkoutState.order.deliveryFee +
        checkoutState.order.cashFee;
    final isButtonEnabled =
        termsAccepted.value && checkoutState.canSubmit && !checkoutState.isPlacing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkoutTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isLoadingAddresses.value || checkoutState.isPlacing)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: [
                    Text(
                      l10n.selectAddress,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AddressModel>(
                      value: selectedAddress.value,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      items: addresses
                          .map(
                            (address) => DropdownMenuItem<AddressModel>(
                              value: address,
                              child: Text(
                                address.formatted,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        selectedAddress.value = value;
                        ref.read(checkoutProvider.notifier).setAddress(value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return l10n.requiredField;
                        }
                        return null;
                      },
                    ),
                    if (addresses.isEmpty && !isLoadingAddresses.value) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.addressListEmpty,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      l10n.orderSummary,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      _EmptyCartPlaceholder(message: l10n.emptyCart)
                    else
                      _OrderSummaryList(items: items),
                    const SizedBox(height: 16),
                    _SummaryTotals(
                      total: total,
                      deliveryFee: checkoutState.order.deliveryFee,
                      cashFee: checkoutState.order.cashFee,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 24),
                    _EtaSection(
                      etaLabel: checkoutState.etaLabel,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: termsAccepted.value,
                      onChanged: (value) {
                        termsAccepted.value = value ?? false;
                      },
                      title: Text(
                        l10n.termsAcceptance,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppButton(
                label: l10n.placeOrder,
                isLoading: checkoutState.isPlacing,
                onPressed: isButtonEnabled
                    ? () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        final failure = await ref
                            .read(checkoutProvider.notifier)
                            .placeOrder(etaLabel: checkoutState.etaLabel);
                        if (failure != null) {
                          return;
                        }
                        if (!context.mounted) {
                          return;
                        }
                        _showSnackBar(context, l10n.orderPlaced);
                        ref.read(navProvider.notifier).state = 2;
                        context.go('/');
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailure(BuildContext context, Failure failure) {
    _showSnackBar(context, failure.message);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  AddressModel? _resolveInitialAddress(List<AddressModel> addresses) {
    if (addresses.isEmpty) {
      return null;
    }
    final defaultAddress =
        addresses.where((address) => address.isDefault).toList();
    if (defaultAddress.isNotEmpty) {
      return defaultAddress.first;
    }
    return addresses.first;
  }
}

class _OrderSummaryList extends StatelessWidget {
  const _OrderSummaryList({required this.items});

  final List<CartItemModel> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} × ${item.product.price.toStringAsFixed(0)} руб.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.subtotal.toStringAsFixed(0)} руб.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryTotals extends StatelessWidget {
  const _SummaryTotals({
    required this.total,
    required this.l10n,
  });

  final double total;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(
              label: l10n.total,
              value: '${total.toStringAsFixed(0)} руб.',
              isEmphasised: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasised = false,
  });

  final String label;
  final String value;
  final bool isEmphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = isEmphasised
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(value, style: textStyle),
      ],
    );
  }
}

class _EtaSection extends StatelessWidget {
  const _EtaSection({
    required this.etaLabel,
    required this.l10n,
  });

  final String? etaLabel;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primary.withOpacity(0.08),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.etaLabel,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etaLabel ?? '—',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartPlaceholder extends StatelessWidget {
  const _EmptyCartPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: Row(
          children: [
            const Icon(Icons.shopping_cart_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
