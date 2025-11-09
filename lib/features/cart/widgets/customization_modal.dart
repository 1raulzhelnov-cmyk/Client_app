import 'package:flutter/material.dart';

import '../../../generated/l10n.dart';
import '../../../models/customization_model.dart';
import '../../../models/customization_option.dart';
import '../../../widgets/app_button.dart';

Future<CustomizationSelection?> showCustomizationModal({
  required BuildContext context,
  required String productName,
  required CustomizationModel customization,
}) {
  if (!customization.hasOptions) {
    return Future<CustomizationSelection?>.value(null);
  }
  return showModalBottomSheet<CustomizationSelection>(
    context: context,
    isScrollControlled: true,
    builder: (modalContext) => CustomizationModal(
      productName: productName,
      customization: customization,
    ),
  );
}

class CustomizationModal extends StatefulWidget {
  const CustomizationModal({
    super.key,
    required this.productName,
    required this.customization,
  });

  final String productName;
  final CustomizationModel customization;

  @override
  State<CustomizationModal> createState() => _CustomizationModalState();
}

class _CustomizationModalState extends State<CustomizationModal> {
  late List<CustomizationOption> _sizeOptions;
  late List<CustomizationOption> _addOnOptions;
  late List<CustomizationOption> _modificationOptions;
  String? _selectedSizeId;
  CustomizationOption? _selectedSize;
  late final TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _sizeOptions = widget.customization.sizes
        .map((option) => option.copyWith(isSelected: option.isSelected))
        .toList();
    _addOnOptions = widget.customization.addOns
        .map((option) => option.copyWith(isSelected: option.isSelected))
        .toList();
    _modificationOptions = widget.customization.modifications
        .map((option) => option.copyWith(isSelected: option.isSelected))
        .toList();

    final preselectedSize =
        _firstWhereOrNull(_sizeOptions, (option) => option.isSelected) ??
            _firstWhereOrNull(_sizeOptions, (option) => option.isRequired);
    if (preselectedSize != null) {
      _selectedSizeId = preselectedSize.id;
      _selectedSize = preselectedSize.copyWith(isSelected: true);
    }
    _instructionsController = TextEditingController();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = S.of(context);
    final mediaQuery = MediaQuery.of(context);
    final extraInsets = mediaQuery.viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: extraInsets,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.productName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_sizeOptions.isNotEmpty) ...[
                  Text(
                    l10n.chooseSize,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSizeId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    isExpanded: true,
                    hint: Text(
                      l10n.chooseSize,
                      style: theme.textTheme.bodyMedium,
                    ),
                    items: _sizeOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(_formatOptionTitle(option)),
                          ),
                        )
                        .toList(),
                    onChanged: _handleSizeChanged,
                  ),
                  const SizedBox(height: 16),
                },
                Text(
                  l10n.specialInstructions,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: l10n.specialInstructions,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_addOnOptions.isNotEmpty)
                  _OptionsList(
                    title: l10n.additionalOptions,
                    options: _addOnOptions,
                    onChanged: (option, value) =>
                        _toggleOption(value, option, isAddOn: true),
                  ),
                if (_modificationOptions.isNotEmpty)
                  _OptionsList(
                    title: l10n.customize,
                    options: _modificationOptions,
                    onChanged: (option, value) =>
                        _toggleOption(value, option, isAddOn: false),
                  ),
                const SizedBox(height: 12),
                AppButton(
                  label: l10n.addToCart,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSizeChanged(String? value) {
    setState(() {
      _selectedSizeId = value;
      if (value == null) {
        _selectedSize = null;
        return;
      }
      final match = _firstWhereOrNull(
        _sizeOptions,
        (option) => option.id == value,
      );
      _selectedSize = match?.copyWith(isSelected: true);
    });
  }

  void _toggleOption(bool value, CustomizationOption option,
      {required bool isAddOn}) {
    setState(() {
      if (isAddOn) {
        _addOnOptions = _addOnOptions
            .map(
              (item) => item.id == option.id
                  ? item.copyWith(isSelected: value)
                  : item,
            )
            .toList();
      } else {
        _modificationOptions = _modificationOptions
            .map(
              (item) => item.id == option.id
                  ? item.copyWith(isSelected: value)
                  : item,
            )
            .toList();
      }
    });
  }

  void _submit() {
    final instructions = _instructionsController.text.trim();
    final addOns = _addOnOptions
        .where((option) => option.isSelected)
        .map((option) => option.copyWith(isSelected: true))
        .toList();
    final modifications = _modificationOptions
        .where((option) => option.isSelected)
        .map((option) => option.copyWith(isSelected: true))
        .toList();
    final selection = CustomizationSelection(
      size: _selectedSize?.copyWith(isSelected: true),
      addOns: addOns,
      modifications: modifications,
      instructions: instructions.isEmpty ? null : instructions,
    );
    Navigator.of(context).pop(selection);
  }

  static CustomizationOption? _firstWhereOrNull(
    List<CustomizationOption> source,
    bool Function(CustomizationOption option) test,
  ) {
    for (final option in source) {
      if (test(option)) {
        return option;
      }
    }
    return null;
  }

  String _formatOptionTitle(CustomizationOption option) {
    if (option.price <= 0) {
      return option.name;
    }
    final formattedPrice = option.price % 1 == 0
        ? option.price.toStringAsFixed(0)
        : option.price.toStringAsFixed(2);
    return '${option.name} +$formattedPrice ₽';
  }
}

class _OptionsList extends StatelessWidget {
  const _OptionsList({
    required this.title,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final List<CustomizationOption> options;
  final void Function(CustomizationOption option, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: option.isSelected,
              onChanged: (value) =>
                  onChanged(option, value ?? !option.isSelected),
              title: Text(_formatOptionTitle(option)),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatOptionTitle(CustomizationOption option) {
    if (option.price <= 0) {
      return option.name;
    }
    final formattedPrice = option.price % 1 == 0
        ? option.price.toStringAsFixed(0)
        : option.price.toStringAsFixed(2);
    return '${option.name} +$formattedPrice ₽';
  }
}
