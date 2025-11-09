import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eazy_client_mvp/features/orders/widgets/rating_modal.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';

void main() {
  testWidgets('RatingModal обновляет выбранную оценку при нажатии на звезду',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const RatingModal(
            orderId: 'order-1',
            venueId: 'venue-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    RatingBar ratingBar =
        tester.widget<RatingBar>(find.byType(RatingBar));
    expect(ratingBar.initialRating, equals(5));

    await tester.tap(find.byIcon(Icons.star_rounded).at(2));
    await tester.pumpAndSettle();

    ratingBar = tester.widget<RatingBar>(find.byType(RatingBar));
    expect(ratingBar.initialRating, equals(3));
  });
}
