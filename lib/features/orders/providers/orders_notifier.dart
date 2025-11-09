import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/order_model.dart';

final ordersHistorySearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

final ordersHistoryProvider =
    AutoDisposeFutureProvider<List<OrderModel>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final query = ref.watch(ordersHistorySearchQueryProvider);

  final trimmed = query.trim();
  final queryParameters =
      trimmed.isEmpty ? null : <String, String>{'search': trimmed};

  final result = await apiService.get<dynamic>(
    '/orders/history',
    queryParameters: queryParameters,
  );

  return result.fold(
    (failure) => throw failure,
    (data) {
      final orders = _parseOrders(data);
      if (orders == null) {
        throw const ParsingFailure(
          message: 'Не удалось загрузить историю заказов',
        );
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    },
  );
});

final orderReceiptProvider =
    AutoDisposeFutureProvider.family<String, String>((ref, orderId) async {
  final apiService = ref.read(apiServiceProvider);
  final normalizedId = orderId.trim();
  if (normalizedId.isEmpty) {
    throw const Failure(message: 'Некорректный идентификатор заказа');
  }

  final result = await apiService.get<dynamic>(
    '/orders/$normalizedId/receipt',
  );

  return result.fold(
    (failure) => throw failure,
    (data) {
      final url = _extractReceiptUrl(data);
      if (url == null || url.isEmpty) {
        throw const ParsingFailure(
          message: 'Ссылка на чек не найдена',
        );
      }
      return url;
    },
  );
});

List<OrderModel>? _parseOrders(dynamic payload) {
  if (payload == null) {
    return <OrderModel>[];
  }

  if (payload is List) {
    final orders = <OrderModel>[];
    for (final raw in payload) {
      if (raw is Map) {
        try {
          orders.add(
            OrderModel.fromJson(
              Map<String, dynamic>.from(raw as Map),
            ),
          );
        } catch (_) {
          return null;
        }
      }
    }
    return orders;
  }

  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    for (final key in const [
      'orders',
      'data',
      'items',
      'result',
      'payload',
      'history',
    ]) {
      final nested = map[key];
      final parsed = _parseOrders(nested);
      if (parsed != null) {
        return parsed;
      }
    }
  }

  return null;
}

String? _extractReceiptUrl(dynamic payload) {
  if (payload == null) {
    return null;
  }

  if (payload is String) {
    return payload.trim();
  }

  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    for (final key in const [
      'url',
      'link',
      'receiptUrl',
      'downloadUrl',
      'href',
    ]) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final value in map.values) {
      final nested = _extractReceiptUrl(value);
      if (nested != null && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
  }

  if (payload is List) {
    for (final item in payload) {
      final nested = _extractReceiptUrl(item);
      if (nested != null && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
  }

  return null;
}
