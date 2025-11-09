import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/features/checkout/providers/checkout_notifier.dart';
import 'package:eazy_client_mvp/features/checkout/providers/payment_notifier.dart';
import 'package:eazy_client_mvp/features/checkout/widgets/payment_form.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/order_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/services/stripe/stripe_service.dart';

class MockStripeService extends Mock implements StripeService {}

class _FakeCheckoutNotifier extends CheckoutNotifier {
  _FakeCheckoutNotifier(this._initialState);

  final CheckoutState _initialState;

  @override
  CheckoutState build() => _initialState;
}

class _FakePaymentNotifier extends PaymentNotifier {
  _FakePaymentNotifier(this._initialState);

  final PaymentState _initialState;

  @override
  PaymentState build() => _initialState;
}

void main() {
  late CheckoutState checkoutState;
  late MockStripeService stripeService;

  setUp(() {
    final product = const ProductModel(
      id: 'p1',
      venueId: 'v1',
      name: 'Тестовый продукт',
      description: 'Описание',
      price: 100,
      imageUrl: '',
    );
    final cartItem = CartItemModel(product: product, quantity: 1);
    final order = OrderModel(
      id: 'order-1',
      userId: 'user-1',
      items: [cartItem],
      total: cartItem.subtotal,
      address: const AddressModel(
        id: 'address-1',
        formatted: 'Тестовая улица, 1',
        lat: 0,
        lng: 0,
      ),
      status: OrderStatus.placed,
      createdAt: DateTime(2024, 1, 1),
      paymentMethod: 'card',
    );
    checkoutState = CheckoutState(order: order);
    stripeService = MockStripeService();
  });

  ProviderScope _buildScope({
    required Widget child,
    required PaymentState paymentState,
  }) {
    return ProviderScope(
      overrides: [
        checkoutProvider.overrideWith(
          (ref) => _FakeCheckoutNotifier(checkoutState),
        ),
        paymentProvider.overrideWith((ref) async => const <PaymentMethod>[]),
        paymentNotifierProvider.overrideWith(
          (ref) => _FakePaymentNotifier(paymentState),
        ),
        stripeServiceProvider.overrideWithValue(stripeService),
      ],
      child: child,
    );
  }

  testWidgets(
    'Pay button disabled when terms not accepted',
    (tester) async {
      const paymentState = PaymentState(
        useNewCard: true,
        cardComplete: false,
      );
      await tester.pumpWidget(
        _buildScope(
          paymentState: paymentState,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(
              body: PaymentForm(termsAccepted: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'Pay button enabled when card complete and terms accepted',
    (tester) async {
      const paymentState = PaymentState(
        useNewCard: true,
        cardComplete: true,
      );

      await tester.pumpWidget(
        _buildScope(
          paymentState: paymentState,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(
              body: PaymentForm(termsAccepted: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Cash toggle requires instructions before submitting',
    (tester) async {
      const paymentState = PaymentState(
        useNewCard: true,
        cardComplete: true,
      );

      await tester.pumpWidget(
        _buildScope(
          paymentState: paymentState,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(
              body: PaymentForm(termsAccepted: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final formContext = tester.element(find.byType(PaymentForm));
      final cashLabel = S.of(formContext).cashPayment;
      final instructionsLabel = S.of(formContext).cashInstructions;

      await tester.tap(find.text(cashLabel));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, instructionsLabel),
        findsOneWidget,
      );

      var button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.byType(TextFormField),
        'Позвоните при доставке',
      );
      await tester.pumpAndSettle();

      button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);
    },
  );
}
