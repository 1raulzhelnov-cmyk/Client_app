import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/address_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../cart/providers/cart_notifier.dart';
import '../../profile/providers/profile_notifier.dart';
import '../../venue/providers/venue_detail_notifier.dart';

class CheckoutState {
  const CheckoutState({
    required this.order,
    this.isPlacing = false,
    this.error,
    this.etaLabel,
  });

  final OrderModel order;
  final bool isPlacing;
  final Failure? error;
  final String? etaLabel;

  bool get hasItems => order.items.isNotEmpty;

  bool get hasSelectedAddress => order.address.formatted.trim().isNotEmpty;

  bool get canSubmit => hasItems && hasSelectedAddress && !isPlacing;

  CheckoutState copyWith({
    OrderModel? order,
    bool? isPlacing,
    Failure? error,
    bool clearError = false,
    String? etaLabel,
    bool clearEta = false,
  }) {
    return CheckoutState(
      order: order ?? this.order,
      isPlacing: isPlacing ?? this.isPlacing,
      error: clearError ? null : error ?? this.error,
      etaLabel: clearEta ? null : etaLabel ?? this.etaLabel,
    );
  }
}

final checkoutProvider =
    AutoDisposeNotifierProvider<CheckoutNotifier, CheckoutState>(
  CheckoutNotifier.new,
);

class CheckoutNotifier extends AutoDisposeNotifier<CheckoutState> {
  int _etaRequestId = 0;

  @override
  CheckoutState build() {
    final initialCart = ref.read(cartNotifierProvider).value ?? const <CartItemModel>[];
    final profileValue = ref.read(profileNotifierProvider);
    final userId = _resolveUserId(profileValue);
    final order = _buildOrder(
      cartItems: initialCart,
      userId: userId,
    );
    final initialState = CheckoutState(order: order);

    ref.listen<AsyncValue<List<CartItemModel>>>(
      cartNotifierProvider,
      (previous, next) {
        final items = next.valueOrNull;
        if (items == null) {
          return;
        }
        _updateOrderFromCart(items);
      },
    );

    ref.listen<AsyncValue<UserModel>>(
      profileNotifierProvider,
      (previous, next) {
        final user = next.valueOrNull;
        if (user == null) {
          return;
        }
        _updateUser(user.id);
      },
    );

    if (initialCart.isNotEmpty) {
      Future<void>(() => _updateEta(initialCart));
    }

    return initialState;
  }

  void setAddress(AddressModel address) {
    state = state.copyWith(
      order: state.order.copyWith(address: address),
      clearError: true,
    );
  }

  Future<Failure?> placeOrder({String? etaLabel}) async {
    final currentState = state;
    if (!currentState.hasItems) {
      const failure = Failure(message: 'Корзина пуста. Добавьте товары.');
      state = currentState.copyWith(error: failure);
      return failure;
    }
    if (!currentState.hasSelectedAddress) {
      const failure = Failure(message: 'Выберите адрес доставки.');
      state = currentState.copyWith(error: failure);
      return failure;
    }

    state = currentState.copyWith(isPlacing: true, clearError: true);

    final resolvedEtaLabel = etaLabel ?? currentState.etaLabel;
    final etaDate = _etaDateFromLabel(resolvedEtaLabel);
    final order = currentState.order.copyWith(
      paymentMethod: 'pending',
      eta: etaDate,
    );

    final payload = _buildPayload(order, resolvedEtaLabel);
    final apiService = ref.read(apiServiceProvider);

    try {
      final result = await apiService.post<Map<String, dynamic>>(
        '/orders',
        body: payload,
      );

      return await result.fold(
        (failure) {
          state = state.copyWith(
            isPlacing: false,
            error: failure,
          );
          return failure;
        },
        (response) async {
          final updatedOrder = _parseOrder(response, fallback: order);
          state = state.copyWith(
            order: updatedOrder,
            isPlacing: false,
            clearError: true,
          );
          await ref.read(cartUpdateNotifier.notifier).clearCart();
          return null;
        },
      );
    } on Failure catch (failure) {
      state = state.copyWith(
        isPlacing: false,
        error: failure,
      );
      return failure;
    } catch (error) {
      final failure = Failure(message: error.toString());
      state = state.copyWith(
        isPlacing: false,
        error: failure,
      );
      return failure;
    }
  }

  void _updateOrderFromCart(List<CartItemModel> items) {
    final total = _calculateTotal(items);
    final updatedOrder = state.order.copyWith(
      items: items,
      total: total,
    );
    state = state.copyWith(
      order: updatedOrder,
      clearError: true,
    );
    Future<void>(() => _updateEta(items));
  }

  void _updateUser(String userId) {
    if (userId.trim().isEmpty) {
      return;
    }
    state = state.copyWith(
      order: state.order.copyWith(userId: userId),
    );
  }

