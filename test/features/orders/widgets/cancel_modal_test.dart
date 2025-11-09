import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/orders/providers/order_status_notifier.dart';
import 'package:eazy_client_mvp/features/orders/widgets/cancel_modal.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockOrderStatusNotifier extends Mock implements OrderStatusNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> _pumpModal(
    WidgetTester tester, {
    required OrderStatusNotifier notifier,
    required bool isPaid,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderStatusNotifier.overrideWithValue(notifier),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: CancelModal(
              orderId: 'order-123',
              isPaid: isPaid,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('выбор причины активирует кнопку подтверждения', (tester) async {
    final notifier = MockOrderStatusNotifier();
    when(notifier.cancelOrder(any, any)).thenAnswer((_) async => null);

    await _pumpModal(tester, notifier: notifier, isPaid: true);

    final context = tester.element(find.byType(CancelModal));
    final l10n = S.of(context);

    final buttonFinder = find.byType(ElevatedButton);
    final disabledButton = tester.widget<ElevatedButton>(buttonFinder);
    expect(disabledButton.onPressed, isNull);

    expect(find.text(l10n.refundInfo), findsOneWidget);

    await tester.tap(find.text(l10n.cancellationReasonChangedMind));
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<ElevatedButton>(buttonFinder);
    expect(enabledButton.onPressed, isNotNull);

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    verify(notifier.cancelOrder('order-123', 'Changed mind')).called(1);
  });

  testWidgets('показывает сообщение об ошибке при неудачной отмене',
      (tester) async {
    final notifier = MockOrderStatusNotifier();
    when(notifier.cancelOrder(any, any)).thenAnswer(
      (_) async => const Failure(message: 'Ошибка отмены'),
    );

    await _pumpModal(tester, notifier: notifier, isPaid: false);

    final context = tester.element(find.byType(CancelModal));
    final l10n = S.of(context);

    await tester.tap(find.text(l10n.cancellationReasonWrongAddress));
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ошибка отмены'), findsOneWidget);
    verify(notifier.cancelOrder('order-123', 'Wrong address')).called(1);
  });
}
