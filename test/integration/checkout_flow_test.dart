import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/checkout/providers/checkout_notifier.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class _SpyCartUpdateNotifier extends CartUpdateNotifier {
  bool clearCalled = false;

  @override
  void build() {}

  @override
  Future<void> clearCart() async {
    clearCalled = true;
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

  test('placeOrder отправляет заказ и очищает корзину', () async {
    final apiService = MockApiService();
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    final cartUpdateSpy = _SpyCartUpdateNotifier();

    when(firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(firebaseUser.uid).thenReturn('firebase-user');

    when(
      apiService.get<Map<String, dynamic>>('/venues/venue-123'),
    ).thenAnswer(
      (_) async => right({
        'id': 'venue-123',
        'name': 'Тестовое заведение',
        'type': 'food',
        'rating': 4.5,
        'cuisines': const <String>[],
        'avgPrice': 820,
        'photos': const <String>[],
        'deliveryFee': 0,
        'deliveryTimeMinutes': '25-35',
        'address': {
          'id': 'venue-address',
          'formatted': 'Москва, Тестовая 1',
          'lat': 55.75,
          'lng': 37.61,
        },
      }),
    );

    when(
      apiService.post<Map<String, dynamic>>(
        '/orders',
        body: anyNamed('body'),
      ),
    ).thenAnswer(
      (_) async => right(<String, dynamic>{
        'order': <String, dynamic>{
          'id': 'order-1',
          'userId': 'user-001',
          'items': const <Map<String, dynamic>>[],
          'total': 700,
          'address': const <String, dynamic>{
            'id': 'addr-1',
            'formatted': 'Москва, пр-т Тестовый, 3',
            'lat': 55.75,
            'lng': 37.62,
          },
          'status': 'placed',
          'createdAt': DateTime.now().toIso8601String(),
        },
      }),
    );

    final cartItem = CartItemModel(
      product: const ProductModel(
        id: 'product-1',
        venueId: 'venue-123',
        name: 'Тестовый товар',
        description: 'Описание',
        price: 350,
        imageUrl: '',
      ),
      quantity: 2,
    );

    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(firebaseAuth),
        apiServiceProvider.overrideWithValue(apiService),
        cartNotifierProvider.overrideWith(
          (ref) => Stream<List<CartItemModel>>.value([cartItem]),
        ),
        cartUpdateNotifier.overrideWith((ref) => cartUpdateSpy),
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
    );

    addTearDown(container.dispose);

    await container.read(cartNotifierProvider.stream).first;

    final notifier = container.read(checkoutProvider.notifier);
    final failure = await notifier.placeOrder(
      etaLabel: '25-35 мин',
      paymentIntentId: 'pi_test_123',
      paymentMethodId: 'pm_card_123',
    );

    expect(failure, isNull);
    expect(cartUpdateSpy.clearCalled, isTrue);

    final state = container.read(checkoutProvider);
    expect(state.isPlacing, isFalse);
    expect(state.order.paymentMethod, equals('card'));
    expect(state.order.paymentIntentId, equals('pi_test_123'));

    final captured = verify(
      apiService.post<Map<String, dynamic>>(
        '/orders',
        body: captureAnyNamed('body'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['paymentMethod'], equals('card'));
    expect(captured['paymentMethodId'], equals('pm_card_123'));
    expect(captured['paymentIntentId'], equals('pi_test_123'));
    expect(captured['items'], isA<List>());
    expect((captured['items'] as List).length, equals(1));
    expect(captured['address'], isA<Map<String, dynamic>>());
  });
}