  void _updateEta(List<CartItemModel> items) async {
    final requestId = ++_etaRequestId;
    if (items.isEmpty) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        clearEta: true,
        order: state.order.copyWith(eta: null),
      );
      return;
    }
    final venueIds = items.map((item) => item.product.venueId).toSet();
    if (venueIds.length != 1) {
      if (!mounted || requestId != _etaRequestId) {
        return;
      }
      const fallbackLabel = '60-90 мин';
      state = state.copyWith(
        etaLabel: fallbackLabel,
        order: state.order.copyWith(
          eta: _etaDateFromLabel(fallbackLabel),
        ),
      );
      return;
    }
    final venueId = venueIds.first;
    try {
      final venue = await ref.read(venueDetailProvider(venueId).future);
      if (!mounted || requestId != _etaRequestId) {
        return;
      }
      final label = _formatEtaLabel(venue.deliveryTimeMinutes);
      state = state.copyWith(
        etaLabel: label,
        order: state.order.copyWith(
          eta: _etaDateFromLabel(label),
        ),
      );
    } on Failure {
      if (!mounted || requestId != _etaRequestId) {
        return;
      }
      state = state.copyWith(
        clearEta: true,
        order: state.order.copyWith(eta: null),
      );
    } catch (_) {
      if (!mounted || requestId != _etaRequestId) {
        return;
      }
      state = state.copyWith(
        clearEta: true,
        order: state.order.copyWith(eta: null),
      );
    }
  }

  OrderModel _buildOrder({
    required List<CartItemModel> cartItems,
    required String userId,
  }) {
    return OrderModel.empty(
      fromCart: cartItems,
      userId: userId,
    );
  }

  String _resolveUserId(AsyncValue<UserModel> profileValue) {
    final user = profileValue.valueOrNull;
    if (user != null && user.id.isNotEmpty) {
      return user.id;
    }
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser != null && firebaseUser.uid.isNotEmpty) {
      return firebaseUser.uid;
    }
    return 'anonymous';
  }

  double _calculateTotal(List<CartItemModel> items) {
    return items.fold<double>(
      0,
      (previousValue, item) => previousValue + item.subtotal,
    );
  }

  Map<String, dynamic> _buildPayload(
    OrderModel order,
    String? etaLabel,
  ) {
    final etaString = etaLabel;
    final payload = <String, dynamic>{
      'userId': order.userId,
      'items': order.items.map((item) => item.toJson()).toList(),
      'address': order.address.toJson(),
      'total': order.total,
      'deliveryFee': order.deliveryFee,
      'cashFee': order.cashFee,
      'paymentMethod': 'pending',
      'eta': etaString,
      'etaApprox': order.eta?.toIso8601String(),
      'notes': order.notes,
    };

    payload.removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      if (value is num) {
        return key != 'total' && value == 0;
      }
      if (value is List && value.isEmpty) {
        return true;
      }
      if (value is Map && value.isEmpty) {
        return true;
      }
      return false;
    });

    return payload;
  }

  OrderModel _parseOrder(
    Map<String, dynamic>? response, {
    required OrderModel fallback,
  }) {
    if (response == null || response.isEmpty) {
      return fallback;
    }
    final orderMap = _extractOrderMap(response);
    if (orderMap == null) {
      return fallback;
    }
    try {
      return OrderModel.fromJson(orderMap).copyWith(
        paymentMethod: 'pending',
      );
    } catch (_) {
      return fallback;
    }
  }

  Map<String, dynamic>? _extractOrderMap(Map<String, dynamic> payload) {
    if (payload.containsKey('order') && payload['order'] is Map) {
      return Map<String, dynamic>.from(payload['order'] as Map);
    }
    if (payload.containsKey('data') && payload['data'] is Map) {
      return Map<String, dynamic>.from(payload['data'] as Map);
    }
    if (payload.containsKey('result') && payload['result'] is Map) {
      return Map<String, dynamic>.from(payload['result'] as Map);
    }
    if (payload.containsKey('payload') && payload['payload'] is Map) {
      return Map<String, dynamic>.from(payload['payload'] as Map);
    }
    if (payload.containsKey('id') && payload.containsKey('items')) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  String? _formatEtaLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final digits = RegExp(r'\d+').allMatches(raw).map((match) => match.group(0)!).toList();
    if (digits.isEmpty) {
      return raw.trim();
    }
    final first = digits.first;
    final last = digits.length > 1 ? digits.last : null;
    if (last == null || last == first) {
      return '$first мин';
    }
    return '$first-$last мин';
  }

  DateTime? _etaDateFromLabel(String? label) {
    final minutes = _extractEtaMinutes(label);
    if (minutes == null) {
      return null;
    }
    return DateTime.now().add(Duration(minutes: minutes));
  }

  int? _extractEtaMinutes(String? label) {
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    final matches = RegExp(r'\d+').allMatches(label);
    final values = matches.map((match) => int.tryParse(match.group(0) ?? '')).whereType<int>().toList();
    if (values.isEmpty) {
      return null;
    }
    final sum = values.fold<int>(0, (previousValue, element) => previousValue + element);
    final average = sum / values.length;
    return average.round();
  }
}
