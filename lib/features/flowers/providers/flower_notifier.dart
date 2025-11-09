import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/flower_model.dart';

class FlowerQuery {
  const FlowerQuery({
    this.occasion,
    this.season,
    this.search,
    this.limit,
  });

  final String? occasion;
  final String? season;
  final String? search;
  final int? limit;

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'type': 'flowers',
    };
    if (occasion != null && occasion!.isNotEmpty) {
      params['occasion'] = occasion!.toLowerCase();
    }
    if (season != null && season!.isNotEmpty) {
      params['season'] = season!.toLowerCase();
    }
    if (search != null && search!.trim().isNotEmpty) {
      params['search'] = search!.trim();
    }
    if (limit != null && limit! > 0) {
      params['limit'] = limit!.toString();
    }
    return params;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FlowerQuery &&
        other.occasion == occasion &&
        other.season == season &&
        other.search == search &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(occasion, season, search, limit);

  FlowerQuery copyWith({
    String? occasion,
    String? season,
    String? search,
    int? limit,
  }) {
    return FlowerQuery(
      occasion: occasion ?? this.occasion,
      season: season ?? this.season,
      search: search ?? this.search,
      limit: limit ?? this.limit,
    );
  }
}

const _defaultFlowerLimit = 50;

final flowerProvider =
    AutoDisposeFutureProvider.family<List<FlowerModel>, FlowerQuery>(
  (ref, query) async {
    final apiService = ref.read(apiServiceProvider);
    final params = query.toQueryParameters();
    params.putIfAbsent('limit', () => _defaultFlowerLimit.toString());

    final result = await apiService.get<dynamic>(
      '/products',
      queryParameters: params,
    );

    return result.fold(
      (failure) => throw failure,
      (data) {
        final flowers = _parseFlowers(data);
        if (flowers == null) {
          throw const ParsingFailure(
            message: 'Не удалось загрузить каталог цветов',
          );
        }
        flowers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return flowers;
      },
    );
  },
);

List<FlowerModel>? _parseFlowers(dynamic payload) {
  if (payload is List) {
    return payload
        .whereType<Map>()
        .map(
          (item) => FlowerModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    for (final key in const [
      'flowers',
      'items',
      'products',
      'data',
      'result',
      'payload',
    ]) {
      final nested = map[key];
      final parsed = _parseFlowers(nested);
      if (parsed != null) {
        return parsed;
      }
    }

    final values = map.values.toList();
    if (values.isNotEmpty && values.every((value) => value is Map)) {
      return values
          .map(
            (value) => FlowerModel.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    }
  }
  return null;
}
