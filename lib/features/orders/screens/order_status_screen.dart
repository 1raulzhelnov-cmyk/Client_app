import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/order_model.dart';
import '../../../widgets/async_value_widget.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/order_status_notifier.dart';
import '../widgets/cancel_modal.dart';

class OrderStatusScreen extends ConsumerStatefulWidget {
  const OrderStatusScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen> {
  OrderModel? _lastKnownOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final orderValue = ref.watch(orderStatusProvider(widget.orderId));
    final fallbackOrder = _lastKnownOrder;
    final OrderModel? currentOrder = orderValue.maybeWhen(
      data: (order) => order,
      orElse: () => fallbackOrder,
    );
    final showCancelAction = currentOrder != null;
    final isCancelEnabled =
        currentOrder != null && _isCancellationAllowed(currentOrder);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderStatusTitle),
        actions: [
          if (showCancelAction)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: l10n.cancelOrder,
              onPressed: isCancelEnabled
                  ? () => _showCancellationSheet(currentOrder!)
                  : null,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AsyncValueWidget<OrderModel>(
            value: orderValue,
            loading: fallbackOrder != null
                ? _OrderStatusContent(
                    order: fallbackOrder,
                    l10n: l10n,
                  )
                : const Center(child: LoadingIndicator()),
            error: (error, _) {
              final cachedOrder = fallbackOrder;
              if (cachedOrder != null) {
                return _OrderStatusContent(
                  order: cachedOrder,
                  l10n: l10n,
                );
              }
              final message =
                  error is Failure ? error.message : l10n.errorGeneric;
              return _OrderStatusError(
                message: message,
                onRetry: () => ref.invalidate(
                  orderStatusProvider(widget.orderId),
                ),
              );
            },
            data: (order) {
              _lastKnownOrder = order;
              return _OrderStatusContent(
                order: order,
                l10n: l10n,
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isCancellationAllowed(OrderModel order) {
    return order.status == OrderStatus.placed ||
        order.status == OrderStatus.confirmed;
  }

  bool _isOrderPaid(OrderModel order) =>
      order.paymentMethod.toLowerCase() != 'cash';

  Future<void> _showCancellationSheet(OrderModel order) async {
    final isPaid = _isOrderPaid(order);
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => CancelModal(
        orderId: order.id,
        isPaid: isPaid,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == true) {
      final l10n = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.statusCancelled),
        ),
      );
    }
  }
}
class _OrderStatusContent extends StatelessWidget {
  const _OrderStatusContent({
    required this.order,
    required this.l10n,
  });

  final OrderModel order;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _OrderHeader(
          order: order,
          l10n: l10n,
        ),
        const SizedBox(height: 24),
        _OrderTimeline(
          currentStatus: order.status,
          l10n: l10n,
        ),
        const SizedBox(height: 24),
        _DeliveryInfo(
          order: order,
          l10n: l10n,
        ),
        const SizedBox(height: 24),
        _OrderItemsSection(
          order: order,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.order,
    required this.l10n,
  });

  final OrderModel order;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = l10n.localeName;
    final format = DateFormat('d MMM, HH:mm', locale);
    final createdAtText = format.format(order.createdAt.toLocal());
    final etaText =
        order.eta != null ? format.format(order.eta!.toLocal()) : '—';
    final progress = order.statusProgress.clamp(0, 1);
    final statusLabel = _statusLabel(order.status, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '#${order.id}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: colorScheme.surfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                statusLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              createdAtText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '${l10n.etaLabel}: $etaText',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({
    required this.currentStatus,
    required this.l10n,
  });

  final OrderStatus currentStatus;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final stages = _stages(l10n, currentStatus);
    var currentIndex =
        stages.indexWhere((stage) => stage.status == currentStatus);
    if (currentIndex == -1) {
      currentIndex = stages.isEmpty ? 0 : stages.length - 1;
    }
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < stages.length; i++)
              _TimelineItem(
                label: stages[i].label,
                isCompleted: i <= currentIndex,
                isCurrent: i == currentIndex,
                isLast: i == stages.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = isCompleted ? colorScheme.primary : colorScheme.outline;
    final textStyle = isCurrent
        ? theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: activeColor,
                size: 20,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isCompleted
                      ? activeColor
                      : colorScheme.outlineVariant.withOpacity(0.6),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: isLast ? 2 : 0),
              child: Text(
                label,
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({
    required this.order,
    required this.l10n,
  });

  final OrderModel order;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = l10n.localeName;
    final format = DateFormat('d MMM, HH:mm', locale);
    final updatedAt = order.updatedAt ?? order.createdAt;
    final updatedAtText = format.format(updatedAt.toLocal());

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.address.formatted,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.update),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${updatedAtText}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.notes!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderItemsSection extends StatelessWidget {
  const _OrderItemsSection({
    required this.order,
    required this.l10n,
  });

  final OrderModel order;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.orderSummary,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _OrderItemRow(item: item, l10n: l10n),
              ),
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.itemsLabel,
              value: _formatAmount(order.total, l10n),
            ),
            if (order.deliveryFee > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: l10n.deliveryFeeLabel,
                value: _formatAmount(order.deliveryFee, l10n),
              ),
            ],
            if (order.cashFee > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: l10n.cashFeeApplied,
                value: _formatAmount(order.cashFee, l10n),
              ),
            ],
            const SizedBox(height: 12),
            _SummaryRow(
              label: l10n.total,
              value: _formatAmount(order.grandTotal, l10n),
              emphasised: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.l10n,
  });

  final CartItemModel item;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final additionals = item.selectedCustomizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${item.quantity} × ${item.product.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.subtotal.toStringAsFixed(0)} ${l10n.currencyRub}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (additionals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            additionals.map((option) => option.name).join(', '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
        if (item.note != null && item.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.note!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasised
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _OrderStatusError extends StatelessWidget {
  const _OrderStatusError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _OrderStage {
  const _OrderStage({
    required this.status,
    required this.label,
  });

  final OrderStatus status;
  final String label;
}

List<_OrderStage> _stages(S l10n, OrderStatus currentStatus) {
  if (currentStatus == OrderStatus.cancelled) {
    return [
      _OrderStage(status: OrderStatus.placed, label: l10n.statusPlaced),
      _OrderStage(status: OrderStatus.cancelled, label: l10n.statusCancelled),
    ];
  }
  return [
    _OrderStage(status: OrderStatus.placed, label: l10n.statusPlaced),
    _OrderStage(status: OrderStatus.confirmed, label: l10n.statusConfirmed),
    _OrderStage(status: OrderStatus.preparing, label: l10n.statusPreparing),
    _OrderStage(status: OrderStatus.transit, label: l10n.statusTransit),
    _OrderStage(status: OrderStatus.delivered, label: l10n.statusDelivered),
  ];
}

String _statusLabel(OrderStatus status, S l10n) {
  switch (status) {
    case OrderStatus.placed:
      return l10n.statusPlaced;
    case OrderStatus.confirmed:
      return l10n.statusConfirmed;
    case OrderStatus.preparing:
      return l10n.statusPreparing;
    case OrderStatus.transit:
      return l10n.statusTransit;
    case OrderStatus.delivered:
      return l10n.statusDelivered;
    case OrderStatus.cancelled:
      return l10n.statusCancelled;
  }
}

String _formatAmount(double value, S l10n) =>
    '${value.toStringAsFixed(0)} ${l10n.currencyRub}';
