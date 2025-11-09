import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/orders/providers/review_notifier.dart';
import 'package:eazy_client_mvp/services/api/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockApiService extends Mock implements ApiService {}

class FakeFirebaseStorage extends Fake implements FirebaseStorage {}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ReviewNotifier отправляет фото и вызывает API с URL из хранилища',
      () async {
    final apiService = MockApiService();
    final uploadedFiles = <List<File>>[];

    when(
      apiService.post<Map<String, dynamic>?>(
        any,
        body: anyNamed('body'),
        decoder: anyNamed('decoder'),
      ),
    ).thenAnswer((invocation) async {
      final decoder = invocation.namedArguments[#decoder]
          as Map<String, dynamic>? Function(dynamic)?;
      final response = <String, dynamic>{
        'id': 'review-1',
        'orderId': 'order-1',
        'venueId': 'venue-1',
        'stars': 5,
        'photoUrls': const ['https://example.com/photo.jpg'],
      };
      return right(decoder?.call(response) ?? response);
    });

    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(apiService),
        firebaseStorageProvider.overrideWithValue(FakeFirebaseStorage()),
        firebaseAuthProvider.overrideWithValue(FakeFirebaseAuth()),
        reviewRepositoryProvider.overrideWith((ref) {
          final api = ref.watch(apiServiceProvider);
          final storage = ref.watch(firebaseStorageProvider);
          final auth = ref.watch(firebaseAuthProvider);
          return ReviewRepository(
            apiService: api,
            firebaseStorage: storage,
            firebaseAuth: auth,
            uploadOverride: ({required files, required orderId}) async {
              uploadedFiles.add(files);
              return files
                  .map(
                    (file) => 'https://example.com/${file.uri.pathSegments.last}',
                  )
                  .toList();
            },
          );
        }),
      ],
    );

    addTearDown(container.dispose);

    final notifier = container.read(reviewProvider.notifier);
    final photoFile = File('review_photo.jpg');
    final failure = await notifier.submitReview(
      orderId: 'order-1',
      venueId: 'venue-1',
      stars: 4,
      text: 'Great service',
      photos: [photoFile],
    );

    expect(failure, isNull);
    expect(uploadedFiles, hasLength(1));
    expect(uploadedFiles.first, hasLength(1));
    expect(uploadedFiles.first.first.uri.pathSegments.last, 'review_photo.jpg');

    final verification = verify(
      apiService.post<Map<String, dynamic>?>(
        '/reviews',
        body: captureAnyNamed('body'),
        decoder: anyNamed('decoder'),
      ),
    );
    verification.called(1);
    final payload = verification.captured.first as Map<String, dynamic>;
    expect(payload['orderId'], equals('order-1'));
    expect(payload['photoUrls'], isA<List>());
    expect((payload['photoUrls'] as List).first,
        equals('https://example.com/review_photo.jpg'));
  });
}
