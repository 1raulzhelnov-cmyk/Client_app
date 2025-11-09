import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/venue_model.dart';
import 'filter_notifier.dart';

enum VenueSort { ratingDesc, priceAsc }

extension VenueSortX on VenueSort {
  String get label {
    switch (this) {
      case VenueSort.ratingDesc:
        return 'По рейтингу';
      case VenueSort.priceAsc:
        return 'По цене';
    }
  }

  String get queryValue {
    switch (this) {
      case VenueSort.ratingDesc:
        return 'rating_desc';
      case VenueSort.priceAsc:
        return 'price_asc';
    }
  }
}

class VenueFilterState {
  const VenueFilterState({
    this.type = 'food',
    this.cuisine,
    this.minRating,
    this.maxAvgPrice,
    this.search,
    this.sort = VenueSort.ratingDesc,
    this.limit = 20,
  });

  final String type;
  final String? cuisine;
  final double? minRating;
  final double? maxAvgPrice;
  final String? search;
  final VenueSort sort;
  final int limit;

  Map<String, String> toQueryParameters() {
    final map = <String, String>{
      'type': type,
      'sort': sort.queryValue,
      'limit': limit.toString(),
    };
    if (cuisine != null && cuisine!.isNotEmpty) {
      map['cuisine'] = cuisine!;
    }
    if (minRating != null && minRating! > 0) {
      map['minRating'] = minRating!.toStringAsFixed(1);
    }
    if (maxAvgPrice != null && maxAvgPrice! > 0) {
      map['maxPrice'] = maxAvgPrice!.toStringAsFixed(0);
    }
    if (search != null && search!.trim().isNotEmpty) {
      map['search'] = search!.trim();
    }
    return map;
  }

  VenueFilterState copyWith({
    String? type,
    String? cuisine,
    double? minRating,
    double? maxAvgPrice,
    String? search,
    VenueSort? sort,
    int? limit,
  }) {
    return VenueFilterState(
      type: type ?? this.type,
      cuisine: cuisine ?? this.cuisine,
      minRating: minRating ?? this.minRating,
      maxAvgPrice: maxAvgPrice ?? this.maxAvgPrice,
      search: search ?? this.search,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VenueFilterState &&
        other.type == type &&
        other.cuisine == cuisine &&
        other.minRating == minRating &&
        other.maxAvgPrice == maxAvgPrice &&
        other.search == search &&
        other.sort == sort &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
        type,
        cuisine,
        minRating,
        maxAvgPrice,
        search,
        sort,
        limit,
      );
}

class VenueFiltersNotifier extends AutoDisposeNotifier<VenueFilterState> {
  @override
  VenueFilterState build() => const VenueFilterState();

  void setType(String type) {
    if (state.type == type) {
      return;
    }
    state = VenueFilterState(type: type, sort: state.sort, limit: state.limit);
  }

  void setCuisine(String? cuisine) {
    state = state.copyWith(cuisine: cuisine);
  }

  void setMinRating(double? rating) {
    state = state.copyWith(minRating: rating);
  }

  void setMaxAvgPrice(double? price) {
    state = state.copyWith(maxAvgPrice: price);
  }

  void setSearch(String? text) {
    state = state.copyWith(search: text);
  }

  void setSort(VenueSort sort) {
    state = state.copyWith(sort: sort);
  }

  void setLimit(int limit) {
    state = state.copyWith(limit: limit);
  }

  void reset() {
    state = VenueFilterState(type: state.type);
  }
}

final venueFiltersNotifierProvider =
    AutoDisposeNotifierProvider<VenueFiltersNotifier, VenueFilterState>(
  VenueFiltersNotifier.new,
);

final venueFilterProvider = Provider<Map<String, String>>((ref) {
  final filters = ref.watch(venueFiltersNotifierProvider);
  final modalFilters = ref.watch(filterProvider);
  final params = filters.toQueryParameters();
  params.addAll(_modalFiltersToQuery(modalFilters));
  return params;
});

final venueNotifierProvider =
    AutoDisposeAsyncNotifierProvider<VenueNotifier, List<VenueModel>>(
  VenueNotifier.new,
);

class VenueNotifier extends AutoDisposeAsyncNotifier<List<VenueModel>> {
  static const int _defaultLimit = 20;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Map<String, String> _currentFilters = const {};

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<VenueModel>> build() async {
    final filters = Map<String, String>.from(ref.watch(venueFilterProvider));
    filters.putIfAbsent('limit', () => _defaultLimit.toString());

    if (!const MapEquality<String, String>().equals(filters, _currentFilters)) {
      _currentPage = 1;
      _hasMore = true;
    }

    _currentFilters = Map.unmodifiable(filters);

    final cached = await _loadFromCache(filters);
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
    }

