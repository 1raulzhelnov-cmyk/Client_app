import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/home/widgets/venue_list.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:eazy_client_mvp/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VenueList widget', () {
    late MockApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      apiService = MockApiService();
    });

    testWidgets('renders grid and loads more on scroll', (tester) async {
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
          <String, dynamic>{
            'id': 'venue-2',
            'name': 'Tokyo Line',
            'type': 'food',
            'rating': 4.4,
            'cuisines': ['японская'],
            'avgPrice': 1250,
            'photos': ['https://example.com/venue2.jpg'],
            'deliveryFee': 200,
            'deliveryTimeMinutes': '35-45',
            'address': <String, dynamic>{
              'id': 'addr-2',
              'formatted': 'Москва, Арбат, 4',
              'lat': 55.7522,
              'lng': 37.6156,
              'instructions': '',
              'isDefault': false,
            },
            'hours': <String, String>{'mon-sun': '11:00-22:00'},
          },
        ],
        'pagination': <String, dynamic>{'hasNext': true},
      };

      final secondPage = <String, dynamic>{
        'venues': [
          <String, dynamic>{
            'id': 'venue-3',
            'name': 'Sushi & Co',
            'type': 'food',
            'rating': 4.8,
            'cuisines': ['японская'],
            'avgPrice': 1350,
            'photos': ['https://example.com/venue3.jpg'],
            'deliveryFee': 180,
            'deliveryTimeMinutes': '30-40',
            'address': <String, dynamic>{
              'id': 'addr-3',
              'formatted': 'Москва, Смоленская, 12',
              'lat': 55.7495,
              'lng': 37.6074,
              'instructions': '',
              'isDefault': false,
            },
            'hours': <String, String>{'mon-sun': '10:00-23:00'},
          },
        ],
        'pagination': <String, dynamic>{'hasNext': false},
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
        return params['page'] == '1' ? right(firstPage) : right(secondPage);
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Bistro 24'), findsOneWidget);
      expect(find.text('Tokyo Line'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(find.byType(LoadingIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('Sushi & Co'), findsOneWidget);
      verify(
        apiService.get<Map<String, dynamic>>(
          '/venues',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(2);
    });
  });
}
