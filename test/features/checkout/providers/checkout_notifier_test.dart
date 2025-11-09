import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/constants/app_constants.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/checkout/providers/checkout_notifier.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/models/cart_item_model.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/models/venue_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._user);

  final UserModel _user;

  @override
  Future<UserModel> build() async => _user;
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutNotifier', () {
    late ProviderContainer container;
    late MockFirebaseAuth firebaseAuth;
    late MockUser firebaseUser;
    late MockApiService apiService;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      firebaseUser = MockUser();
      apiService = MockApiService();

      when(firebaseAuth.currentUser).thenReturn(firebaseUser);
      when(firebaseUser.uid).thenReturn('firebase-user');

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

      when(
        apiService.get<Map<String, dynamic>>('/venues/venue-123'),
      ).thenAnswer(
        (_) async => right(
          _fakeVenuePayload(),
        ),
      );

      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(firebaseAuth),
          apiServiceProvider.overrideWithValue(apiService),
          cartNotifierProvider.overrideWith(
            (ref) => Stream<List<CartItemModel>>.value([cartItem]),
          ),
          profileNotifierProvider.overrideWith(
            () => _StubProfileNotifier(
              const UserModel(
                id: 'user-001',
                name: 'Тестовый пользователь',
                email: 'user@example.com',
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('setAddress обновляет выбранный адрес', () async {
      final notifier = container.read(checkoutProvider.notifier);
      final address = const AddressModel(
        id: 'addr-1',
        formatted: 'Москва, ул. Тестовая, 1',
        lat: 55.75,
        lng: 37.61,
        instructions: 'Позвонить за 5 минут',
      );

      notifier.setAddress(address);

      final state = container.read(checkoutProvider);
      expect(state.order.address, same(address));
      expect(state.hasSelectedAddress, isTrue);
    });

      test('setPaymentMethod cash пересчитывает комиссию', () async {
      await container.read(cartNotifierProvider.stream).first;

      final notifier = container.read(checkoutProvider.notifier);
      notifier.setPaymentMethod('cash');

      final state = container.read(checkoutProvider);
      final expectedFee = state.order.total * AppConstants.cashFeePercent;
      expect(state.order.paymentMethod, equals('cash'));
      expect(state.order.cashFee, closeTo(expectedFee, 0.0001));
    });

      test('placeOrder требует инструкции для оплаты наличными', () async {
        await container.read(cartNotifierProvider.stream).first;
        final notifier = container.read(checkoutProvider.notifier);

        notifier.setPaymentMethod('cash');
        notifier.updateCashInstructions('   ');

        final failure = await notifier.placeOrder();

        expect(failure, isA<Failure>());
        expect(
          failure?.message,
          contains('инструкцию для оплаты наличными'),
        );
        final state = container.read(checkoutProvider);
        expect(state.isPlacing, isFalse);
      });
  });
}

Map<String, dynamic> _fakeVenuePayload() {
  return <String, dynamic>{
    'id': 'venue-123',
    'name': 'Тестовое заведение',
    'type': VenueType.food.name,
    'rating': 4.7,
    'cuisines': const <String>['авторская'],
    'avgPrice': 900,
    'photos': const <String>[],
    'deliveryFee': 150,
    'deliveryTimeMinutes': '30-45',
    'address': <String, dynamic>{
      'id': 'venue-addr',
      'formatted': 'Москва, тестовый проспект, 5',
      'lat': 55.75,
      'lng': 37.61,
    },
  };
}
