import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../widgets/search_bar.dart';
import '../widgets/venue_list.dart';
import '../../flowers/screens/flower_catalog_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = S.of(context);

    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: SearchBar(
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor:
                colorScheme.onSurface.withOpacity(0.6),
            indicatorColor: colorScheme.primary,
            tabs: [
              Tab(text: l10n.food),
              Tab(text: l10n.flowers),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VenueList(
              type: 'food',
              onVenueTap: (venue) => context.go('/venue/${venue.id}'),
            ),
            const FlowerCatalogScreen(),
          ],
        ),
      ),
    );
  }
}
