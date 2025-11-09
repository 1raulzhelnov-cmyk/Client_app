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

  group('Address management integration', () {
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

    test('addAddress posts to API and updates state', () async {
      const requestAddress = AddressModel(
        formatted: 'Москва, ул. Тверская, 1',
        lat: 55.757,
        lng: 37.615,
        instructions: 'Позвонить за 10 минут',
      );
      final expectedAddress = requestAddress.copyWith(id: 'addr-1');

      when(
        apiService.post<AddressModel>(
          any,
          body: anyNamed('body'),
          decoder: anyNamed('decoder'),
        ),
      ).thenAnswer((invocation) async {
        final decoder = invocation.namedArguments[#decoder]
            as AddressModel Function(dynamic)?;
        final decoded = decoder?.call(expectedAddress.toJson());
        return right(decoded ?? expectedAddress);
      });

      final notifier = container.read(addressNotifierProvider.notifier);
      final failure = await notifier.addAddress(requestAddress);

      expect(failure, isNull);
      final state = container.read(addressNotifierProvider);
      expect(state, hasLength(1));
      expect(state.first.id, equals(expectedAddress.id));
      verify(
        apiService.post<AddressModel>(
          '/addresses',
          body: requestAddress.toJson(),
          decoder: anyNamed('decoder'),
        ),
      ).called(1);
    });
  });
}
