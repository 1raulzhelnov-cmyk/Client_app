import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../providers/filter_notifier.dart';
import '../providers/venue_notifier.dart';
import 'filter_modal.dart';

class SearchBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const SearchBar({
    super.key,
    this.bottom,
  });

  final PreferredSizeWidget? bottom;

  @override
  ConsumerState<SearchBar> createState() => _SearchBarState();

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}

class _SearchBarState extends ConsumerState<SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _lastSyncedQuery = '';

  @override
  void initState() {
    super.initState();
    final initialQuery =
        ref.read(filterProvider)['query']?.toString() ?? '';
    _lastSyncedQuery = initialQuery;
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode();

    ref.listen<FilterState>(
      filterProvider,
      (_, next) {
        final nextQuery = next['query']?.toString() ?? '';
        if (nextQuery == _lastSyncedQuery || _focusNode.hasFocus) {
          return;
        }
        _lastSyncedQuery = nextQuery;
        _controller.value = _controller.value.copyWith(
          text: nextQuery,
          selection: TextSelection.collapsed(offset: nextQuery.length),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String value) async {
    final notifier = ref.read(filterProvider.notifier);
    notifier.setQuery(value);
    await notifier.save();
    ref
      ..invalidate(venueNotifierProvider)
      ..refresh(venueNotifierProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    final filters = ref.watch(filterProvider);
    final hasActiveFilters = filters.entries.any(
      (entry) => entry.key != 'query',
    );

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      titleSpacing: 16,
      title: _SearchField(
        controller: _controller,
        focusNode: _focusNode,
        hintText: l10n.searchPlaceholder,
        onSubmitted: _submitSearch,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _FilterButton(
            hasActiveFilters: hasActiveFilters,
            onPressed: () => showFilterModal(context, ref),
          ),
        ),
      ],
      bottom: widget.bottom,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return Row(
            children: [
              Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration.collapsed(hintText: hintText),
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSubmitted,
                ),
              ),
              if (value.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    controller.clear();
                    focusNode.requestFocus();
                    onSubmitted('');
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.hasActiveFilters,
    required this.onPressed,
  });

  final bool hasActiveFilters;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = IconButton(
      tooltip: S.of(context).applyFilters,
      onPressed: onPressed,
      icon: const Icon(Icons.filter_list),
    );

    if (!hasActiveFilters) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: 6,
          top: 12,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
