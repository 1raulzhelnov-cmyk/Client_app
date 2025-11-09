import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../services/stripe/stripe_service.dart';

final paymentProvider = AutoDisposeFutureProvider<List<PaymentMethod>>((ref) async {
  final stripe = ref.read(stripeServiceProvider);
  return stripe.getSavedMethods();
});

final paymentNotifierProvider =
    AutoDisposeNotifierProvider<PaymentNotifier, PaymentState>(
  PaymentNotifier.new,
);

class PaymentState {
  const PaymentState({
    this.selectedMethodId,
    this.useNewCard = true,
    this.saveCard = false,
    this.cardComplete = false,
    this.isProcessing = false,
    this.error,
  });

  final String? selectedMethodId;
  final bool useNewCard;
  final bool saveCard;
  final bool cardComplete;
  final bool isProcessing;
  final Failure? error;

  bool get canSubmit {
    if (isProcessing) {
      return false;
    }
    if (useNewCard) {
      return cardComplete;
    }
    return selectedMethodId != null && selectedMethodId!.isNotEmpty;
  }

  PaymentState copyWith({
    String? selectedMethodId,
    bool? useNewCard,
    bool? saveCard,
    bool? cardComplete,
    bool? isProcessing,
    Failure? error,
    bool clearError = false,
  }) {
    return PaymentState(
      selectedMethodId: selectedMethodId ?? this.selectedMethodId,
      useNewCard: useNewCard ?? this.useNewCard,
      saveCard: saveCard ?? this.saveCard,
      cardComplete: cardComplete ?? this.cardComplete,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PaymentResult {
  const PaymentResult({
    required this.paymentIntent,
    required this.paymentMethod,
  });

  final PaymentIntent paymentIntent;
  final PaymentMethod paymentMethod;
}

class PaymentNotifier extends AutoDisposeNotifier<PaymentState> {
  StripeService get _stripe => ref.read(stripeServiceProvider);

  @override
  PaymentState build() {
    return const PaymentState();
  }

  void selectSavedMethod(String? methodId) {
    state = state.copyWith(
      useNewCard: methodId == null,
      selectedMethodId: methodId,
      clearError: true,
    );
  }

  void useNewCard() {
    state = state.copyWith(
      useNewCard: true,
      selectedMethodId: null,
      clearError: true,
    );
  }

  void toggleSaveCard(bool value) {
    state = state.copyWith(
      saveCard: value,
      clearError: true,
    );
  }

  void updateCardComplete(bool complete) {
    state = state.copyWith(
      cardComplete: complete,
      clearError: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<PaymentResult?> pay({
    required double amount,
    CardFormEditController? controller,
    PaymentMethod? selectedMethod,
  }) async {
    if (state.isProcessing) {
      return null;
    }
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final PaymentMethod method;

      if (state.useNewCard) {
        if (controller == null) {
          throw const Failure(message: 'Заполните данные карты.');
        }
        method = await _stripe.createPaymentMethod(controller);
        if (state.saveCard) {
          await _attach(method.id);
        }
      } else {
        final resolvedMethod = selectedMethod;
        if (resolvedMethod == null) {
          throw const Failure(message: 'Выберите сохранённый способ оплаты.');
        }
        method = resolvedMethod;
      }

      final intent = await _stripe.createIntent(amount: amount);
      final confirmed = await _stripe.confirmPayment(
        intent: intent,
        method: method,
      );

      final status = confirmed.status;
      if (status != null) {
        final statusString = status is Enum ? status.name : status.toString();
        final normalized = statusString.toLowerCase();
        if (normalized != 'succeeded' && normalized != 'requires_capture') {
          throw Failure(
            message: 'Платеж не завершен: $statusString.',
          );
        }
      }

      state = state.copyWith(isProcessing: false, clearError: true);
      return PaymentResult(
        paymentIntent: confirmed,
        paymentMethod: method,
      );
    } on Failure catch (failure) {
      state = state.copyWith(
        isProcessing: false,
        error: failure,
      );
      return null;
    } catch (error) {
      final failure = Failure(message: error.toString());
      state = state.copyWith(
        isProcessing: false,
        error: failure,
      );
      return null;
    }
  }

  Future<void> _attach(String paymentMethodId) async {
    try {
      await _stripe.attachPaymentMethod(paymentMethodId);
      // обновляем сохранённые методы
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (ref.mounted) {
            ref.invalidate(paymentProvider);
          }
        }),
      );
    } on Failure catch (failure) {
      // Если сохранить карту не удалось, показываем ошибку, но не блокируем оплату.
      state = state.copyWith(error: failure);
    } catch (error) {
      state = state.copyWith(
        error: Failure(message: error.toString()),
      );
    }
  }
}
