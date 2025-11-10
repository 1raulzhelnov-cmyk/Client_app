import 'dart:io';

import 'package:eazy_client_mvp/core/di/providers.dart';
import 'package:eazy_client_mvp/features/profile/providers/profile_notifier.dart';
import 'package:eazy_client_mvp/features/profile/screens/edit_profile_screen.dart';
import 'package:eazy_client_mvp/generated/l10n.dart';
import 'package:eazy_client_mvp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker(this._file);

  final XFile? _file;
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.camera,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    return _file;
  }
}

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.initialUser);

  final UserModel initialUser;
    bool uploadPhotoCalled = false;
    bool deleteAccountCalled = false;
    Map<String, dynamic>? lastUpdatedData;

  @override
  Future<UserModel> build() async => initialUser;

  @override
  Future<String> uploadPhoto(File file) async {
    uploadPhotoCalled = true;
    state = AsyncData(
      initialUser.copyWith(photoUrl: file.path),
    );
    return file.path;
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
      lastUpdatedData = data;
    state = AsyncData(
      initialUser.copyWith(
        name: data['name'] as String? ?? initialUser.name,
        phone: data['phone'] as String? ?? initialUser.phone,
        photoUrl: data['photoUrl'] as String? ?? initialUser.photoUrl,
      ),
    );
  }

  @override
    Future<void> deleteAccount() async {
      deleteAccountCalled = true;
    }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditProfileScreen', () {
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('profile_test');
      tempFile = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([0]);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('picks photo from gallery and calls uploadPhoto', (tester) async {
      final l10n = await S.load(const Locale('ru'));
      final user = const UserModel(
        id: 'uid-123',
        name: 'Tester',
        email: 'test@example.com',
      );
      final notifier = _StubProfileNotifier(user);
      final imagePicker = _FakeImagePicker(XFile(tempFile.path));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith(() => notifier),
            imagePickerProvider.overrideWithValue(imagePicker),
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
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.changePhoto));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.photoSourceGallery));
      await tester.pumpAndSettle();

      expect(imagePicker.lastSource, ImageSource.gallery);
      expect(notifier.uploadPhotoCalled, isTrue);
    });

      testWidgets('submits updated profile values', (tester) async {
        final l10n = await S.load(const Locale('ru'));
        final user = const UserModel(
          id: 'uid-123',
          name: 'Tester',
          email: 'test@example.com',
          phone: '+79001112233',
        );
        final notifier = _StubProfileNotifier(user);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileNotifierProvider.overrideWith(() => notifier),
              imagePickerProvider.overrideWithValue(ImagePicker()),
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
              home: const EditProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.bySemanticsLabel(l10n.fullNameField),
          '  Новое имя  ',
        );
        await tester.enterText(
          find.bySemanticsLabel(l10n.phoneField),
          '+79991234567',
        );

        await tester.tap(find.text(l10n.saveChanges));
        await tester.pumpAndSettle();

        expect(notifier.lastUpdatedData?['name'], 'Новое имя');
        expect(notifier.lastUpdatedData?['phone'], '+79991234567');
        expect(
          notifier.state.value?.name,
          'Новое имя',
        );
      });

      testWidgets('delete account confirmation triggers notifier', (tester) async {
        final l10n = await S.load(const Locale('ru'));
        final user = const UserModel(
          id: 'uid-123',
          name: 'Tester',
          email: 'test@example.com',
        );
        final notifier = _StubProfileNotifier(user);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileNotifierProvider.overrideWith(() => notifier),
              imagePickerProvider.overrideWithValue(ImagePicker()),
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
              home: const EditProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.deleteAccount));
        await tester.pumpAndSettle();

        expect(find.text(l10n.confirmDeletionTitle), findsOneWidget);

        await tester.tap(find.text(l10n.delete));
        await tester.pumpAndSettle();

        expect(notifier.deleteAccountCalled, isTrue);
      });
  });
}
