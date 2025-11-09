import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../models/review_model.dart';
import '../../../services/api/api_service.dart';

typedef ReviewPhotoUploader = Future<List<String>> Function({
  required List<File> files,
  required String orderId,
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final firebaseStorage = ref.watch(firebaseStorageProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return ReviewRepository(
    apiService: apiService,
    firebaseStorage: firebaseStorage,
    firebaseAuth: firebaseAuth,
  );
});

final reviewProvider =
    NotifierProvider<ReviewNotifier, void>(ReviewNotifier.new);

final venueReviewsProvider =
    AutoDisposeFutureProvider.family<List<ReviewModel>, String>(
  (ref, venueId) async {
    final repository = ref.watch(reviewRepositoryProvider);
    return repository.fetchReviews(venueId);
  },
);

class ReviewNotifier extends Notifier<void> {
  late final ReviewRepository _repository;

  @override
  void build() {
    _repository = ref.read(reviewRepositoryProvider);
  }

  Future<Failure?> submitReview({
    required String orderId,
    required String venueId,
    required int stars,
    String? text,
    List<File> photos = const <File>[],
  }) async {
    final normalizedStars = stars.clamp(0, 5);
    if (normalizedStars < 1 || normalizedStars > 5) {
      return const Failure(message: 'Поставьте оценку от 1 до 5.');
    }

    final trimmedText = text?.trim();
    final review = ReviewModel(
      orderId: orderId,
      venueId: venueId,
      stars: normalizedStars,
      text: trimmedText?.isEmpty ?? true ? null : trimmedText,
    );

    try {
      final created = await _repository.submitReview(
        review: review,
        photos: photos,
      );
      final targetVenueId = created?.venueId ?? venueId;
      if (targetVenueId != null && targetVenueId.isNotEmpty) {
        ref.invalidate(venueReviewsProvider(targetVenueId));
      } else {
        ref.invalidate(venueReviewsProvider(venueId));
      }
      return null;
    } on Failure catch (failure) {
      return failure;
    } catch (error, stackTrace) {
      debugPrint('Review submission error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return Failure(message: error.toString());
    }
  }
}

class ReviewRepository {
  ReviewRepository({
    required ApiService apiService,
    required FirebaseStorage firebaseStorage,
    required FirebaseAuth firebaseAuth,
    ReviewPhotoUploader? uploadOverride,
  })  : _apiService = apiService,
        _firebaseStorage = firebaseStorage,
        _firebaseAuth = firebaseAuth,
        _uploadOverride = uploadOverride;

  final ApiService _apiService;
  final FirebaseStorage _firebaseStorage;
  final FirebaseAuth _firebaseAuth;
  final ReviewPhotoUploader? _uploadOverride;

  Future<List<ReviewModel>> fetchReviews(String venueId) async {
    final result = await _apiService.get<List<dynamic>>(
      '/reviews',
      queryParameters: <String, String>{
        'venueId': venueId,
      },
      decoder: (dynamic data) => _ensureList(data),
    );
    return result.fold(
      (failure) => throw failure,
        (data) {
          if (data == null || data.isEmpty) {
            return const <ReviewModel>[];
          }
          final list = _extractReviewList(data);
        return list
            .map(
              (raw) => ReviewModel.fromJson(
                Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
              ),
            )
            .toList()
          ..sort((a, b) {
            final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final second =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return second.compareTo(first);
          });
      },
    );
  }

  Future<ReviewModel?> submitReview({
    required ReviewModel review,
    List<File> photos = const <File>[],
  }) async {
    final uploaded = await _uploadPhotos(
      files: photos,
      orderId: review.orderId,
    );

    final payload = review.copyWith(
      photoUrls: <String>[
        ...review.photoUrls,
        ...uploaded,
      ],
    );

    final response = await _apiService.post<Map<String, dynamic>?>(
      '/reviews',
      body: payload.toJson(),
      decoder: (dynamic data) {
        if (data == null) {
          return null;
        }
        if (data is Map<String, dynamic>) {
          return data;
        }
        if (data is Map) {
          return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
        }
        return null;
      },
    );

    return response.fold(
      (failure) => throw failure,
      (json) {
        if (json == null) {
          return null;
        }
        return ReviewModel.fromJson(json);
      },
    );
  }

  Future<List<String>> _uploadPhotos({
    required List<File> files,
    required String orderId,
  }) async {
    if (files.isEmpty) {
      return const <String>[];
    }

    final override = _uploadOverride;
    if (override != null) {
      return override(
        files: files,
        orderId: orderId,
      );
    }

    if (kIsWeb) {
      throw const Failure(
        message: 'Загрузка фото отзывов в веб-версии пока не поддерживается.',
      );
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const Failure(message: 'Пользователь не авторизован.');
    }

    final downloadUrls = <String>[];
    for (final file in files) {
      final originalName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'photo.jpg';
      final sanitizedName = _sanitizeFileName(originalName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'reviews/${user.uid}/$orderId/${timestamp}_$sanitizedName'.toLowerCase();

      try {
        final ref = _firebaseStorage.ref().child(path);
        final metadata = SettableMetadata(
          contentType: _resolveContentType(sanitizedName),
        );
        await ref.putFile(file, metadata);
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      } on FirebaseException catch (error, stackTrace) {
        debugPrint('Upload review photo error: ${error.message}');
        debugPrintStack(stackTrace: stackTrace);
        throw Failure(
          message: error.message ?? 'Не удалось загрузить фото отзыва.',
          code: error.code,
        );
      }
    }

    return downloadUrls;
  }

  List<dynamic> _ensureList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map) {
      for (final key in const ['reviews', 'data', 'items', 'result']) {
        final value = data[key];
        if (value is List) {
          return value;
        }
      }
      return data.values.whereType<List>().expand((value) => value).toList();
    }
    if (data == null) {
      return const <dynamic>[];
    }
    return <dynamic>[data];
  }

  List<dynamic> _extractReviewList(List<dynamic> raw) {
    if (raw.isEmpty) {
      return const <dynamic>[];
    }
    if (raw.first is Map) {
      return raw;
    }
    return raw
        .whereType<Map>()
        .expand<List<dynamic>>((element) {
          final values = element.values.whereType<List>();
          if (values.isEmpty) {
            return const <dynamic>[];
          }
          return values.expand((value) => value);
        })
        .toList();
  }

  String _sanitizeFileName(String input) {
    final withoutSpaces = input.replaceAll(' ', '_');
    return withoutSpaces.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
  }

  String _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }
}
