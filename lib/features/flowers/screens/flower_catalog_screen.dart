import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/flower_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/flower_notifier.dart';

class FlowerCatalogScreen extends ConsumerStatefulWidget {
  const FlowerCatalogScreen({super.key});

  @override
  ConsumerState<FlowerCatalogScreen> createState() =>
      _FlowerCatalogScreenState();
}

class _FlowerTabConfig {
  const _FlowerTabConfig({
    required this.labelBuilder,
    required this.occasion,
    this.isSeasonal = false,
  });

  final String Function(S l10n) labelBuilder;
  final String occasion;
  final bool isSeasonal;
}

const _seasonKeys = <String>['spring', 'summer', 'autumn', 'winter'];

class _FlowerCatalogScreenState extends ConsumerState<FlowerCatalogScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <_FlowerTabConfig>[
    _FlowerTabConfig(
      labelBuilder: (l10n) => l10n.flowerOccasionBirthday,
      occasion: 'birthday',
    ),
    _FlowerTabConfig(
      labelBuilder: (l10n) => l10n.flowerOccasionWedding,
      occasion: 'wedding',
    ),
    _FlowerTabConfig(
      labelBuilder: (l10n) => l10n.flowerOccasionSeasonal,
      occasion: 'seasonal',
      isSeasonal: true,
    ),
  ];

  late final TabController _tabController;
  String _selectedSeason = _seasonKeys.first;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleSeasonSelected(String season) {
    if (_selectedSeason == season) {
      return;
    }
    setState(() {
      _selectedSeason = season;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.flowerCatalogTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.flowerCatalogSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor:
              colorScheme.onSurfaceVariant.withOpacity(0.7),
          indicatorColor: colorScheme.primary,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: tab.labelBuilder(l10n),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              if (tab.isSeasonal) {
                return _SeasonalTab(
                  selectedSeason: _selectedSeason,
                  onSeasonSelected: _handleSeasonSelected,
                );
              }
              return FlowerCatalogList(
                query: FlowerQuery(occasion: tab.occasion),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SeasonalTab extends StatelessWidget {
  const _SeasonalTab({
    required this.selectedSeason,
    required this.onSeasonSelected,
  });

  final String selectedSeason;
  final ValueChanged<String> onSeasonSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.flowerSeasonalSubtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _seasonKeys.map((key) {
                  final label = _localizedSeason(key, l10n);
                  final isSelected = selectedSeason == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => onSeasonSelected(key),
                    selectedColor:
                        theme.colorScheme.primary.withOpacity(0.2),
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FlowerCatalogList(
            query: FlowerQuery(
              occasion: 'seasonal',
              season: selectedSeason,
            ),
          ),
        ),
      ],
    );
  }
}

class FlowerCatalogList extends ConsumerWidget {
  const FlowerCatalogList({
    super.key,
    required this.query,
  });

  final FlowerQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final asyncFlowers = ref.watch(flowerProvider(query));

    return asyncFlowers.when(
      data: (flowers) {
        if (flowers.isEmpty) {
          return _FlowerEmptyState(message: l10n.flowerEmptyState);
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(flowerProvider(query).future),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.68,
            ),
            itemCount: flowers.length,
            itemBuilder: (context, index) {
              final flower = flowers[index];
              return _FlowerCard(
                flower: flower,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: LoadingIndicator()),
      error: (error, stackTrace) {
        final failure = error is Failure ? error : null;
        final message = failure?.message ?? l10n.flowerErrorState;
        return _FlowerErrorState(
          message: message,
          onRetry: () => ref.invalidate(flowerProvider(query)),
        );
      },
    );
  }
}

class _FlowerCard extends StatelessWidget {
  _FlowerCard({required this.flower})
      : _priceFormat = NumberFormat.currency(
          locale: 'ru_RU',
          symbol: '₽',
          decimalDigits: 0,
        );

  final FlowerModel flower;
  final NumberFormat _priceFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = S.of(context);
    final occasionLabel = _localizedOccasion(flower.occasion, l10n);
    final seasonLabel = _localizedSeason(flower.season, l10n);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FlowerImage(imageUrl: flower.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flower.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flower.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (occasionLabel.isNotEmpty)
                      _InfoChip(
                        icon: Icons.event,
                        label: occasionLabel,
                      ),
                    if (seasonLabel.isNotEmpty)
                      _InfoChip(
                        icon: Icons.wb_sunny_outlined,
                        label: seasonLabel,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _priceFormat.format(flower.price),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (flower.careInstructions != null &&
                    flower.careInstructions!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.spa_outlined,
                          size: 18,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            flower.careInstructions!.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerImage extends StatelessWidget {
  const _FlowerImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.11),
            colorScheme.secondary.withOpacity(0.09),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: imageUrl.isEmpty
          ? Center(
              child: Icon(
                Icons.local_florist_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: colorScheme.surfaceVariant,
              ),
              errorWidget: (context, url, error) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerEmptyState extends StatelessWidget {
  const _FlowerEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_florist_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowerErrorState extends StatelessWidget {
  const _FlowerErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
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
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

String _localizedSeason(String? value, S l10n) {
  switch (value?.toLowerCase().trim()) {
    case 'spring':
      return l10n.flowerSeasonSpring;
    case 'summer':
      return l10n.flowerSeasonSummer;
    case 'autumn':
    case 'fall':
      return l10n.flowerSeasonAutumn;
    case 'winter':
      return l10n.flowerSeasonWinter;
    default:
      return value?.trim() ?? '';
  }
}

String _localizedOccasion(String? value, S l10n) {
  switch (value?.toLowerCase().trim()) {
    case 'birthday':
      return l10n.flowerOccasionBirthday;
    case 'wedding':
      return l10n.flowerOccasionWedding;
    case 'anniversary':
      return l10n.flowerOccasionAnniversary;
    case 'seasonal':
      return l10n.flowerOccasionSeasonal;
    case 'congratulations':
    case 'celebration':
      return l10n.flowerOccasionCelebration;
    default:
      return value?.trim() ?? '';
  }
}
