import 'package:dartz/dartz.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/services/stripe/stripe_service.dart';

class MockStripe extends Mock implements Stripe {}

class MockApiService extends Mock implements ApiService {}

class MockPaymentMethod extends Mock implements PaymentMethod {}

class MockPaymentIntent extends Mock implements PaymentIntent {}

class MockCardFormEditController extends Mock
    implements CardFormEditController {}

void main() {
  late MockStripe stripe;
  late MockApiService apiService;
  late StripeService service;

  setUp(() {
    stripe = MockStripe();
    apiService = MockApiService();
    service = StripeService(apiService: apiService, stripe: stripe);
  });

  group('createPaymentMethod', () {
    test(
      'throws Failure when card details incomplete',
      () async {
        final controller = MockCardFormEditController();

        await expectLater(
          service.createPaymentMethod(
            controller,
            isCompleteOverride: false,
          ),
          throwsA(isA<Failure>()),
        );
      },
    );

    test(
      'returns PaymentMethod when stripe succeeds',
      () async {
        final controller = MockCardFormEditController();
        final paymentMethod = MockPaymentMethod();
        when(paymentMethod.id).thenReturn('pm_test_123');

        when(
          stripe.createPaymentMethod(
            params: anyNamed('params'),
          ),
        ).thenAnswer((_) async => paymentMethod);

        final result = await service.createPaymentMethod(
          controller,
          isCompleteOverride: true,
        );

        expect(result, same(paymentMethod));
        verify(
          stripe.createPaymentMethod(
            params: anyNamed('params'),
          ),
        ).called(1);
      },
    );

    test('createIntent бросает Failure при пустом ответе API', () async {
      when(
        apiService.post<Map<String, dynamic>>(
          any,
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => right(<String, dynamic>{}));

      expect(
        () => service.createIntent(amount: 10),
        throwsA(isA<Failure>()),
      );
    });

    test('confirmPayment требует clientSecret', () async {
      final intent = MockPaymentIntent();
      when(intent.clientSecret).thenReturn(null);
      when(intent.id).thenReturn('pi_123');
      final method = MockPaymentMethod();
      when(method.id).thenReturn('pm_123');

      expect(
        () => service.confirmPayment(intent: intent, method: method),
        throwsA(isA<Failure>()),
      );
    });
  });
}
