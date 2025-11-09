import 'dart:convert';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/home/providers/filter_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilterNotifier', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('restores saved filters on init', () async {
      final payload = jsonEncode(<String, dynamic>{
        'query': 'sushi',
        'minRating': 4.5,
      });
      await prefs.setString('filters', payload);

      container.read(filterProvider); // trigger notifier init
      await Future<void>.delayed(Duration.zero);

      final state = container.read(filterProvider);
      expect(state['query'], equals('sushi'));
      expect(state['minRating'], equals(4.5));
    });

    test('setters update state and save to preferences', () async {
      final notifier = container.read(filterProvider.notifier);

      notifier
        ..setQuery('  ramen  ')
        ..setCuisine(['italian', 'asian', ''])
        ..setPriceRange(100, 500)
        ..setRating(4)
        ..setDistance(12.5);
      await notifier.save();

      final state = container.read(filterProvider);
      expect(state['query'], equals('ramen'));
      expect(state['cuisines'], equals('italian,asian'));
      expect(state['minPrice'], equals(100));
      expect(state['maxPrice'], equals(500));
      expect(state['minRating'], equals(4));
      expect(state['maxDistance'], equals(12.5));

      final stored = prefs.getString('filters');
      expect(stored, isNotNull);
      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded['query'], equals('ramen'));
      expect(decoded['maxDistance'], equals(12.5));
    });

    test('clear removes state and persisted data', () async {
      final notifier = container.read(filterProvider.notifier);

      notifier
        ..setQuery('pizza')
        ..setRating(4);
      await notifier.save();
      expect(prefs.getString('filters'), isNotNull);

      await notifier.clear();
      final state = container.read(filterProvider);
      expect(state, isEmpty);
      expect(prefs.getString('filters'), isNull);
    });
  });
}
