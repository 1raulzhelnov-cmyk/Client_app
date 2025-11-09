import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/product_model.dart';
import '../../../widgets/loading_indicator.dart';
import '../providers/product_notifier.dart';

class MenuCatalog extends ConsumerStatefulWidget {
  const MenuCatalog({
    super.key,
    required this.venueId,
    required this.isMenu,
    this.initialProducts = const <ProductModel>[],
    this.onAddToCart,
    this.onCustomizeProduct,
  });

  final String venueId;
  final bool isMenu;
  final List<ProductModel> initialProducts;
  final ValueChanged<ProductModel>? onAddToCart;
  final ValueChanged<ProductModel>? onCustomizeProduct;

  @override
  ConsumerState<MenuCatalog> createState() => _MenuCatalogState();
}

class _MenuCatalogState extends ConsumerState<MenuCatalog> {
  late final TextEditingController _searchController;
  late final NumberFormat _priceFormat;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _priceFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _query = value.trim();
    });
  }

  void _clearSearch() {
    if (_query.isEmpty) {
      return;
    }
    _searchController.clear();
    setState(() {
      _query = '';
    });
    FocusScope.of(context).unfocus();
  }

  void _handleProductAction(ProductModel product) {
    if (!product.available) {
      _showMessage(S.of(context).unavailable);
      return;
    }

    if (product.customizations.isNotEmpty &&
        widget.onCustomizeProduct != null) {
      widget.onCustomizeProduct!(product);
      return;
    }

    if (widget.onAddToCart != null) {
      widget.onAddToCart!(product);
      return;
    }

    if (product.customizations.isNotEmpty) {
      _showMessage(S.of(context).customize);
      return;
    }

    _showMessage(S.of(context).addToCart);
  }

  void _showMessage(String message) {
    if (message.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final asyncProducts = ref.watch(productProvider(widget.venueId));

    final fallbackSections = widget.initialProducts.isEmpty
        ? const <MenuCategoryGroup>[]
        : buildMenuSections(
            filterMenuProducts(widget.initialProducts, _query),
            l10n.otherCategory,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isMenu
                        ? Icons.restaurant_menu
                        : Icons.shopping_bag_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isMenu ? l10n.menuTab : l10n.catalogTab,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                        ),
                  hintText: l10n.searchPlaceholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        asyncProducts.when(
          data: (products) {
            final filtered = filterMenuProducts(products, _query);
            final sections = buildMenuSections(
              filtered,
              l10n.otherCategory,
            );
            return _CatalogSections(
              sections: sections,
              priceFormat: _priceFormat,
              onProductTap: _handleProductAction,
              query: _query,
              onClearQuery: _clearSearch,
            );
          },
          loading: () {
            if (fallbackSections.isNotEmpty) {
              return _CatalogSections(
                sections: fallbackSections,
                priceFormat: _priceFormat,
                onProductTap: _handleProductAction,
                query: _query,
                onClearQuery: _clearSearch,
                isLoading: true,
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: LoadingIndicator()),
            );
          },
          error: (error, stackTrace) {
            final message = error is Failure
                ? error.message
                : l10n.errorGeneric;
            if (fallbackSections.isNotEmpty) {
              return _CatalogSections(
                sections: fallbackSections,
                priceFormat: _priceFormat,
                onProductTap: _handleProductAction,
                query: _query,
                onClearQuery: _clearSearch,
                errorMessage: message,
              );
            }
            return _MenuCatalogError(
              message: message,
              onRetry: () => ref.invalidate(productProvider(widget.venueId)),
            );
          },
        ),
      ],
    );
  }
}

class _CatalogSections extends StatelessWidget {
  const _CatalogSections({
    required this.sections,
    required this.priceFormat,
    required this.onProductTap,
    required this.query,
    required this.onClearQuery,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<MenuCategoryGroup> sections;
  final NumberFormat priceFormat;
  final ValueChanged<ProductModel> onProductTap;
  final String query;
  final VoidCallback onClearQuery;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);

    if (sections.isEmpty) {
      final headline = query.isEmpty ? l10n.unavailable : l10n.noVenuesFound;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Icon(
              query.isEmpty ? Icons.menu_book_outlined : Icons.search_off,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.searchPlaceholder,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onClearQuery,
                icon: const Icon(Icons.clear),
                label: Text(l10n.clearFilters),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _InlineError(message: errorMessage!),
          ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: LinearProgressIndicator(),
          ),
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final section = sections[index];
            return _CategoryTile(
              section: section,
              priceFormat: priceFormat,
              onProductTap: onProductTap,
            );
          },
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.section,
    required this.priceFormat,
    required this.onProductTap,
  });

  final MenuCategoryGroup section;
  final NumberFormat priceFormat;
  final ValueChanged<ProductModel> onProductTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: PageStorageKey<String>('menu-${section.title}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      title: Text(
        section.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: section.products
          .map(
            (product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ProductCard(
                product: product,
                priceFormat: priceFormat,
                onAddToCart: () => onProductTap(product),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.priceFormat,
    required this.onAddToCart,
  });

  final ProductModel product;
  final NumberFormat priceFormat;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = S.of(context);
    final priceText = priceFormat.format(product.price);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(imageUrl: product.imageUrl),
            const SizedBox(width: 12),
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
                    priceText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!product.available) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.unavailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (product.customizations.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.customize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.addToCart,
              onPressed: onAddToCart,
              icon: Icon(
                Icons.add_shopping_cart_outlined,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 80,
        width: 80,
        child: imageUrl.isEmpty
            ? Container(
                color: colorScheme.surfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  Icons.fastfood_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colorScheme.surfaceVariant,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _MenuCatalogError extends StatelessWidget {
  const _MenuCatalogError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
List<ProductModel> filterMenuProducts(
  List<ProductModel> products,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return List<ProductModel>.from(products);
  }
  return products.where((product) {
    final name = product.name.toLowerCase();
    final description = product.description.toLowerCase();
    final category = (product.category ?? '').toLowerCase();
    return name.contains(normalized) ||
        description.contains(normalized) ||
        category.contains(normalized);
  }).toList();
}

@visibleForTesting
List<MenuCategoryGroup> buildMenuSections(
  List<ProductModel> products,
  String fallbackCategory,
) {
  if (products.isEmpty) {
    return const <MenuCategoryGroup>[];
  }
  final grouped = <String, List<ProductModel>>{};
  for (final product in products) {
    final rawCategory = product.category?.trim();
    final category =
        (rawCategory == null || rawCategory.isEmpty) ? fallbackCategory : rawCategory;
    grouped.putIfAbsent(category, () => <ProductModel>[]).add(product);
  }

  return grouped.entries.map((entry) {
    final sorted = List<ProductModel>.from(entry.value)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return MenuCategoryGroup(
      title: entry.key,
      products: sorted,
    );
  }).toList()
    ..sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
}

class MenuCategoryGroup {
  const MenuCategoryGroup({
    required this.title,
    required this.products,
  });

  final String title;
  final List<ProductModel> products;
}
