import 'package:eazy_client_mvp/core/errors/failure.dart';
import 'package:eazy_client_mvp/features/address/providers/address_notifier.dart';
import 'package:eazy_client_mvp/features/address/screens/address_list_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/address_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _StubAddressNotifier extends AddressNotifier {
  _StubAddressNotifier(this.initialAddresses);

  final List<AddressModel> initialAddresses;
  String? lastDeletedId;

  @override
  List<AddressModel> build() => initialAddresses;

  @override
  Future<Failure?> fetchAddresses() async {
    state = initialAddresses;
    return null;
  }

  @override
  Future<Failure?> deleteAddress(String id) async {
    lastDeletedId = id;
    state = state.where((address) => address.id != id).toList();
    return null;
  }
}

class _FailingAddressNotifier extends AddressNotifier {
  @override
  List<AddressModel> build() => const [];

  @override
  Future<Failure?> fetchAddresses() async {
    state = const [];
    return const Failure(message: 'Ошибка загрузки адресов');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddressListScreen', () {
    testWidgets('renders addresses and handles delete', (tester) async {
      final l10n = await S.load(const Locale('ru'));
      const address = AddressModel(
        id: 'addr-1',
        formatted: 'Москва, ул. Тверская, 1',
        lat: 55.757,
        lng: 37.615,
        instructions: 'Позвонить за 10 минут',
      );
      final notifier = _StubAddressNotifier(const [address]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addressNotifierProvider.overrideWith(() => notifier),
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
            home: const AddressListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(address.formatted), findsOneWidget);
      expect(find.text(address.instructions!), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(notifier.lastDeletedId, equals(address.id));
      expect(find.text(l10n.addressDeleted), findsOneWidget);
    });

    testWidgets('показывает пустой стейт при отсутствии адресов', (tester) async {
      final l10n = await S.load(const Locale('ru'));
      final notifier = _StubAddressNotifier(const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addressNotifierProvider.overrideWith(() => notifier),
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
            home: const AddressListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(l10n.addressListEmpty), findsOneWidget);
    });

    testWidgets('отображает snackbar при ошибке загрузки', (tester) async {
      final l10n = await S.load(const Locale('ru'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addressNotifierProvider.overrideWith(_FailingAddressNotifier.new),
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
            home: const AddressListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ошибка загрузки адресов'), findsOneWidget);
      expect(find.text(l10n.addressListEmpty), findsOneWidget);
    });
  });
}
