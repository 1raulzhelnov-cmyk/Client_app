import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/address_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/flower_model.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../models/venue_model.dart';

final navProvider = StateProvider<int>((ref) => 0);

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return const HomeRepository();
});

final flowerCatalogProvider =
    FutureProvider.autoDispose<List<FlowerModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchFlowers();
});

final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchOrders();
});

class HomeRepository {
  const HomeRepository({Duration delay = const Duration(milliseconds: 350)})
      : _delay = delay;

  final Duration _delay;

  Future<void> _simulateDelay() async {
    if (_delay == Duration.zero) {
      return;
    }
    await Future<void>.delayed(_delay);
  }

  Future<List<VenueModel>> fetchVenues(String type) async {
    await _simulateDelay();
    if (type == 'food') {
      return _foodVenues();
    }
    if (type == 'flowers') {
      return _flowerVenues();
    }
    return <VenueModel>[];
  }

  Future<List<FlowerModel>> fetchFlowers() async {
    await _simulateDelay();
    return _flowers();
  }

  Future<List<OrderModel>> fetchOrders() async {
    await _simulateDelay();
    return _orders();
  }

  List<VenueModel> _foodVenues() {
    final centralAddress = _address(
      id: 'address-food-1',
      street: 'ул. Тверская, 5',
    );
    final southAddress = _address(
      id: 'address-food-2',
      street: 'пр-т Вернадского, 16',
    );

    return <VenueModel>[
      VenueModel(
        id: 'venue-bistro',
        name: 'Bistro 24',
        type: VenueType.food,
        rating: 4.7,
        cuisines: const <String>['Авторская', 'Выпечка'],
        averagePrice: 890,
        photos: const <String>[
          'https://example.com/images/food/bistro.jpg',
        ],
        deliveryFee: 150,
        deliveryTimeMinutes: '25-35',
        address: centralAddress,
        description: 'Свежие блюда и десерты каждый день.',
        hours: const <String, String>{
          'mon-fri': '10:00-23:00',
          'sat-sun': '11:00-23:00',
        },
      ),
      VenueModel(
        id: 'venue-sushi',
        name: 'Tokyo Line',
        type: VenueType.food,
        rating: 4.5,
        cuisines: const <String>['Суши', 'Поке'],
        averagePrice: 1250,
        photos: const <String>[
          'https://example.com/images/food/tokyo-line.jpg',
        ],
        deliveryFee: 200,
        deliveryTimeMinutes: '35-45',
        address: southAddress,
        description: 'Роллы, боулы и поке без компромиссов.',
        hours: const <String, String>{
          'mon-sun': '11:00-22:00',
        },
      ),
    ];
  }

  List<VenueModel> _flowerVenues() {
    final center = _address(
      id: 'address-flowers-1',
      street: 'ул. Петровка, 12',
    );

    return <VenueModel>[
      VenueModel(
        id: 'venue-bloom',
        name: 'Bloom & Co.',
        type: VenueType.flower,
        rating: 4.8,
        cuisines: const <String>['Флористика'],
        averagePrice: 3100,
        photos: const <String>[
          'https://example.com/images/flowers/bloom.jpg',
        ],
        deliveryFee: 250,
        deliveryTimeMinutes: '60-90',
        address: center,
        description: 'Премиальные композиции и оформление событий.',
        hours: const <String, String>{
          'mon-fri': '09:00-21:00',
          'sat-sun': '10:00-20:00',
        },
      ),
    ];
  }

  List<FlowerModel> _flowers() {
    return <FlowerModel>[
      FlowerModel(
        id: 'flower-rose',
        venueId: 'venue-bloom',
        name: 'Букет красных роз',
        description: '21 роза сорта Freedom с эвкалиптом.',
        price: 3290,
        imageUrl: 'https://example.com/images/flowers/rose.jpg',
        occasion: 'Юбилей',
        season: 'Круглый год',
        careInstructions: 'Подрезать стебли и менять воду каждые 2 дня.',
      ),
      FlowerModel(
        id: 'flower-tulip',
        venueId: 'venue-bloom',
        name: 'Весенние тюльпаны',
        description: 'Микс из 25 разноцветных тюльпанов.',
        price: 2790,
        imageUrl: 'https://example.com/images/flowers/tulip.jpg',
        season: 'Весна',
        occasion: 'Поздравление',
        careInstructions: 'Не ставить на солнце, освежать воду ежедневно.',
      ),
    ];
  }

  List<CartItemModel> _cartItems() {
    final pizza = ProductModel(
      id: 'product-pizza',
      venueId: 'venue-bistro',
      name: 'Пицца Маргарита',
      description: 'Классическая пицца с томатами и базиликом.',
      price: 610,
      imageUrl: 'https://example.com/images/food/pizza.jpg',
      category: 'Пицца',
      type: ProductType.food,
    );
    final poke = ProductModel(
      id: 'product-poke',
      venueId: 'venue-sushi',
      name: 'Поке с лососем',
      description: 'Рис, свежие овощи и филе лосося.',
      price: 740,
      imageUrl: 'https://example.com/images/food/poke.jpg',
      category: 'Боулы',
      type: ProductType.food,
    );

    return <CartItemModel>[
      CartItemModel(
        id: 'cart-1',
        product: pizza,
        quantity: 2,
      ),
      CartItemModel(
        id: 'cart-2',
        product: poke,
        quantity: 1,
      ),
    ];
  }

  List<OrderModel> _orders() {
    final items = _cartItems();
    final total = items.fold<double>(
      0,
      (previousValue, item) => previousValue + item.subtotal,
    );

    final address = _address(
      id: 'order-address',
      street: 'ул. Арбат, 4',
    );

    return <OrderModel>[
      OrderModel(
        id: 'order-1001',
        userId: 'user-001',
        items: items,
        total: total,
        address: address,
        status: OrderStatus.preparing,
        createdAt: DateTime(2024, 11, 6, 18, 30),
        eta: DateTime(2024, 11, 6, 19, 10),
        deliveryFee: 150,
        cashFee: 0,
        notes: 'Позвонить за 5 минут до доставки.',
      ),
    ];
  }

  AddressModel _address({required String id, required String street}) {
    return AddressModel(
      id: id,
      formatted: 'Москва, $street',
      lat: 55.7558,
      lng: 37.6173,
      instructions: 'Подъезд со двора.',
    );
  }
}
