import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/home/providers/home_providers.dart';
import 'package:eazy_client_mvp/features/home/screens/home_tab.dart';
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

  testWidgets('search submission refreshes venue list with query',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final apiService = MockApiService();

    final capturedQueries = <Map<String, String>>[];

    when(
      apiService.get<Map<String, dynamic>>(
        any,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final params = Map<String, String>.from(
        invocation.namedArguments[#queryParameters] as Map,
      );
      capturedQueries.add(params);
      return right(<String, dynamic>{
        'venues': [
          <String, dynamic>{
            'id': 'venue-1',
            'name': 'Test Venue',
            'type': 'food',
            'rating': 4.6,
            'cuisines': ['итальянская'],
            'avgPrice': 900,
            'photos': ['https://example.com/1.jpg'],
            'deliveryFee': 150,
            'deliveryTimeMinutes': '20-30',
            'address': <String, dynamic>{
              'id': 'addr-1',
              'formatted': 'Москва, Тестовая, 1',
              'lat': 55.75,
              'lng': 37.61,
              'instructions': '',
              'isDefault': false,
            },
            'hours': <String, String>{'mon-fri': '10:00-22:00'},
          },
        ],
        'pagination': <String, dynamic>{'hasNext': false},
      });
    });

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => prefs),
        apiServiceProvider.overrideWithValue(apiService),
        homeRepositoryProvider
            .overrideWithValue(const HomeRepository(delay: Duration.zero)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeTab(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(capturedQueries, isNotEmpty);
    expect(capturedQueries.first['search'], isNull);

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    await tester.tap(textFieldFinder);
    await tester.pump();
    await tester.enterText(textFieldFinder, 'sushi');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final hasSearchQuery =
        capturedQueries.any((params) => params['search'] == 'sushi');
    expect(hasSearchQuery, isTrue);

    verify(
      apiService.get<Map<String, dynamic>>(
        '/venues',
        queryParameters: anyNamed('queryParameters'),
      ),
    ).called(greaterThanOrEqualTo(2));
  });
}
