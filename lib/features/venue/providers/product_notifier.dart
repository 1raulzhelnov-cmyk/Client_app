import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/product_model.dart';

final productProvider =
    AutoDisposeFutureProvider.family<List<ProductModel>, String>(
  (ref, venueId) async {
    final apiService = ref.read(apiServiceProvider);
    final result = await apiService.get<dynamic>(
      '/products',
      queryParameters: <String, String>{'venueId': venueId},
    );

    return result.fold(
      (failure) => throw failure,
      (data) {
        final products = _parseProducts(data);
        if (products == null) {
          throw const ParsingFailure(
            message: 'Не удалось загрузить меню заведения',
          );
        }
        final sorted = List<ProductModel>.from(products)
          ..sort((a, b) {
            final categoryA = (a.category ?? '').toLowerCase();
            final categoryB = (b.category ?? '').toLowerCase();
            final categoryCompare = categoryA.compareTo(categoryB);
            if (categoryCompare != 0) {
              return categoryCompare;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return sorted;
      },
    );
  },
);

List<ProductModel>? _parseProducts(dynamic payload) {
  if (payload is List) {
    return payload
        .whereType<Map>()
        .map(
          (item) => ProductModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    // Прямой ответ { products: [...] }
    for (final key in const [
      'products',
      'items',
      'data',
      'result',
      'payload',
    ]) {
      final nested = map[key];
      final parsed = _parseProducts(nested);
      if (parsed != null) {
        return parsed;
      }
    }

    // Ответ в виде словаря { id: {...}, id2: {...} }
    final values = map.values.toList();
    if (values.isNotEmpty && values.every((value) => value is Map)) {
      return values
          .map(
            (value) => ProductModel.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }
  }

  return null;
}
