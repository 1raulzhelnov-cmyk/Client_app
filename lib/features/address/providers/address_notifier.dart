import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/address_model.dart';
import '../../../services/api/api_service.dart';

final addressNotifierProvider =
    AutoDisposeNotifierProvider<AddressNotifier, List<AddressModel>>(
  AddressNotifier.new,
);

class AddressNotifier extends AutoDisposeNotifier<List<AddressModel>> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  List<AddressModel> build() => const [];

  Future<Failure?> fetchAddresses() async {
    final result = await _apiService.get<List<AddressModel>>(
      '/addresses',
      decoder: (data) {
        final rawList = data as List<dynamic>? ?? const [];
        return rawList
            .whereType<Map<String, dynamic>>()
            .map(AddressModel.fromJson)
            .toList();
      },
    );

    return result.fold(
      (failure) {
        state = const [];
        return failure;
      },
      (addresses) {
        state = addresses;
        return null;
      },
    );
  }

  Future<Failure?> addAddress(AddressModel address) async {
    final result = await _apiService.post<AddressModel>(
      '/addresses',
      body: address.toJson(),
      decoder: (data) => _decodeAddress(data, address),
    );

    return result.fold(
      (failure) => failure,
      (created) {
        state = [...state, created];
        return null;
      },
    );
  }

  Future<Failure?> updateAddress(AddressModel address) async {
    final id = address.id;
    if (id == null || id.isEmpty) {
      return const Failure(message: 'Address identifier is missing');
    }

    final result = await _apiService.put<AddressModel>(
      '/addresses/$id',
      body: address.toJson(),
      decoder: (data) => _decodeAddress(data, address),
    );

    return result.fold(
      (failure) => failure,
      (updated) {
        state = [
          for (final item in state)
            if (item.id == updated.id) updated else item
        ];
        return null;
      },
    );
  }

  Future<Failure?> deleteAddress(String id) async {
    if (id.isEmpty) {
      return const Failure(message: 'Address identifier is missing');
    }

    final result = await _apiService.delete<dynamic>(
      '/addresses/$id',
    );

    return result.fold(
      (failure) => failure,
      (_) {
        state = [
          for (final item in state)
            if (item.id != id) item,
        ];
        return null;
      },
    );
  }

  AddressModel _decodeAddress(dynamic data, AddressModel fallback) {
    if (data is Map<String, dynamic>) {
      return AddressModel.fromJson(data);
    }
    return fallback;
  }
}
