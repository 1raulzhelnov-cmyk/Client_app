import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../../models/flower_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/home_providers.dart';

class FlowerCatalog extends ConsumerWidget {
  const FlowerCatalog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowersState = ref.watch(flowerCatalogProvider);
    final l10n = S.of(context);

    return flowersState.when(
      data: (flowers) {
        if (flowers.isEmpty) {
          return _EmptyFlowers(message: l10n.noVenuesFound);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: flowers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final flower = flowers[index];
            return _FlowerCard(flower: flower);
          },
        );
      },
      loading: () => const Center(child: LoadingIndicator()),
      error: (error, _) => _EmptyFlowers(message: l10n.errorGeneric),
    );
  }
}

class _FlowerCard extends StatelessWidget {
  const _FlowerCard({required this.flower});

  final FlowerModel flower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.15),
                    colorScheme.secondary.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_florist_outlined,
                  size: 48,
                ),
              ),
            ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flower.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${flower.price.toStringAsFixed(0)} руб.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
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

class _EmptyFlowers extends StatelessWidget {
  const _EmptyFlowers({required this.message});

  final String message;

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
              Icons.local_florist_outlined,
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
        ),
      ),
    );
  }
}
