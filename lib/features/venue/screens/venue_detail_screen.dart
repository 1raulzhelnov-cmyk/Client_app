import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/customization_model.dart';
import '../../../models/customization_option.dart';
import '../../../models/product_model.dart';
import '../../../models/review_model.dart';
import '../../../models/venue_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../../cart/providers/cart_notifier.dart';
import '../../cart/widgets/customization_modal.dart';
import '../providers/venue_detail_notifier.dart';
import '../widgets/menu_catalog.dart';
import '../../orders/providers/review_notifier.dart';

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

  Future<void> _addProductToCart(
    BuildContext context,
    ProductModel product, {
    CustomizationSelection? selection,
  }) async {
    final notifier = ref.read(cartUpdateNotifier.notifier);
    final l10n = S.of(context);
    final selectedOptions =
        selection?.selectedOptions ?? const <CustomizationOption>[];
    final note = selection?.instructions?.trim();
    try {
      await notifier.addItem(
        product,
        1,
        selectedOptions,
        note: note == null || note.isEmpty ? null : note,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context, '${product.name} — ${l10n.addToCart}');
    } on Failure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, l10n.errorGeneric);
    }
  }

  Future<void> _customizeProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final customization =
        CustomizationModel.fromOptions(product.customizations);
    if (!customization.hasOptions) {
      await _addProductToCart(context, product);
      return;
    }
    final selection = await showCustomizationModal(
      context: context,
      productName: product.name,
      customization: customization,
    );
    if (!mounted || selection == null) {
      return;
    }
    await _addProductToCart(context, product, selection: selection);
  }

  void _showSnackBar(BuildContext context, String message) {
    if (message.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
          onAddToCart: (product) => _addProductToCart(context, product),
          onCustomizeProduct: (product) =>
              _customizeProduct(context, product),
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

class _VenueDetailView extends ConsumerWidget {
  const _VenueDetailView({
    required this.venue,
    required this.pageController,
    required this.currentImageIndex,
    required this.onPageChanged,
    required this.onRefresh,
    required this.onAddToCart,
    required this.onCustomizeProduct,
  });

  final VenueModel venue;
  final PageController pageController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<ProductModel> onAddToCart;
  final ValueChanged<ProductModel> onCustomizeProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = S.of(context);
    final images = venue.photos.isEmpty
        ? const <String>[]
        : List<String>.from(venue.photos);
    final reviewsValue = ref.watch(venueReviewsProvider(venue.id));
    final reviewsCount = reviewsValue.maybeWhen(
      data: (reviews) => reviews.length,
      orElse: () => 0,
    );
    final averageRating = reviewsValue.maybeWhen(
      data: (reviews) {
        if (reviews.isEmpty) {
          return venue.rating;
        }
        final total =
            reviews.fold<int>(0, (sum, review) => sum + review.stars);
        return total / reviews.length;
      },
      orElse: () => venue.rating,
    );
    final displayRating = reviewsCount > 0 ? averageRating : venue.rating;
    final clampedRating = displayRating.clamp(0, 5);
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
    final initialProducts =
        venue.type == VenueType.food ? venue.menu : venue.catalog;

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
                              rating: clampedRating,
                              itemSize: 20,
                              unratedColor: colorScheme.outlineVariant,
                              itemBuilder: (context, index) => Icon(
                                Icons.star_rounded,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              clampedRating.toStringAsFixed(1),
                              style: ratingsTheme,
                            ),
                            if (reviewsCount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                l10n.reviewsCountLabel(reviewsCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
                        _ReviewsSection(
                          reviewsValue: reviewsValue,
                          averageRating: displayRating,
                          reviewsCount: reviewsCount,
                          l10n: l10n,
                          onRetry: () =>
                              ref.invalidate(venueReviewsProvider(venue.id)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: MenuCatalog(
                      venueId: venue.id,
                      isMenu: venue.type == VenueType.food,
                      initialProducts: initialProducts,
                      onAddToCart: onAddToCart,
                      onCustomizeProduct: onCustomizeProduct,
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

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviewsValue,
    required this.averageRating,
    required this.reviewsCount,
    required this.l10n,
    required this.onRetry,
  });

  final AsyncValue<List<ReviewModel>> reviewsValue;
  final double averageRating;
  final int reviewsCount;
  final S l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final ratingValue = averageRating.clamp(0, 5);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RatingBarIndicator(
                  rating: ratingValue,
                  itemCount: 5,
                  itemSize: 18,
                  unratedColor: colorScheme.outlineVariant,
                  itemBuilder: (context, index) => Icon(
                    Icons.star_rounded,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ratingValue.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.reviewsCountLabel(reviewsCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            reviewsValue.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Text(
                    l10n.reviewsEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _ReviewCard(
                    review: reviews[index],
                    l10n: l10n,
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: LoadingIndicator()),
              ),
              error: (error, _) {
                final message = error is Failure
                    ? error.message
                    : l10n.errorGeneric;
                return _ReviewsError(
                  message: message,
                  onRetry: onRetry,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.l10n,
  });

  final ReviewModel review;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = (review.userName ?? '').trim().isEmpty
        ? l10n.reviewsAnonymous
        : review.userName!.trim();
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '•';
    final createdAt = review.createdAt;
    final dateText = createdAt != null
        ? DateFormat('d MMM yyyy', l10n.localeName)
            .format(createdAt.toLocal())
        : '';
    final ratingValue = review.stars.clamp(0, 5).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Text(
                initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            RatingBarIndicator(
              rating: ratingValue,
              itemSize: 16,
              unratedColor: colorScheme.outlineVariant,
              itemBuilder: (context, index) => Icon(
                Icons.star_rounded,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ),
        if (review.hasText) ...[
          const SizedBox(height: 12),
          Text(
            review.text ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
        if (review.hasPhotos) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: review.photoUrls
                .map((url) => _ReviewPhotoThumbnail(imageUrl: url))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ReviewPhotoThumbnail extends StatelessWidget {
  const _ReviewPhotoThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 96,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: colorScheme.surfaceVariant,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: colorScheme.surfaceVariant,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewsError extends StatelessWidget {
  const _ReviewsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
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
