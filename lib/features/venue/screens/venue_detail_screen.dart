import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/product_model.dart';
import '../../../models/venue_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/venue_detail_notifier.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  const VenueDetailScreen({
    super.key,
    required this.venueId,
  });

  final String venueId;

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueState = ref.watch(venueDetailProvider(widget.venueId));
    return Scaffold(
      body: venueState.when(
        data: (venue) => _VenueDetailView(
          venue: venue,
          pageController: _pageController,
          currentImageIndex: _currentImageIndex,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          onRefresh: () async {
            await ref.refresh(venueDetailProvider(widget.venueId).future);
          },
        ),
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stackTrace) {
          final message = error is Failure ? error.message : error.toString();
          return _VenueDetailError(
            message: message,
            onRetry: () => ref.invalidate(venueDetailProvider(widget.venueId)),
          );
        },
      ),
    );
  }
}

class _VenueDetailView extends StatelessWidget {
  const _VenueDetailView({
    required this.venue,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
    required this.onRefresh,
  });

  final VenueModel venue;
  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = S.of(context);
    final images = venue.photos.isEmpty
        ? const <String>[]
        : List<String>.from(venue.photos);
    final isOpen = venue.isOpen;
    final addressText = venue.address.formatted;
    final hasDescription =
        venue.description != null && venue.description!.trim().isNotEmpty;
    final ratingsTheme = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final hoursEntries = venue.hours.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final contactsEntries = venue.contacts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final priceFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final deliveryFeeText = '${venue.deliveryFee.toStringAsFixed(0)} ₽';
    final averageCheckText = priceFormat.format(venue.averagePrice);

    final menuSections = _groupProductsByCategory(
      venue.type == VenueType.food ? venue.menu : venue.catalog,
      l10n,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            leading: const BackButton(),
            title: Text(
              venue.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    _GalleryPlaceholder(
                      colorScheme: colorScheme,
                    )
                  else
                    PageView.builder(
                      controller: pageController,
                      itemCount: images.length,
                      onPageChanged: onPageChanged,
                      itemBuilder: (context, index) {
                        final imageUrl = images[index];
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              _GalleryPlaceholder(colorScheme: colorScheme),
                          errorWidget: (context, url, error) =>
                              _GalleryPlaceholder(colorScheme: colorScheme),
                        );
                      },
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: _GalleryIndicator(
                        current: currentImageIndex,
                        total: images.length,
                        colorScheme: colorScheme,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RatingBarIndicator(
                            rating: venue.rating,
                            itemSize: 20,
                            unratedColor: colorScheme.outlineVariant,
                            itemBuilder: (context, index) => Icon(
                              Icons.star_rounded,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            venue.rating.toStringAsFixed(1),
                            style: ratingsTheme,
                          ),
                          const SizedBox(width: 16),
                          _OpenBadge(
                            isOpen: isOpen,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.etaLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            venue.deliveryTimeMinutes,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.paid_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$deliveryFeeText · $averageCheckText',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (hasDescription) ...[
                        Text(
                          venue.description!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _SectionTitle(
                        title: l10n.workingHours,
                        icon: Icons.access_time,
                      ),
                      const SizedBox(height: 8),
                      if (hoursEntries.isEmpty)
                        Text(
                          l10n.unavailable,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: hoursEntries
                              .map(
                                (entry) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    '${entry.key}: ${entry.value}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: l10n.contactInfo,
                        icon: Icons.contact_phone_outlined,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ContactRow(
                            icon: Icons.place_outlined,
                            label: addressText,
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          ...contactsEntries.map(
                            (entry) => _ContactRow(
                              icon: _contactIcon(entry.key),
                              label: entry.value,
                              theme: theme,
                              colorScheme: colorScheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (menuSections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _MenuCatalogSection(
                      sections: menuSections,
                      isMenu: venue.type == VenueType.food,
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

class _MenuCatalogSection extends StatefulWidget {
  const _MenuCatalogSection({
    required this.sections,
    required this.isMenu,
  });

  final List<_ProductSection> sections;
  final bool isMenu;

  @override
  State<_MenuCatalogSection> createState() => _MenuCatalogSectionState();
}

class _MenuCatalogSectionState extends State<_MenuCatalogSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.sections.length,
      vsync: this,
    )..addListener(_handleTabChanged);
  }

  @override
  void didUpdateWidget(covariant _MenuCatalogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections.length != widget.sections.length) {
      _tabController
        ..removeListener(_handleTabChanged)
        ..dispose();
      _tabController = TabController(
        length: widget.sections.length,
        vsync: this,
      )..addListener(_handleTabChanged);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted && _tabController.indexIsChanging == false) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.sections.isEmpty) {
      final l10n = S.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: widget.isMenu ? l10n.menuTab : l10n.catalogTab,
              icon: Icons.list_alt_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.unavailable,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final currentSection = widget.sections[_tabController.index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTitle(
            title:
                widget.isMenu ? S.of(context).menuTab : S.of(context).catalogTab,
            icon: Icons.list_alt_outlined,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: widget.sections
                .map(
                  (section) => Tab(text: section.title),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentSection.products.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final product = currentSection.products[index];
            return _ProductTile(product: product);
          },
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surfaceVariant,
          ),
          alignment: Alignment.center,
          child: product.imageUrl.isEmpty
              ? Icon(
                  Icons.fastfood_outlined,
                  color: colorScheme.onSurfaceVariant,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    width: 72,
                    height: 72,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceVariant,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.fastfood_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${product.price.toStringAsFixed(0)} ₽',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (!product.available)
                Text(
                  S.of(context).unavailable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueDetailError extends StatelessWidget {
  const _VenueDetailError({
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
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({
    required this.isOpen,
    required this.colorScheme,
    required this.theme,
  });

  final bool isOpen;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final background = isOpen
        ? colorScheme.primary.withOpacity(0.1)
        : colorScheme.error.withOpacity(0.1);
    final color = isOpen ? colorScheme.primary : colorScheme.error;
    final text = isOpen ? 'Открыто' : 'Закрыто';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GalleryIndicator extends StatelessWidget {
  const _GalleryIndicator({
    required this.current,
    required this.total,
    required this.colorScheme,
  });

  final int current;
  final int total;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '${current + 1}/$total',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceVariant,
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ProductSection {
  const _ProductSection({
    required this.title,
    required this.products,
  });

  final String title;
  final List<ProductModel> products;
}

List<_ProductSection> _groupProductsByCategory(
  List<ProductModel> products,
  S l10n,
) {
  if (products.isEmpty) {
    return const [];
  }
  final grouped = <String, List<ProductModel>>{};
  for (final product in products) {
    final key = (product.category?.trim().isNotEmpty ?? false)
        ? product.category!.trim()
        : l10n.otherCategory;
    grouped.putIfAbsent(key, () => <ProductModel>[]).add(product);
  }
  final sections = grouped.entries
      .map(
        (entry) => _ProductSection(
          title: entry.key,
          products: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));
  return sections;
}

IconData _contactIcon(String key) {
  switch (key.toLowerCase()) {
    case 'phone':
    case 'tel':
    case 'telephone':
      return Icons.phone_outlined;
    case 'email':
      return Icons.email_outlined;
    case 'website':
    case 'site':
    case 'url':
      return Icons.link_outlined;
    case 'instagram':
    case 'telegram':
    case 'whatsapp':
      return Icons.chat_bubble_outline;
    default:
      return Icons.info_outline;
  }
}
