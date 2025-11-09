import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/venue_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/venue_notifier.dart';

class VenueList extends ConsumerStatefulWidget {
  const VenueList({
    super.key,
    required this.type,
    this.onVenueTap,
  });

  final String type;
  final ValueChanged<VenueModel>? onVenueTap;

  @override
  ConsumerState<VenueList> createState() => _VenueListState();
}

class _VenueListState extends ConsumerState<VenueList> {
  late final ScrollController _scrollController;
  late final NumberFormat _priceFormat;

  @override
  void initState() {
    super.initState();
    _priceFormat =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
    _scrollController = ScrollController()..addListener(_onScroll);
    ref.read(venueFiltersNotifierProvider.notifier).setType(widget.type);
  }

  @override
  void didUpdateWidget(covariant VenueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      ref.read(venueFiltersNotifierProvider.notifier).setType(widget.type);
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(venueNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    final venuesAsync = ref.watch(venueNotifierProvider);
    final filters = ref.watch(venueFiltersNotifierProvider);
    final notifier = ref.read(venueNotifierProvider.notifier);
    final isLoadingMore =
        venuesAsync.isLoading && (venuesAsync.valueOrNull?.isNotEmpty ?? false);

      return Column(
        children: [
          _FiltersBar(
            filters: filters,
            onReset: () => ref.read(venueFiltersNotifierProvider.notifier).reset(),
            onCuisineChanged: (value) =>
                ref.read(venueFiltersNotifierProvider.notifier).setCuisine(value),
            onRatingChanged: (value) => ref
                .read(venueFiltersNotifierProvider.notifier)
                .setMinRating(value),
            onPriceChanged: (value) => ref
                .read(venueFiltersNotifierProvider.notifier)
                .setMaxAvgPrice(value),
            onSortChanged: (sort) => ref
                .read(venueFiltersNotifierProvider.notifier)
                .setSort(sort),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final venues = _extractVenues(venuesAsync);
                final failure = _extractFailure(venuesAsync);
                final isInitialLoading =
                    venuesAsync.isLoading && venues.isEmpty && failure == null;
                final hasHardError = failure != null && venues.isEmpty;

                if (isInitialLoading) {
                  return const Center(child: LoadingIndicator());
                }

                if (hasHardError) {
                  return _ErrorRetry(
                    message: failure!.message,
                    onRetry: () => ref.invalidate(venueNotifierProvider),
                  );
                }

                if (venues.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref
                        .refresh(venueNotifierProvider.future)
                        .then((_) {}),
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        _EmptyVenues(message: l10n.noVenuesFound),
                      ],
                    ),
                  );
                }

                final hasMore = notifier.hasMore;
                final showLoadMore =
                    (hasMore && venues.isNotEmpty) || isLoadingMore;
                final itemCount = venues.length + (showLoadMore ? 1 : 0);
                final showErrorBanner = failure != null;

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(venueNotifierProvider.future).then((_) {}),
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (showErrorBanner)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ErrorBanner(
                            message: failure!.message,
                            onDismiss: () =>
                                ref.invalidate(venueNotifierProvider),
                          ),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= venues.length) {
                            return const _LoadMoreCard();
                          }
                          final venue = venues[index];
                          return _VenueCard(
                            venue: venue,
                            priceFormat: _priceFormat,
                            onTap: () => widget.onVenueTap?.call(venue),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filters,
    required this.onReset,
    required this.onCuisineChanged,
    required this.onRatingChanged,
    required this.onPriceChanged,
    required this.onSortChanged,
  });

