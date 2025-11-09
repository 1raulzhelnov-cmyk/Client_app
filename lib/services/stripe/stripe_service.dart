import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/errors/failure.dart';
import '../api/api_service.dart';

class StripeService {
  StripeService({
    required ApiService apiService,
    Stripe? stripe,
  })  : _apiService = apiService,
        _stripe = stripe ?? Stripe.instance;

  final ApiService _apiService;
  final Stripe _stripe;

  Future<List<PaymentMethod>> getSavedMethods() async {
    final result = await _apiService.get<dynamic>(
      '/payments/methods',
    );

    return result.fold(
      (failure) => throw failure,
      (data) {
        if (data == null) {
          return const <PaymentMethod>[];
        }
        final methodsJson = _extractList(data);
        return methodsJson.map(PaymentMethod.fromJson).toList();
      },
    );
  }

  Future<PaymentMethod> createPaymentMethod(
    CardFormEditController controller, {
    bool? isCompleteOverride,
  }) async {
    final isComplete =
        isCompleteOverride ?? controller.details?.complete ?? false;
    if (!isComplete) {
      throw const Failure(message: 'Заполните данные карты полностью.');
    }

    try {
      return _stripe.createPaymentMethod(
        params: const PaymentMethodParams.card(),
      );
    } on StripeException catch (error) {
      final message = error.error.localizedMessage ?? 'Оплата отклонена.';
      throw Failure(
        message: message,
        code: error.error.code,
      );
    } catch (error) {
      throw Failure(message: error.toString());
    }
  }

  Future<PaymentIntent> createIntent({
    required double amount,
    String currency = 'rub',
  }) async {
    final payload = <String, dynamic>{
      'amount': (amount * 100).round(),
      'currency': currency,
    };

    final result = await _apiService.post<Map<String, dynamic>>(
      '/payments/intent',
      body: payload,
    );

    return result.fold(
      (failure) => throw failure,
      (data) {
        if (data == null || data.isEmpty) {
          throw const Failure(
            message: 'Не удалось создать платеж. Попробуйте снова.',
          );
        }
        return PaymentIntent.fromJson(data);
      },
    );
  }

  Future<PaymentIntent> confirmPayment({
    required PaymentIntent intent,
    required PaymentMethod method,
  }) async {
    final clientSecret = intent.clientSecret;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const Failure(
        message: 'Отсутствует секрет платежа для подтверждения.',
      );
    }

    try {
      return _stripe.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        params: PaymentMethodParams.cardFromMethodId(
          paymentMethodData: PaymentMethodDataCardFromMethod(
            paymentMethodId: method.id,
          ),
        ),
      );
    } on StripeException catch (error) {
      final message =
          error.error.localizedMessage ?? 'Не удалось подтвердить платеж.';
      throw Failure(
        message: message,
        code: error.error.code,
      );
    } catch (error) {
      throw Failure(message: error.toString());
    }
  }

  Future<void> attachPaymentMethod(String paymentMethodId) async {
    final result = await _apiService.post<void>(
      '/payments/methods',
      body: <String, dynamic>{
        'paymentMethodId': paymentMethodId,
      },
    );

    result.fold(
      (failure) => throw failure,
      (_) => null,
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final value = data['data'] ?? data['methods'] ?? data['items'];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
