import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/customization_option.dart';
import '../../../widgets/async_value_widget.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/loading_indicator.dart';
import '../../home/providers/home_providers.dart';
import '../providers/cart_notifier.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartValue = ref.watch(cartNotifierProvider);
    final l10n = S.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AsyncValueWidget<List<CartItemModel>>(
          value: cartValue,
          loading: const Center(child: LoadingIndicator()),
          error: (error, _) => CartEmptyState(
            message: l10n.errorGeneric,
            onActionPressed: () =>
                ref.read(navProvider.notifier).state = 0,
          ),
          data: (items) {
            if (items.isEmpty) {
              return CartEmptyState(
                message: l10n.emptyCart,
                onActionPressed: () =>
                    ref.read(navProvider.notifier).state = 0,
              );
            }

            final theme = Theme.of(context);
            final cartUpdate = ref.read(cartUpdateNotifier.notifier);
            final total = items.fold<double>(
              0,
              (previousValue, item) => previousValue + item.subtotal,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.cartTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CartItemTile(
                        item: item,
                        onQuantityChanged: (quantity) =>
                            _handleQuantityChange(
                          context,
                          cartUpdate,
                          item,
                          quantity,
                        ),
                        onRemove: () => _handleRemove(
                          context,
                          cartUpdate,
                          item,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.total,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(0)} руб.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: AppButton(
                    label: l10n.checkout,
                    onPressed: () => context.push('/checkout'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleQuantityChange(
    BuildContext context,
    CartUpdateNotifier notifier,
    CartItemModel item,
    int quantity,
  ) async {
    final l10n = S.of(context);
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) {
      _showError(context, l10n.errorGeneric);
      return;
    }
    try {
      await notifier.updateQty(itemId, quantity);
    } on Failure catch (error) {
      _showError(context, error.message);
    } catch (_) {
      _showError(context, l10n.errorGeneric);
    }
  }

  Future<void> _handleRemove(
    BuildContext context,
    CartUpdateNotifier notifier,
    CartItemModel item,
  ) async {
    final l10n = S.of(context);
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) {
      _showError(context, l10n.errorGeneric);
      return;
    }
    try {
      await notifier.removeItem(itemId);
    } on Failure catch (error) {
      _showError(context, error.message);
    } catch (_) {
      _showError(context, l10n.errorGeneric);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    super.key,
  });

  final CartItemModel item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    final product = item.product;
    final customizations = item.selectedCustomizations;
    final hasCustomizations = customizations.isNotEmpty;
    final note = item.note;
    final hasNote = note != null && note.trim().isNotEmpty;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primary.withOpacity(0.08),
              ),
              child: product.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.shopping_bag_outlined,
                      color: theme.colorScheme.primary,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                            if (hasCustomizations) ...[
                              const SizedBox(height: 6),
                              _CustomizationChips(options: customizations),
                            ],
                            if (hasNote) ...[
                              const SizedBox(height: 6),
                              Text(
                                note!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onRemove,
                        tooltip: l10n.delete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CartQuantityStepper(
                        quantity: item.quantity,
                        onChanged: (value) {
                          if (value < 1) {
                            onRemove();
                          } else {
                            onQuantityChanged(value);
                          }
                        },
                      ),
                      Text(
                        '${item.subtotal.toStringAsFixed(0)} руб.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomizationChips extends StatelessWidget {
  const _CustomizationChips({required this.options});

  final List<CustomizationOption> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options
          .map(
            (option) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                option.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({
    required this.quantity,
    required this.onChanged,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperIconButton(
            icon: Icons.remove,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: theme.textTheme.titleMedium,
            ),
          ),
          _StepperIconButton(
            icon: Icons.add,
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class CartEmptyState extends StatelessWidget {
  const CartEmptyState({
    required this.message,
    required this.onActionPressed,
    super.key,
  });

  final String message;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/app_icon.png',
              width: 96,
              height: 96,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: l10n.home,
              onPressed: onActionPressed,
            ),
          ],
        ),
      ),
    );
  }
}

