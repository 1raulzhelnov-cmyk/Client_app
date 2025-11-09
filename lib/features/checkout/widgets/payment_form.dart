import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _cardController = CardFormEditController();
    _cardController.addListener(_onCardChanged);
  }

  @override
  void dispose() {
    _cardController.removeListener(_onCardChanged);
    _cardController.dispose();
    super.dispose();
  }

  void _onCardChanged() {
    final details = _cardController.details;
    ref
        .read(paymentNotifierProvider.notifier)
        .updateCardComplete(details?.complete ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final paymentState = ref.watch(paymentNotifierProvider);
    final methodsAsync = ref.watch(paymentProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final total = checkoutState.order.grandTotal;
    final methods = methodsAsync.maybeWhen<List<PaymentMethod>>(
      data: (data) => data,
      orElse: () => const <PaymentMethod>[],
    );

    if (methods.isNotEmpty &&
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
          methodsAsync.when(
            data: (_) => const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (error, __) => _ErrorBanner(
              message: error is Failure ? error.message : error.toString(),
              onRetry: () => ref.invalidate(paymentProvider),
            ),
          ),
          if (methods.isNotEmpty) ...[
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
          if (showNewCardRadio)
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
          if (!showNewCardRadio || paymentState.useNewCard) ...[
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
          if (paymentState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              paymentState.error!.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: l10n.payNow(amountLabel),
            isLoading: isBusy,
            onPressed: (!widget.termsAccepted || !paymentState.canSubmit || !checkoutState.canSubmit)
                ? null
                : () => _onPay(methods, total, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _onPay(
    List<PaymentMethod> methods,
    double amount,
    S l10n,
  ) async {
    final context = this.context;
    if (!widget.termsAccepted) {
      _showMessage(l10n.acceptTermsBeforePaying);
      return;
    }

    final checkoutState = ref.read(checkoutProvider);
    if (!checkoutState.canSubmit) {
      _showMessage(l10n.checkoutIncomplete);
      return;
    }

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
    ref.read(navProvider.notifier).state = 2;
    context.go('/');
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
