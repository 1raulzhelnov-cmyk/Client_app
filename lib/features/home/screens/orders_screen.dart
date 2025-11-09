import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../../models/order_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/home_providers.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(ordersProvider);
    final l10n = S.of(context);

    return SafeArea(
      child: ordersState.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _OrdersEmpty(message: l10n.orders);
          }

          final theme = Theme.of(context);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.orders,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(order: order);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, _) => _OrdersEmpty(message: l10n.errorGeneric),
      ),
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(colorScheme, order.status);
    final createdAt = order.createdAt;
    final formattedDate =
        '${_twoDigits(createdAt.day)}.${_twoDigits(createdAt.month)}.${createdAt.year} '
        '${_twoDigits(createdAt.hour)}:${_twoDigits(createdAt.minute)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.id}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${order.grandTotal.toStringAsFixed(0)} руб.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(order.status.name),
                  backgroundColor: statusColor.withOpacity(0.12),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: statusColor.withOpacity(0.4)),
                ),
                if (order.eta != null)
                  Chip(
                    label: Text(
                      'ETA ${_twoDigits(order.eta!.hour)}:${_twoDigits(order.eta!.minute)}',
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.08),
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.address.formatted,
              style: theme.textTheme.bodyMedium,
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                order.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme, OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return colorScheme.primary;
      case OrderStatus.preparing:
      case OrderStatus.confirmed:
      case OrderStatus.transit:
        return colorScheme.secondary;
      case OrderStatus.placed:
      default:
        return colorScheme.tertiary;
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