    final venues = await fetchVenues(filters, page: 1);
    _currentPage = 1;
    return venues;
  }

  Future<List<VenueModel>> fetchVenues(
    Map<String, String> filters, {
    int page = 1,
  }) async {
    final apiService = ref.read(apiServiceProvider);

    final params = Map<String, String>.from(filters);
    params['page'] = page.toString();
    params.putIfAbsent('limit', () => _defaultLimit.toString());

    final result = await apiService.get<Map<String, dynamic>>(
      '/venues',
      queryParameters: params,
    );

    return await result.fold<Future<List<VenueModel>>>(
      (failure) async {
        if (page == 1) {
          final cached = await _loadFromCache(filters);
          if (cached.isNotEmpty) {
            _hasMore = cached.length >=
                (int.tryParse(params['limit'] ?? '') ?? _defaultLimit);
            return cached;
          }
        }
        throw failure;
      },
      (data) async {
        try {
          final rawList = data['venues'] as List<dynamic>? ?? const [];
          final venues = rawList
              .map(
                (dynamic item) => VenueModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
          final limit =
              int.tryParse(params['limit'] ?? '') ?? _defaultLimit;

          final pagination = data['pagination'] as Map<String, dynamic>?;
          final bool hasNext = pagination?['hasNext'] as bool? ??
              data['hasMore'] as bool? ??
              (venues.length == limit);

          _hasMore = hasNext;

          if (page == 1 && venues.isNotEmpty) {
            await _saveToCache(filters, venues);
          }

          return venues;
        } catch (error, stackTrace) {
          final failure = ParsingFailure(
            message: 'Не удалось обработать данные заведений',
            statusCode: data['statusCode'] as int?,
          );
          Error.throwWithStackTrace(failure, stackTrace);
        }
      },
    );
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    final currentData = state.value ?? <VenueModel>[];
    state = AsyncValue<List<VenueModel>>.loading(
      previous: AsyncData(currentData),
    );
    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final newItems = await fetchVenues(_currentFilters, page: nextPage);
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        final updated = <VenueModel>[...currentData, ...newItems];
        state = AsyncData(updated);
        await _saveToCache(_currentFilters, updated);
      }
    } on Failure catch (failure, stackTrace) {
      state = AsyncError(
        failure,
        stackTrace,
        previous: AsyncData(currentData),
      );
    } catch (error, stackTrace) {
      state = AsyncError(
        Failure(message: error.toString()),
        stackTrace,
        previous: AsyncData(currentData),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<List<VenueModel>> _loadFromCache(
    Map<String, String> filters,
  ) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final cached = prefs.getString(_cacheKey(filters));
    if (cached == null) {
      return const [];
    }
    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => VenueModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveToCache(
    Map<String, String> filters,
    List<VenueModel> venues,
  ) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final payload = jsonEncode(
      venues.map((venue) => venue.toJson()).toList(),
    );
    await prefs.setString(_cacheKey(filters), payload);
  }

  String _cacheKey(Map<String, String> filters) {
    final entries = filters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final serialized = entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'venues_cache_$serialized';
  }
}

Map<String, String> _modalFiltersToQuery(FilterState filters) {
  if (filters.isEmpty) {
    return const {};
  }
  final result = <String, String>{};

  void putIfPresent(String key, dynamic value, String Function(dynamic) mapper) {
    if (value == null) {
      return;
    }
    result[key] = mapper(value);
  }

  if (filters.containsKey('query')) {
    final value = filters['query']?.toString().trim();
    if (value != null && value.isNotEmpty) {
      result['search'] = value;
    }
  }

  putIfPresent('cuisines', filters['cuisines'], (value) => value.toString());
  putIfPresent('minPrice', filters['minPrice'], (value) {
    if (value is num) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  });
  putIfPresent('maxPrice', filters['maxPrice'], (value) {
    if (value is num) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  });
  putIfPresent('minRating', filters['minRating'], (value) {
    if (value is num) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  });
  putIfPresent('maxDistance', filters['maxDistance'], (value) {
    if (value is num) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  });

  return result;
}
