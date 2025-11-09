import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../models/order_model.dart';

final orderStatusProvider =
    AutoDisposeStreamProvider.family<OrderModel, String>((ref, orderId) {
  final normalizedId = orderId.trim();
  return ref.read(firestoreServiceProvider).getOrderStream(normalizedId);
});
