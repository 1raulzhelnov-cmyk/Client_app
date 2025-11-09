import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/order_model.dart';

final orderStatusProvider =
    AutoDisposeStreamProvider.family<OrderModel, String>((ref, orderId) {
  final normalizedId = orderId.trim();
  return ref.read(firestoreServiceProvider).getOrderStream(normalizedId);
});

final orderStatusNotifier = Provider<OrderStatusNotifier>((ref) {
  return OrderStatusNotifier(ref);
});

class OrderStatusNotifier {
  OrderStatusNotifier(this.ref);

  final Ref ref;

  Future<Failure?> cancelOrder(String orderId, String reason) async {
    final normalizedId = orderId.trim();
    if (normalizedId.isEmpty) {
      return const Failure(
        message: 'Некорректный идентификатор заказа',
      );
    }
    final payload = <String, dynamic>{'reason': reason};

    final apiService = ref.read(apiServiceProvider);
    try {
      final result = await apiService.post<dynamic>(
        '/orders/$normalizedId/cancel',
        body: payload,
      );

      return result.fold(
        (failure) => failure,
        (_) {
          ref.invalidate(orderStatusProvider(normalizedId));
          return null;
        },
      );
    } on Failure catch (failure) {
      return failure;
    } catch (error) {
      return Failure(message: error.toString());
    }
  }
}
