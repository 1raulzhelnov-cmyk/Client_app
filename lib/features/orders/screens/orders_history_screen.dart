import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/order_model.dart';
import '../../../widgets/async_value_widget.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/orders_notifier.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() =>
      _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  String? _downloadingOrderId;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(ordersHistorySearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersValue = ref.watch(ordersHistoryProvider);
    final l10n = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderHistoryTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _applySearch(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchOrders,
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.cancel,
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersHistoryProvider);
                  await ref.read(ordersHistoryProvider.future);
                },
                child: AsyncValueWidget<List<OrderModel>>(
                  value: ordersValue,
                  loading: const _OrdersHistoryLoading(),
                  error: (error, _) => _OrdersHistoryError(
                    message: error is Failure ? error.message : l10n.errorGeneric,
                    onRetry: () => ref.invalidate(ordersHistoryProvider),
                  ),
                  data: (orders) => _OrdersHistoryList(
                    orders: orders,
                    onOrderTap: (order) =>
                        context.push('/orders/${order.id}/status'),
                    onDownloadReceipt: _downloadReceipt,
                    downloadingOrderId: _downloadingOrderId,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _applySearch);
    setState(() {});
  }

  void _applySearch() {
    if (!mounted) {
      return;
    }
    final query = _searchController.text;
    ref.read(ordersHistorySearchQueryProvider.notifier).state = query;
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    ref.read(ordersHistorySearchQueryProvider.notifier).state = '';
    setState(() {});
  }

  Future<void> _downloadReceipt(OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);
    setState(() {
      _downloadingOrderId = order.id;
    });

    try {
      final url = await ref.read(orderReceiptProvider(order.id).future);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.downloadReceipt}: $url'),
          duration: const Duration(seconds: 4),
        ),
      );
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.errorGeneric),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingOrderId = null;
        });
      }
    }
  }
}

class _OrdersHistoryList extends StatelessWidget {
  const _OrdersHistoryList({
    required this.orders,
    required this.onOrderTap,
    required this.onDownloadReceipt,
    required this.downloadingOrderId,
  });

  final List<OrderModel> orders;
  final ValueChanged<OrderModel> onOrderTap;
  final ValueChanged<OrderModel> onDownloadReceipt;
  final String? downloadingOrderId;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.orders,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isDownloading = downloadingOrderId == order.id;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.receipt_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(_orderTitle(order, l10n)),
            subtitle: Text(_orderSubtitle(order, l10n)),
            onTap: () => onOrderTap(order),
            trailing: isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: l10n.downloadReceipt,
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => onDownloadReceipt(order),
                  ),
          ),
        );
      },
    );
  }
}

class _OrdersHistoryLoading extends StatelessWidget {
  const _OrdersHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 220,
          child: Center(child: LoadingIndicator()),
        ),
      ],
    );
  }
}

class _OrdersHistoryError extends StatelessWidget {
  const _OrdersHistoryError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ],
    );
  }
}

String _orderTitle(OrderModel order, S l10n) {
  return '#${order.id} • ${_formatAmount(order.grandTotal, l10n)}';
}

String _orderSubtitle(OrderModel order, S l10n) {
  final status = _statusLabel(order.status, l10n);
  final locale = l10n.locale.languageCode;
  final formatter = DateFormat('d MMM yyyy, HH:mm', locale);
  final createdAt = formatter.format(order.createdAt.toLocal());
  return '$status • $createdAt';
}

String _formatAmount(double value, S l10n) =>
    '${value.toStringAsFixed(0)} ${l10n.currencyRub}';

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
