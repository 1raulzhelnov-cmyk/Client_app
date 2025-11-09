import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/venue/screens/venue_detail_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VenueDetailScreen', () {
    late _MockApiService apiService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      apiService = _MockApiService();
    });

    testWidgets('отображает детали заведения и табы меню', (tester) async {
      final response = <String, dynamic>{
        'id': 'venue-321',
        'name': 'Городская трапезная',
        'type': 'food',
        'rating': 4.7,
        'cuisines': ['европейская'],
        'avgPrice': 780,
        'photos': [
          'https://example.com/images/venue-321-1.jpg',
          'https://example.com/images/venue-321-2.jpg',
        ],
        'deliveryFee': 120,
        'deliveryTimeMinutes': '25-35',
        'address': <String, dynamic>{
          'id': 'addr-1',
          'formatted': 'Москва, ул. Ленина, 15',
          'lat': 55.7522,
          'lng': 37.6156,
          'instructions': 'Позвонить за 10 минут',
          'isDefault': false,
        },
        'description': 'Сезонное меню, фермерские продукты и авторские напитки.',
        'isOpen': true,
        'hours': <String, String>{
          'mon-fri': '09:00-22:00',
          'sat-sun': '10:00-23:30',
        },
        'contacts': <String, String>{
          'phone': '+7 495 000-00-00',
          'website': 'https://gorodtrapeznaya.ru',
        },
        'menu': [
          <String, dynamic>{
            'id': 'soup-borscht',
            'venueId': 'venue-321',
            'name': 'Борщ с говядиной',
            'description': 'Подаётся со сметаной и пампушками',
            'price': 350,
            'imageUrl': '',
            'available': true,
            'category': 'Супы',
            'type': 'food',
          },
          <String, dynamic>{
            'id': 'dessert-napoleon',
            'venueId': 'venue-321',
            'name': 'Торт Наполеон',
            'description': 'Домашний десерт из хрустящих коржей',
            'price': 290,
            'imageUrl': '',
            'available': true,
            'category': 'Десерты',
            'type': 'food',
          },
        ],
      };

      when(
        apiService.get<Map<String, dynamic>>('/venues/venue-321'),
      ).thenAnswer((_) async => right(response));

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
            home: const VenueDetailScreen(venueId: 'venue-321'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('Городская трапезная'), findsWidgets);
      expect(find.text('+7 495 000-00-00'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Супы'), findsOneWidget);
      expect(find.text('Десерты'), findsOneWidget);
      expect(find.text('Борщ с говядиной'), findsOneWidget);
    });
  });
}
