import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../../models/venue_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/home_providers.dart';

class VenueList extends ConsumerWidget {
  const VenueList({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesState = ref.watch(venueListProvider(type));
    final l10n = S.of(context);

    return venuesState.when(
      data: (venues) {
        if (venues.isEmpty) {
          return _EmptyVenues(message: l10n.noVenuesFound);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: venues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final venue = venues[index];
            return _VenueCard(venue: venue);
          },
        );
      },
      loading: () => const Center(child: LoadingIndicator()),
      error: (error, _) => _EmptyVenues(message: l10n.errorGeneric),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final VenueModel venue;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withOpacity(0.12),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    venue.name.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue.cuisines.join(' • '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          venue.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue.isOpen ? 'Открыто' : 'Закрыто',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: venue.isOpen
                            ? colorScheme.primary
                            : colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '${venue.deliveryTimeMinutes} мин',
                ),
                _InfoChip(
                  icon: Icons.delivery_dining_outlined,
                  label: '${venue.deliveryFee.toStringAsFixed(0)} руб.',
                ),
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: 'Средний чек ${venue.averagePrice.toStringAsFixed(0)} руб.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              venue.address.formatted,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(label),
      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
        ),
      ),
    );
  }
}
