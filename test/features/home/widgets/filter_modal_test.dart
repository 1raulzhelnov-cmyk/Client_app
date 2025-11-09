import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/home/providers/filter_notifier.dart';
import 'package:eazy_client_mvp/features/home/widgets/filter_modal.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/venue_model.dart';
import 'package:eazy_client_mvp/features/home/providers/venue_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVenueNotifier extends AutoDisposeAsyncNotifier<List<VenueModel>> {
  @override
  Future<List<VenueModel>> build() async => const <VenueModel>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('filter modal updates filter provider on apply', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => prefs),
        venueNotifierProvider.overrideWith(_FakeVenueNotifier.new),
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
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => showFilterModal(context, ref),
                    child: const Text('Открыть фильтры'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть фильтры'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Italian'));
    await tester.pump();

    await tester.tap(find.text('Применить фильтры'));
    await tester.pumpAndSettle();

    final state = container.read(filterProvider);
    expect(state['cuisines'], equals('italian'));
    expect(prefs.getString('filters'), isNotNull);
  });
}
