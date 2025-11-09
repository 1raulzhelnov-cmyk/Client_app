import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

typedef FilterState = Map<String, dynamic>;

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>(FilterNotifier.new);

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier(this._ref) : super(const {}) {
    unawaited(_restore());
  }

  static const String _prefsKey = 'filters';

  final Ref _ref;

  Future<void> _restore() async {
    try {
      final prefs = await _ref.read(sharedPrefsProvider.future);
      final payload = prefs.getString(_prefsKey);
      if (payload == null || payload.isEmpty) {
        return;
      }
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        state = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Проглатываем ошибки восстановления, чтобы не ломать поток выполнения.
    }
  }

  void setQuery(String? query) {
    final trimmed = query?.trim() ?? '';
    _updateState('query', trimmed.isEmpty ? null : trimmed);
  }

  void setCuisine(List<String> cuisines) {
    final normalized = cuisines.where((c) => c.trim().isNotEmpty).toList();
    _updateState(
      'cuisines',
      normalized.isEmpty ? null : normalized.join(','),
    );
  }

  void setPriceRange(double min, double max) {
    final clampedMin = min.clamp(0, max);
    final clampedMax = max.clamp(clampedMin, double.infinity);
    _updateState('minPrice', clampedMin <= 0 ? null : clampedMin);
    _updateState('maxPrice', clampedMax <= 0 ? null : clampedMax);
  }

  void setRating(double? minRating) {
    final value = (minRating ?? 0) <= 0 ? null : minRating;
    _updateState('minRating', value);
  }

  void setDistance(double? maxDistance) {
    final value = (maxDistance ?? 0) <= 0 ? null : maxDistance;
    _updateState('maxDistance', value);
  }

  Future<void> save() async {
    await _persist();
  }

  Future<void> clear() async {
    state = const {};
    await _persist();
  }

  void _updateState(String key, dynamic value) {
    final next = Map<String, dynamic>.from(state);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = next;
  }

  Future<void> _persist() async {
    try {
      final prefs = await _ref.read(sharedPrefsProvider.future);
      if (state.isEmpty) {
        await prefs.remove(_prefsKey);
        return;
      }
      final sanitized = state.map((key, value) {
        if (value is double) {
          return MapEntry(key, double.parse(value.toStringAsFixed(2)));
        }
        return MapEntry(key, value);
      });
      await prefs.setString(_prefsKey, jsonEncode(sanitized));
    } catch (_) {
      // Игнорируем ошибки сохранения, чтобы не блокировать UX.
    }
  }
}
