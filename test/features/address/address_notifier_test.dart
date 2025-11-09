import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
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
  });
}
