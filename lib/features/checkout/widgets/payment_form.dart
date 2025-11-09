import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../home/providers/home_providers.dart';
import '../providers/checkout_notifier.dart';
import '../providers/payment_notifier.dart';

class PaymentForm extends ConsumerStatefulWidget {
  const PaymentForm({
    super.key,
    required this.termsAccepted,
  });

  final bool termsAccepted;

  @override
  ConsumerState<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<PaymentForm> {
  static const String _newCardValue = '__new_card__';

  late final CardFormEditController _cardController;
    late final TextEditingController _cashController;
    bool _suppressCashListener = false;

  @override
  void initState() {
    super.initState();
    _cardController = CardFormEditController();
    _cardController.addListener(_onCardChanged);
    final initialCash = ref.read(checkoutProvider).order.cashInstructions ?? '';
    _cashController = TextEditingController(text: initialCash);
    _cashController.addListener(_onCashChanged);
    ref.listen<CheckoutState>(
      checkoutProvider,
      (previous, next) {
        final instructions = next.order.cashInstructions ?? '';
        if (instructions == _cashController.text) {
          return;
        }
        _suppressCashListener = true;
        _cashController
          ..text = instructions
          ..selection = TextSelection.collapsed(offset: instructions.length);
        _suppressCashListener = false;
      },
    );
  }

  @override
  void dispose() {
    _cardController.removeListener(_onCardChanged);
    _cardController.dispose();
    _cashController.removeListener(_onCashChanged);
    _cashController.dispose();
    super.dispose();
  }

  void _onCardChanged() {
    final details = _cardController.details;
    ref
        .read(paymentNotifierProvider.notifier)
        .updateCardComplete(details?.complete ?? false);
  }

  void _onCashChanged() {
    if (_suppressCashListener) {
      return;
    }
    final checkout = ref.read(checkoutProvider);
    if (checkout.order.paymentMethod != 'cash') {
      return;
    }
    ref.read(checkoutProvider.notifier).updateCashInstructions(_cashController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final paymentState = ref.watch(paymentNotifierProvider);
    final methodsAsync = ref.watch(paymentProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final order = checkoutState.order;
    final total = order.grandTotal;
    final cashFee = order.cashFee;
    final isCash = order.paymentMethod == 'cash';
    final methods = methodsAsync.maybeWhen<List<PaymentMethod>>(
      data: (data) => data,
      orElse: () => const <PaymentMethod>[],
    );

    if (!isCash &&
        methods.isNotEmpty &&
        paymentState.selectedMethodId == null &&
        paymentState.useNewCard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(paymentNotifierProvider.notifier)
            .selectSavedMethod(methods.first.id);
      });
    }

    final isBusy = paymentState.isProcessing || checkoutState.isPlacing;
    final groupValue = paymentState.useNewCard
        ? _newCardValue
        : paymentState.selectedMethodId ?? _newCardValue;
    final amountLabel = '${total.toStringAsFixed(0)} ${l10n.currencyRub}';
    final showNewCardRadio = methods.isNotEmpty;
    final toggleSelection = <bool>[!isCash, isCash];
    final canSubmit = widget.termsAccepted &&
        checkoutState.canSubmit &&
        !isBusy &&
        (isCash || paymentState.canSubmit);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.paymentSectionTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: toggleSelection,
            onPressed: isBusy
                ? null
                : (index) => _onPaymentMethodToggle(index == 1),
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 40, minWidth: 0),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.cardPayment),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.cashPayment),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isCash)
            methodsAsync.when(
              data: (_) => const SizedBox.shrink(),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (error, __) => _ErrorBanner(
                message: error is Failure ? error.message : error.toString(),
                onRetry: () => ref.invalidate(paymentProvider),
              ),
            ),
          if (!isCash && methods.isNotEmpty) ...[
            ...methods.map(
              (method) => RadioListTile<String>(
                value: method.id,
                groupValue: groupValue,
                onChanged: isBusy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        ref
                            .read(paymentNotifierProvider.notifier)
                            .selectSavedMethod(value);
                      },
                title: Text(_formatMethod(method)),
                subtitle: method.billingDetails?.name?.isNotEmpty == true
                    ? Text(method.billingDetails!.name!)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!isCash && showNewCardRadio)
            RadioListTile<String>(
              value: _newCardValue,
              groupValue: groupValue,
              onChanged: isBusy
                  ? null
                  : (_) {
                      ref.read(paymentNotifierProvider.notifier).useNewCard();
                    },
              title: Text(l10n.newCardLabel),
            ),
          if (!isCash && (!showNewCardRadio || paymentState.useNewCard)) ...[
            const SizedBox(height: 12),
            CardFormField(
              controller: _cardController,
              countryCode: 'RU',
              style: CardFormStyle(
                borderRadius: 12,
                borderWidth: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              enablePostalCode: false,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: paymentState.saveCard,
              onChanged: isBusy
                  ? null
                  : (value) {
                      ref
                          .read(paymentNotifierProvider.notifier)
                          .toggleSaveCard(value ?? false);
                    },
              title: Text(l10n.saveCardLabel),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          if (!isCash && paymentState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              paymentState.error!.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (isCash) ...[
            TextFormField(
              controller: _cashController,
              enabled: !isBusy,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.cashInstructions,
                hintText: l10n.cashInstructions,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (ref.read(checkoutProvider).order.paymentMethod != 'cash') {
                  return null;
                }
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.cashFeeApplied}: +${(AppConstants.cashFeePercent * 100).toStringAsFixed(0)}% '
              '(${cashFee.toStringAsFixed(0)} ${l10n.currencyRub})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: isCash ? l10n.placeOrder : l10n.payNow(amountLabel),
            isLoading: isBusy,
            onPressed: canSubmit
                ? () => _onSubmit(
                      isCash: isCash,
                      methods: methods,
                      amount: total,
                      l10n: l10n,
                    )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit({
    required bool isCash,
    required List<PaymentMethod> methods,
    required double amount,
    required S l10n,
  }) async {
    final context = this.context;
    if (!widget.termsAccepted) {
      _showMessage(l10n.acceptTermsBeforePaying);
      return;
    }

    final formState = Form.of(context);
    if (formState != null && !formState.validate()) {
      _showMessage(l10n.checkoutIncomplete);
      return;
    }

    final checkoutState = ref.read(checkoutProvider);
    if (!checkoutState.canSubmit) {
      _showMessage(l10n.checkoutIncomplete);
      return;
    }

      if (isCash) {
        final failure = await ref.read(checkoutProvider.notifier).placeOrder(
              etaLabel: checkoutState.etaLabel,
            );
        if (failure != null) {
          _showMessage(failure.message);
          return;
        }
        if (!context.mounted) {
          return;
        }
        _showMessage(l10n.orderPlaced);
        _navigateToOrderStatus();
        return;
      }

    await _handleCardPayment(
      methods: methods,
      amount: amount,
      l10n: l10n,
      checkoutState: checkoutState,
    );
  }

  Future<void> _handleCardPayment({
    required List<PaymentMethod> methods,
    required double amount,
    required S l10n,
    required CheckoutState checkoutState,
  }) async {
    final context = this.context;
    final paymentState = ref.read(paymentNotifierProvider);
    final notifier = ref.read(paymentNotifierProvider.notifier);
    notifier.clearError();

    PaymentMethod? selectedMethod;
    if (!paymentState.useNewCard) {
      selectedMethod = methods.firstWhereOrNull(
        (method) => method.id == paymentState.selectedMethodId,
      );
      if (selectedMethod == null) {
        _showMessage(l10n.selectPaymentMethod);
        return;
      }
    }

    final result = await notifier.pay(
      amount: amount,
      controller: paymentState.useNewCard ? _cardController : null,
      selectedMethod: selectedMethod,
    );

    if (result == null) {
      final error = ref.read(paymentNotifierProvider).error;
      if (error != null) {
        _showMessage(error.message);
      }
      return;
    }

    final failure = await ref.read(checkoutProvider.notifier).placeOrder(
          etaLabel: checkoutState.etaLabel,
          paymentIntentId: result.paymentIntent.id,
          paymentMethodId: result.paymentMethod.id,
        );
    if (failure != null) {
      _showMessage(failure.message);
      return;
    }

    if (!context.mounted) {
      return;
    }
    _showMessage(l10n.orderPlaced);
    _navigateToOrderStatus();
  }

  void _onPaymentMethodToggle(bool selectCash) {
    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    checkoutNotifier.setPaymentMethod(selectCash ? 'cash' : 'card');
    if (selectCash) {
      checkoutNotifier.updateCashInstructions(_cashController.text);
    }
    ref.read(paymentNotifierProvider.notifier).clearError();
  }

  void _navigateToOrderStatus() {
    final orderId = ref.read(checkoutProvider).order.id.trim();
    ref.read(navProvider.notifier).state = 2;
    if (orderId.isEmpty) {
      context.go('/');
      return;
    }
    final encodedId = Uri.encodeComponent(orderId);
    context.go('/orders/$encodedId/status');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatMethod(PaymentMethod method) {
    final brand = method.card?.brand ?? 'Card';
    final last4 = method.card?.last4 ?? '****';
    return '$brand •••• $last4';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(S.of(context).retry),
          ),
        ],
      ),
    );
  }
}
