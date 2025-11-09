import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/orders/providers/review_notifier.dart';
import 'package:eazy_client_mvp/models/review_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockReviewRepository extends Mock implements ReviewRepository {}

void main() {
  late ProviderContainer container;
  late MockReviewRepository repository;

  setUp(() {
    repository = MockReviewRepository();
    container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('submitReview возвращает null и вызывает репозиторий при успехе', () async {
    when(
      repository.submitReview(
        review: anyNamed('review'),
        photos: anyNamed('photos'),
      ),
    ).thenAnswer(
      (_) async => ReviewModel(
        orderId: 'order-1',
        venueId: 'venue-1',
        stars: 5,
        photoUrls: const ['https://example.com/review.jpg'],
      ),
    );

    final notifier = container.read(reviewProvider.notifier);
    final failure = await notifier.submitReview(
      orderId: 'order-1',
      venueId: 'venue-1',
      stars: 5,
      text: '  Отлично!  ',
      photos: const [],
    );

    expect(failure, isNull);

    final verification = verify(
      repository.submitReview(
        review: captureAnyNamed('review'),
        photos: captureAnyNamed('photos'),
      ),
    );
    verification.called(1);
    final capturedReview = verification.captured.first as ReviewModel;
    expect(capturedReview.orderId, equals('order-1'));
    expect(capturedReview.venueId, equals('venue-1'));
    expect(capturedReview.text, equals('Отлично!'));
    expect(capturedReview.stars, equals(5));
  });

  test('submitReview возвращает Failure, если репозиторий выбрасывает Failure', () async {
    const failureResponse = Failure(message: 'network');
    when(
      repository.submitReview(
        review: anyNamed('review'),
        photos: anyNamed('photos'),
      ),
    ).thenThrow(failureResponse);

    final notifier = container.read(reviewProvider.notifier);
    final failure = await notifier.submitReview(
      orderId: 'order-2',
      venueId: 'venue-2',
      stars: 4,
      text: 'OK',
      photos: const [],
    );

    expect(failure, equals(failureResponse));
  });

  test('submitReview не обращается к репозиторию при некорректной оценке', () async {
    final notifier = container.read(reviewProvider.notifier);
    final failure = await notifier.submitReview(
      orderId: 'order-3',
      venueId: 'venue-3',
      stars: 0,
      text: 'bad',
      photos: const [],
    );

    expect(failure, isA<Failure>());
    verifyNever(
      repository.submitReview(
        review: anyNamed('review'),
        photos: anyNamed('photos'),
      ),
    );
  });
}
