import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/checkout/providers/payment_notifier.dart';
import 'package:eazy_client_mvp/services/stripe/stripe_service.dart';

class MockStripeService extends Mock implements StripeService {}

class MockPaymentMethod extends Mock implements PaymentMethod {}

class MockPaymentIntent extends Mock implements PaymentIntent {}

class MockCardFormEditController extends Mock
    implements CardFormEditController {}

void main() {
  group('PaymentNotifier pay', () {
    late MockStripeService stripeService;
    late ProviderContainer container;

    setUp(() {
      stripeService = MockStripeService();
      container = ProviderContainer(
        overrides: [
          stripeServiceProvider.overrideWithValue(stripeService),
        ],
      );
    });

    tearDown(container.dispose);

    test('completes successfully when Stripe confirms payment', () async {
      final notifier = container.read(paymentNotifierProvider.notifier);
      final controller = MockCardFormEditController();
      final paymentMethod = MockPaymentMethod();
      final createdIntent = MockPaymentIntent();
      final confirmedIntent = MockPaymentIntent();

      when(paymentMethod.id).thenReturn('pm_success_1');
      when(createdIntent.clientSecret).thenReturn('secret_test');
      when(confirmedIntent.status).thenReturn('succeeded');
      when(confirmedIntent.id).thenReturn('pi_success_1');

      when(
        stripeService.createPaymentMethod(
          controller,
        ),
      ).thenAnswer((_) async => paymentMethod);
      when(
        stripeService.createIntent(
          amount: anyNamed('amount'),
          currency: anyNamed('currency'),
        ),
      ).thenAnswer((_) async => createdIntent);
      when(
        stripeService.confirmPayment(
          intent: createdIntent,
          method: paymentMethod,
        ),
      ).thenAnswer((_) async => confirmedIntent);

      final result = await notifier.pay(
        amount: 450,
        controller: controller,
      );

      expect(result, isNotNull);
      expect(result!.paymentMethod, same(paymentMethod));
      expect(result.paymentIntent, same(confirmedIntent));
      expect(container.read(paymentNotifierProvider).error, isNull);

      verify(
        stripeService.createPaymentMethod(controller),
      ).called(1);
      verify(
        stripeService.createIntent(amount: 450, currency: anyNamed('currency')),
      ).called(1);
      verify(
        stripeService.confirmPayment(
          intent: createdIntent,
          method: paymentMethod,
        ),
      ).called(1);
    });

    test('returns failure when confirmPayment throws', () async {
      final notifier = container.read(paymentNotifierProvider.notifier);
      final controller = MockCardFormEditController();
      final paymentMethod = MockPaymentMethod();
      final createdIntent = MockPaymentIntent();

      when(paymentMethod.id).thenReturn('pm_fail_1');
      when(createdIntent.clientSecret).thenReturn('secret_fail');

      when(
        stripeService.createPaymentMethod(
          controller,
        ),
      ).thenAnswer((_) async => paymentMethod);
      when(
        stripeService.createIntent(
          amount: anyNamed('amount'),
          currency: anyNamed('currency'),
        ),
      ).thenAnswer((_) async => createdIntent);
      when(
        stripeService.confirmPayment(
          intent: createdIntent,
          method: paymentMethod,
        ),
      ).thenThrow(const Failure(message: 'Payment failed'));

      final result = await notifier.pay(
        amount: 250,
        controller: controller,
      );

      expect(result, isNull);
      final state = container.read(paymentNotifierProvider);
      expect(state.error, isA<Failure>());
      expect(state.isProcessing, isFalse);
    });
  });
}