  final VenueFilterState filters;
  final VoidCallback onReset;
  final ValueChanged<String?> onCuisineChanged;
  final ValueChanged<double?> onRatingChanged;
  final ValueChanged<double?> onPriceChanged;
  final ValueChanged<VenueSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisines = _cuisineOptions[filters.type] ?? const <String>[];
    final cuisineItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Все кухни')),
      ...cuisines.map(
        (cuisine) => DropdownMenuItem<String?>(
          value: cuisine,
          child: Text(_capitalize(cuisine)),
        ),
      ),
    ];
    final ratingItems = [
      const DropdownMenuItem<double?>(value: null, child: Text('Любой рейтинг')),
      const DropdownMenuItem<double?>(value: 3.5, child: Text('От 3.5')),
      const DropdownMenuItem<double?>(value: 4.0, child: Text('От 4.0')),
      const DropdownMenuItem<double?>(value: 4.5, child: Text('От 4.5')),
    ];
    final priceItems = [
      const DropdownMenuItem<double?>(value: null, child: Text('Любая цена')),
      const DropdownMenuItem<double?>(value: 500, child: Text('До 500 ₽')),
      const DropdownMenuItem<double?>(value: 1000, child: Text('До 1000 ₽')),
      const DropdownMenuItem<double?>(value: 1500, child: Text('До 1500 ₽')),
      const DropdownMenuItem<double?>(value: 2500, child: Text('До 2500 ₽')),
    ];

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Фильтры',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Сбросить'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    value: filters.cuisine,
                    items: cuisineItems,
                    decoration: const InputDecoration(
                      labelText: 'Кухня',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onCuisineChanged,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<double?>(
                    value: filters.minRating,
                    items: ratingItems,
                    decoration: const InputDecoration(
                      labelText: 'Рейтинг',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onRatingChanged,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<double?>(
                    value: filters.maxAvgPrice,
                    items: priceItems,
                    decoration: const InputDecoration(
                      labelText: 'Цена',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onPriceChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<VenueSort>(
                    value: filters.sort,
                    items: VenueSort.values
                        .map(
                          (sort) => DropdownMenuItem(
                            value: sort,
                            child: Text(sort.label),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (sort) {
                      if (sort != null) {
                        onSortChanged(sort);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.priceFormat,
    this.onTap,
  });

  final VenueModel venue;
  final NumberFormat priceFormat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = venue.photos.isNotEmpty ? venue.photos.first : null;
    final averageCheck = priceFormat.format(venue.averagePrice);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const _ImagePlaceholder(),
                            errorWidget: (context, url, error) =>
                                const _ImagePlaceholder(),
                          )
                        : const _ImagePlaceholder(),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: colorScheme.secondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            venue.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RatingBarIndicator(
                    rating: venue.rating,
                    itemBuilder: (context, index) => Icon(
                      Icons.star,
                      color: colorScheme.secondary,
                    ),
                    unratedColor: colorScheme.outlineVariant,
                    itemSize: 16,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    venue.cuisines.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Средний чек $averageCheck',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${venue.deliveryTimeMinutes} мин · ${venue.deliveryFee.toStringAsFixed(0)} ₽ доставка',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    venue.isOpen ? 'Открыто сейчас' : 'Закрыто',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: venue.isOpen
                          ? colorScheme.primary
                          : colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreCard extends StatelessWidget {
  const _LoadMoreCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LoadingIndicator(),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            color: color,
            tooltip: 'Закрыть',
          ),
        ],
      ),
    );
  }
}

class _EmptyVenues extends StatelessWidget {
  const _EmptyVenues({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.store_mall_directory_outlined,
        size: 42,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

const Map<String, List<String>> _cuisineOptions = {
  'food': [
    'европейская',
    'итальянская',
    'азиатская',
    'японская',
    'фастфуд',
    'здоровая',
  ],
  'flowers': [
    'классическая',
    'свадебная',
    'сезонная',
    'уютная',
  ],
};

List<VenueModel> _extractVenues(AsyncValue<List<VenueModel>> value) {
  if (value is AsyncData<List<VenueModel>>) {
    return value.value;
  }
  if (value is AsyncLoading<List<VenueModel>>) {
    return value.previous?.maybeWhen(
          data: (data) => data,
          orElse: () => const <VenueModel>[],
        ) ??
        const <VenueModel>[];
  }
  if (value is AsyncError<List<VenueModel>>) {
    return value.previous?.maybeWhen(
          data: (data) => data,
          orElse: () => const <VenueModel>[],
        ) ??
        const <VenueModel>[];
  }
  return const <VenueModel>[];
}

Failure? _extractFailure(AsyncValue<List<VenueModel>> value) {
  if (value is AsyncError<List<VenueModel>>) {
    final error = value.error;
    if (error is Failure) {
      return error;
    }
  }
  return null;
}
