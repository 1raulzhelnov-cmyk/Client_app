import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/venue_model.dart';

final venueDetailProvider =
    AutoDisposeFutureProvider.family<VenueModel, String>((ref, id) async {
  final apiService = ref.read(apiServiceProvider);
  final result = await apiService.get<Map<String, dynamic>>('/venues/$id');
  return result.fold(
    (failure) => throw failure,
    (data) {
      final venueMap = _extractVenueMap(data);
      if (venueMap == null) {
        const parsingFailure = ParsingFailure(
          message: 'Не удалось загрузить данные заведения',
        );
        throw parsingFailure;
      }
      return VenueModel.fromJson(venueMap);
    },
  );
});

Map<String, dynamic>? _extractVenueMap(Map<String, dynamic>? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }

  Map<String, dynamic>? tryParse(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }

  final direct = tryParse(payload);
  if (direct != null && direct.containsKey('id')) {
    return direct;
  }

  for (final key in const [
    'venue',
    'data',
    'result',
    'payload',
  ]) {
    final value = payload[key];
    final parsed = tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }

  for (final value in payload.values) {
    final parsed = tryParse(value);
    if (parsed != null &&
        parsed.containsKey('id') &&
        parsed.containsKey('name')) {
      return parsed;
    }
  }

  return null;
}
