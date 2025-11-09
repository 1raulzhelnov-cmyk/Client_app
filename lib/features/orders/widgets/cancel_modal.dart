import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../../widgets/app_button.dart';
import '../providers/order_status_notifier.dart';

class CancelModal extends ConsumerStatefulWidget {
  const CancelModal({
    super.key,
    required this.orderId,
    required this.isPaid,
  });

  final String orderId;
  final bool isPaid;

  @override
  ConsumerState<CancelModal> createState() => _CancelModalState();
}

class _CancelModalState extends ConsumerState<CancelModal> {
  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final reasons = <_CancellationReason>[
      _CancellationReason(
        value: 'Changed mind',
        label: l10n.cancellationReasonChangedMind,
      ),
      _CancellationReason(
        value: 'Wrong address',
        label: l10n.cancellationReasonWrongAddress,
      ),
    ];
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cancelOrder,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.cancellationReason,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...reasons.map(
              (reason) => RadioListTile<String>(
                value: reason.value,
                groupValue: _selectedReason,
                contentPadding: EdgeInsets.zero,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedReason = value;
                        });
                      },
                title: Text(reason.label),
              ),
            ),
            if (widget.isPaid) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.refundInfo,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: l10n.confirmCancellation,
              isLoading: _isSubmitting,
              onPressed: _selectedReason == null || _isSubmitting
                  ? null
                  : () => _submit(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final reasonValue = _selectedReason;
    if (reasonValue == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final notifier = ref.read(orderStatusNotifier);
    final failure = await notifier.cancelOrder(
      widget.orderId,
      reasonValue,
    );

    if (!mounted) {
      return;
    }

    if (failure != null) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }
}

class _CancellationReason {
  const _CancellationReason({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}
