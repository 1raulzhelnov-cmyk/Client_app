import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/home/widgets/venue_list.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Venue pagination integration', () {
    late MockApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      apiService = MockApiService();
    });

    testWidgets('keeps previous data and shows error banner on loadMore failure',
        (tester) async {
      final firstPage = <String, dynamic>{
        'venues': [
          <String, dynamic>{
            'id': 'venue-1',
            'name': 'Bistro 24',
            'type': 'food',
            'rating': 4.6,
            'cuisines': ['авторская'],
            'avgPrice': 890,
            'photos': ['https://example.com/venue1.jpg'],
            'deliveryFee': 150,
            'deliveryTimeMinutes': '25-35',
            'address': <String, dynamic>{
              'id': 'addr-1',
              'formatted': 'Москва, Тверская, 5',
              'lat': 55.7558,
              'lng': 37.6173,
              'instructions': '',
              'isDefault': false,
            },
            'hours': <String, String>{'mon-fri': '10:00-23:00'},
          },
        ],
        'pagination': <String, dynamic>{'hasNext': true},
      };

      when(
        apiService.get<Map<String, dynamic>>(
          any,
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = Map<String, String>.from(
          invocation.namedArguments[#queryParameters] as Map,
        );
        if (params['page'] == '1') {
          return right(firstPage);
        }
        return left(
          ServerFailure(message: 'Ошибка сервера', statusCode: 500),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(apiService),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: S.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: VenueList(type: 'food'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Bistro 24'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Bistro 24'), findsOneWidget);
      expect(find.text('Ошибка сервера'), findsOneWidget);
      expect(find.text('Sushi & Co'), findsNothing);

      verify(
        apiService.get<Map<String, dynamic>>(
          '/venues',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(2);
    });
  });
}
