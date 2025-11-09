import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/auth/providers/auth_notifier.dart';
import 'package:eazy_client_mvp/features/home/providers/home_providers.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/main.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(this._user);

  final UserModel _user;

  @override
  FutureOr<UserModel?> build() => _user;
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('переход со списка заведений на детальную страницу', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final mockAuth = _MockFirebaseAuth();
    when(mockAuth.authStateChanges()).thenAnswer(
      (_) => const Stream<User?>.empty(),
    );
    when(mockAuth.currentUser).thenReturn(null);

    final apiService = _MockApiService();

    final venuesListResponse = <String, dynamic>{
      'venues': [
        <String, dynamic>{
          'id': 'venue-1',
          'name': 'Test Bistro',
          'type': 'food',
          'rating': 4.5,
          'cuisines': ['авторская'],
          'avgPrice': 890,
          'photos': ['https://example.com/venue-1.jpg'],
          'deliveryFee': 150,
          'deliveryTimeMinutes': '25-35',
          'address': <String, dynamic>{
            'id': 'addr-1',
            'formatted': 'Москва, ул. Ленина, 5',
            'lat': 55.7522,
            'lng': 37.6156,
            'instructions': '',
            'isDefault': false,
          },
          'description': 'Лучшие обеды в городе.',
          'hours': <String, String>{'mon-fri': '09:00-22:00'},
        },
      ],
      'pagination': <String, dynamic>{'hasNext': false},
    };

    final venueDetailResponse = <String, dynamic>{
      'id': 'venue-1',
      'name': 'Test Bistro',
      'type': 'food',
      'rating': 4.5,
      'cuisines': ['авторская'],
      'avgPrice': 890,
      'photos': [
        'https://example.com/venue-1-1.jpg',
        'https://example.com/venue-1-2.jpg',
      ],
      'deliveryFee': 150,
      'deliveryTimeMinutes': '25-35',
      'address': <String, dynamic>{
        'id': 'addr-1',
        'formatted': 'Москва, ул. Ленина, 5',
        'lat': 55.7522,
        'lng': 37.6156,
        'instructions': '',
        'isDefault': false,
      },
      'description': 'Актуальное меню и быстрая доставка.',
      'isOpen': true,
      'hours': <String, String>{'mon-fri': '09:00-22:00'},
      'contacts': <String, String>{
        'phone': '+7 495 111-11-11',
        'instagram': '@testbistro',
      },
      'menu': [
        <String, dynamic>{
          'id': 'soup-1',
          'venueId': 'venue-1',
          'name': 'Сливочный суп',
          'description': 'Грибной крем-суп с сухариками',
          'price': 320,
          'imageUrl': '',
          'available': true,
          'category': 'Супы',
          'type': 'food',
        },
        <String, dynamic>{
          'id': 'main-1',
          'venueId': 'venue-1',
          'name': 'Стейк из индейки',
          'description': 'Подаётся с картофельным пюре',
          'price': 540,
          'imageUrl': '',
          'available': true,
          'category': 'Горячее',
          'type': 'food',
        },
      ],
    };

    when(
      apiService.get<Map<String, dynamic>>(
        any,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      if (path == '/venues') {
        return right(venuesListResponse);
      }
      if (path == '/venues/venue-1') {
        return right(venueDetailResponse);
      }
      return right(<String, dynamic>{});
    });

    const user = UserModel(
      id: 'user-1',
      name: 'Test User',
      email: 'user@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          authNotifierProvider.overrideWith(() => _StaticAuthNotifier(user)),
          apiServiceProvider.overrideWithValue(apiService),
          homeRepositoryProvider
              .overrideWithValue(const HomeRepository(delay: Duration.zero)),
        ],
        child: const EazyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Test Bistro'), findsWidgets);

    await tester.tap(find.text('Test Bistro').first);
    await tester.pumpAndSettle();

    final l10n = await S.load(const Locale('ru'));
    expect(find.text(l10n.contactInfo), findsOneWidget);
    expect(find.text('+7 495 111-11-11'), findsOneWidget);
    expect(find.text('Супы'), findsOneWidget);
    expect(find.text('Горячее'), findsOneWidget);

    verify(
      apiService.get<Map<String, dynamic>>(
        '/venues',
        queryParameters: anyNamed('queryParameters'),
      ),
    ).called(greaterThanOrEqualTo(1));
    verify(
      apiService.get<Map<String, dynamic>>('/venues/venue-1'),
    ).called(1);
  });
}
