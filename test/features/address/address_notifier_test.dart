import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/address/providers/address_notifier.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddressNotifier', () {
    late ProviderContainer container;
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
      container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(apiService),
        ],
      );
      addTearDown(container.dispose);
    });

      test('fetchAddresses populates state on success', () async {
      final addressesJson = [
        {
          'id': 'addr-1',
          'formatted': 'Москва, ул. Тверская, 1',
          'lat': 55.757,
          'lng': 37.615,
          'instructions': 'Позвонить за 10 минут',
          'isDefault': true,
        },
      ];
      when(
        apiService.get<List<AddressModel>>(
          any,
          queryParameters: anyNamed('queryParameters'),
          decoder: anyNamed('decoder'),
        ),
      ).thenAnswer((invocation) async {
        final decoder = invocation.namedArguments[#decoder]
            as List<AddressModel> Function(dynamic)?;
        final decoded = decoder != null
            ? decoder(addressesJson)
            : const <AddressModel>[];
        return right(decoded);
      });

      final notifier = container.read(addressNotifierProvider.notifier);
      final failure = await notifier.fetchAddresses();

      expect(failure, isNull);
      final state = container.read(addressNotifierProvider);
      expect(state, hasLength(1));
      expect(state.first.formatted, equals('Москва, ул. Тверская, 1'));
      verify(apiService.get<List<AddressModel>>('/addresses',
              queryParameters: anyNamed('queryParameters'),
              decoder: anyNamed('decoder')))
          .called(1);
    });

      test('fetchAddresses clears state on failure', () async {
        final failure = Failure(message: 'Network error');
        when(
          apiService.get<List<AddressModel>>(
            any,
            queryParameters: anyNamed('queryParameters'),
            decoder: anyNamed('decoder'),
          ),
        ).thenAnswer((_) async => left(failure));

        final notifier = container.read(addressNotifierProvider.notifier);
        final result = await notifier.fetchAddresses();

        expect(result, failure);
        expect(container.read(addressNotifierProvider), isEmpty);
      });

      test('add/update/delete address mutate state', () async {
        final address = AddressModel(
          id: 'addr-1',
          formatted: 'Адрес 1',
          lat: 55.0,
          lng: 37.0,
        );

        when(
          apiService.post<AddressModel>(
            any,
            body: anyNamed('body'),
            decoder: anyNamed('decoder'),
          ),
        ).thenAnswer((invocation) async => right(address));

        when(
          apiService.put<AddressModel>(
            any,
            body: anyNamed('body'),
            decoder: anyNamed('decoder'),
          ),
        ).thenAnswer((_) async => right(address.copyWith(instructions: 'Новая')));

        when(
          apiService.delete<dynamic>(
            any,
          ),
        ).thenAnswer((_) async => right(null));

        final notifier = container.read(addressNotifierProvider.notifier);
        expect(await notifier.addAddress(address), isNull);
        expect(container.read(addressNotifierProvider), hasLength(1));

        final updated = address.copyWith(instructions: 'Новая');
        expect(await notifier.updateAddress(updated), isNull);
        expect(container.read(addressNotifierProvider).first.instructions, 'Новая');

        expect(await notifier.deleteAddress(address.id!), isNull);
        expect(container.read(addressNotifierProvider), isEmpty);
      });

      test('updateAddress returns failure when id missing', () async {
        final notifier = container.read(addressNotifierProvider.notifier);
        final failure = await notifier.updateAddress(
          const AddressModel(
            formatted: 'Без id',
            lat: 55,
            lng: 37,
          ),
        );

        expect(failure, isA<Failure>());
        expect(
          failure?.message,
          contains('identifier'),
        );
      });
  });
}
