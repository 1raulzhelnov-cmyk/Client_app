import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/flowers/screens/flower_catalog_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seasonal chip selection updates season query parameter',
      (tester) async {
    final apiService = MockApiService();
    final capturedParams = <Map<String, String>>[];

    when(
      apiService.get<dynamic>(
        any,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final params = Map<String, String>.from(
        invocation.namedArguments[#queryParameters] as Map,
      );
      capturedParams.add(params);

      return right([
        <String, dynamic>{
          'id': 'flower-${params['season'] ?? params['occasion']}',
          'venueId': 'venue-${params['occasion'] ?? 'unknown'}',
          'name': 'Коллекция ${params['season'] ?? params['occasion']}',
          'description': 'Демонстрационный букет',
          'price': 2990,
          'imageUrl': '',
          'occasion': params['occasion'] ?? '',
          'season': params['season'] ?? '',
        },
      ]);
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
            body: FlowerCatalogScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Сезонные'));
    await tester.pumpAndSettle();

    final seasonalCalls = capturedParams
        .where((params) => params['occasion'] == 'seasonal')
        .toList();

    expect(seasonalCalls, isNotEmpty);
    expect(seasonalCalls.first['season'], equals('spring'));

    await tester.tap(find.text('Лето'));
    await tester.pumpAndSettle();

    final updatedSeasonalCalls = capturedParams
        .where((params) => params['occasion'] == 'seasonal')
        .toList();

    expect(updatedSeasonalCalls.length, greaterThan(1));
    expect(updatedSeasonalCalls.last['season'], equals('summer'));

    verify(
      apiService.get<dynamic>(
        '/products',
        queryParameters: anyNamed('queryParameters'),
      ),
    ).called(greaterThanOrEqualTo(2));
  });
}
