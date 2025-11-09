import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/address/providers/address_notifier.dart';
import 'package:eazy_client_mvp/features/checkout/providers/checkout_notifier.dart';
import 'package:eazy_client_mvp/features/checkout/screens/checkout_screen.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';

class _StubAddressNotifier extends AddressNotifier {
  _StubAddressNotifier(this.initial);

  final List<AddressModel> initial;

  @override
  List<AddressModel> build() => initial;

  @override
  Future<Failure?> fetchAddresses() async {
    state = initial;
    return null;
  }
}

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.user);

  final UserModel user;

  @override
  Future<UserModel> build() async => user;
}

class MockApiService extends Mock implements ApiService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('кнопка оформлении заказа активируется после принятия условий',
      (tester) async {
    await S.load(const Locale('ru'));
    final apiService = MockApiService();
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();

    when(firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(firebaseUser.uid).thenReturn('firebase-user');

    when(
      apiService.get<Map<String, dynamic>>('/venues/venue-123'),
    ).thenAnswer(
      (_) async => right({
        'id': 'venue-123',
        'name': 'Тестовое заведение',
        'type': 'food',
        'rating': 4.6,
        'cuisines': const <String>[],
        'avgPrice': 950,
        'photos': const <String>[],
        'deliveryFee': 0,
        'deliveryTimeMinutes': '25-35',
        'address': {
          'id': 'venue-addr',
          'formatted': 'Москва, ул. Тестовая, 2',
          'lat': 55.75,
          'lng': 37.61,
        },
      }),
    );

    final cartItem = CartItemModel(
      product: const ProductModel(
        id: 'product-1',
        venueId: 'venue-123',
        name: 'Тестовый товар',
        description: 'Описание',
        price: 500,
        imageUrl: '',
      ),
      quantity: 1,
    );

    final address = const AddressModel(
      id: 'addr-1',
      formatted: 'Москва, пр-т Тестовый, 3',
      lat: 55.75,
      lng: 37.62,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(firebaseAuth),
          apiServiceProvider.overrideWithValue(apiService),
          cartNotifierProvider.overrideWith(
            (ref) => Stream<List<CartItemModel>>.value([cartItem]),
          ),
          addressNotifierProvider.overrideWith(
            () => _StubAddressNotifier([address]),
          ),
          profileNotifierProvider.overrideWith(
            () => _StubProfileNotifier(
              const UserModel(
                id: 'user-001',
                name: 'Tester',
                email: 'tester@example.com',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const CheckoutScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final buttonFinder = find.byType(ElevatedButton);
    ElevatedButton button = tester.widget(buttonFinder);
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    button = tester.widget(buttonFinder);
    expect(button.onPressed, isNotNull);
  });
}
