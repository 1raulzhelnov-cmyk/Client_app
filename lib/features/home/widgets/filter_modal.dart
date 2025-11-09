import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../providers/filter_notifier.dart';
import '../providers/venue_notifier.dart';

const double _priceMax = 1000;
const double _distanceMax = 50;
const List<String> _cuisineOptions = <String>[
  'italian',
  'asian',
  'japanese',
  'european',
  'fastfood',
  'healthy',
  'vegan',
];

Future<void> showFilterModal(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);
  final l10n = S.of(context);
  final currentFilters = ref.read(filterProvider);
  final initialCuisines = <String>{
    ..._splitCuisines(currentFilters['cuisines']?.toString()),
  };
  final initialMinPrice =
      (currentFilters['minPrice'] as num?)?.toDouble() ?? 0;
  final initialMaxPrice =
      (currentFilters['maxPrice'] as num?)?.toDouble() ?? _priceMax;
  final initialRating =
      (currentFilters['minRating'] as num?)?.toDouble() ?? 0;
  final initialDistance =
      (currentFilters['maxDistance'] as num?)?.toDouble() ?? 0;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final viewInsets = MediaQuery.of(context).viewInsets.bottom;

      var selectedCuisines = Set<String>.from(initialCuisines);
      var priceRange = RangeValues(
        initialMinPrice.clamp(0, _priceMax),
        initialMaxPrice.clamp(0, _priceMax),
      );
      if (priceRange.end < priceRange.start) {
        priceRange = RangeValues(priceRange.start, priceRange.start);
      }
      var minRating = initialRating.clamp(0, 5);
      var maxDistance = initialDistance.clamp(0, _distanceMax);

      return Padding(
        padding: EdgeInsets.only(
          bottom: viewInsets,
        ),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return _FilterContent(
                theme: theme,
                l10n: l10n,
                selectedCuisines: selectedCuisines,
                priceRange: priceRange,
                minRating: minRating,
                maxDistance: maxDistance,
                onCuisineToggle: (cuisine) {
                  setState(() {
                    if (selectedCuisines.contains(cuisine)) {
                      selectedCuisines.remove(cuisine);
                    } else {
                      selectedCuisines.add(cuisine);
                    }
                  });
                },
                onPriceChanged: (range) {
                  setState(() {
                    priceRange = range;
                  });
                },
                onRatingChanged: (rating) {
                  setState(() {
                    minRating = rating;
                  });
                },
                onDistanceChanged: (distance) {
                  setState(() {
                    maxDistance = distance;
                  });
                },
                onApply: () async {
                  final notifier = ref.read(filterProvider.notifier);
                  notifier.setCuisine(selectedCuisines.toList());
                  if (priceRange.start <= 0 && priceRange.end >= _priceMax) {
                    notifier.setPriceRange(0, 0);
                  } else {
                    notifier.setPriceRange(priceRange.start, priceRange.end);
                  }
                  notifier.setRating(minRating <= 0 ? null : minRating);
                  notifier.setDistance(maxDistance <= 0 ? null : maxDistance);
                  await notifier.save();
                  ref
                    ..invalidate(venueNotifierProvider)
                    ..refresh(venueNotifierProvider.future);
                  Navigator.of(context).pop();
                },
                onClear: () async {
                  final notifier = ref.read(filterProvider.notifier);
                  await notifier.clear();
                  ref
                    ..invalidate(venueNotifierProvider)
                    ..refresh(venueNotifierProvider.future);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      );
    },
  );
}

class _FilterContent extends StatelessWidget {
  const _FilterContent({
    required this.theme,
    required this.l10n,
    required this.selectedCuisines,
    required this.priceRange,
    required this.minRating,
    required this.maxDistance,
    required this.onCuisineToggle,
    required this.onPriceChanged,
    required this.onRatingChanged,
    required this.onDistanceChanged,
    required this.onApply,
    required this.onClear,
  });

  final ThemeData theme;
  final S l10n;
  final Set<String> selectedCuisines;
  final RangeValues priceRange;
  final double minRating;
  final double maxDistance;
  final ValueChanged<String> onCuisineToggle;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<double> onDistanceChanged;
  final FutureOr<void> Function() onApply;
  final FutureOr<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.filterTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Кухня',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _cuisineOptions.map((cuisine) {
              final isSelected = selectedCuisines.contains(cuisine);
              return ChoiceChip(
                label: Text(_capitalize(cuisine)),
                selected: isSelected,
                onSelected: (_) => onCuisineToggle(cuisine),
                selectedColor: colorScheme.primary.withOpacity(0.15),
                labelStyle: textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Ценовой диапазон',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          RangeSlider(
            values: priceRange,
            min: 0,
            max: _priceMax,
            divisions: _priceMax ~/ 50,
            labels: RangeLabels(
              priceRange.start.round().toString(),
              priceRange.end.round().toString(),
            ),
            onChanged: onPriceChanged,
          ),
          Text(
            'От ${priceRange.start.round()} ₽ до ${priceRange.end.round()} ₽',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Рейтинг',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              RatingBar.builder(
                initialRating: minRating,
                minRating: 0,
                maxRating: 5,
                allowHalfRating: true,
                glow: false,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemSize: 28,
                unratedColor: colorScheme.outlineVariant,
                itemBuilder: (context, _) => Icon(
                  Icons.star,
                  color: colorScheme.secondary,
                ),
                onRatingUpdate: onRatingChanged,
              ),
              const SizedBox(width: 12),
              Text(
                minRating <= 0
                    ? 'Любой'
                    : minRating.toStringAsFixed(minRating.truncateToDouble() == minRating ? 0 : 1),
                style: textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Расстояние',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Slider(
            value: maxDistance,
            min: 0,
            max: _distanceMax,
            divisions: _distanceMax.toInt(),
            label: maxDistance == 0
                ? 'Любое'
                : '${maxDistance.toStringAsFixed(maxDistance % 1 == 0 ? 0 : 1)} км',
            onChanged: onDistanceChanged,
          ),
          Text(
            maxDistance <= 0
                ? 'Любое расстояние'
                : 'До ${maxDistance.toStringAsFixed(maxDistance % 1 == 0 ? 0 : 1)} км',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => unawaited(onClear()),
                  child: Text(l10n.clearFilters),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => unawaited(onApply()),
                  child: Text(l10n.applyFilters),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Iterable<String> _splitCuisines(String? value) {
  if (value == null || value.isEmpty) {
    return const <String>[];
  }
  return value
      .split(',')
      .map((cuisine) => cuisine.trim())
      .where((cuisine) => cuisine.isNotEmpty);
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
