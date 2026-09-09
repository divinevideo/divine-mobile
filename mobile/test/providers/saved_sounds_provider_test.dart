// ABOUTME: Tests the wiring of savedSoundsServiceProvider.
// ABOUTME: Pins the account bucket and the documents path the service reads.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(savedSoundsServiceProvider, () {
    const pubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const oldContainer = '/var/mobile/Containers/Data/Application/OLD';
    const newContainer = '/var/mobile/Containers/Data/Application/NEW';
    const relativePath = 'draft_audio_imports/draft_autosave/imported.m4a';

    late SharedPreferences preferences;
    late _MockAuthService authService;

    setUp(() async {
      SavedSoundsService.resetLegacyMigrationClaimForTesting();
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyHex);
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    ProviderContainer createContainer(String documentsPath) {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          sharedPreferencesProvider.overrideWithValue(preferences),
          documentsPathProvider.overrideWithValue(documentsPath),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('hands the service the container-relative documents path', () async {
      // Save on one launch...
      await createContainer(oldContainer)
          .read(savedSoundsServiceProvider)
          .saveSound(
            AudioEvent.fromLocalImport(
              id: 'local_import_1',
              filePath: '$oldContainer/$relativePath',
              createdAt: 1700000000,
              title: 'Imported sound',
              mimeType: 'audio/mp4',
            ),
          );

      // ...read it back on the launch after an iOS app update rewrote the
      // container path. Without the documents path the provider hands over,
      // the sound loads with a dangling url and plays nothing (#7977).
      final afterUpdate = createContainer(
        newContainer,
      ).read(savedSoundsServiceProvider);

      expect(
        afterUpdate.loadSounds().single.url,
        '$newContainer/$relativePath',
      );
    });

    group('audio reclamation', () {
      late Directory documents;
      late AppDatabase database;

      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        documents = Directory.systemTemp.createTempSync('saved_sounds_wiring');
        database = AppDatabase.test(NativeDatabase.memory());
      });

      tearDown(() async {
        await database.close();
        if (documents.existsSync()) documents.deleteSync(recursive: true);
      });

      SavedSoundsService createService() {
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(preferences),
            documentsPathProvider.overrideWithValue(documents.path),
            databaseProvider.overrideWithValue(database),
          ],
        );
        addTearDown(container.dispose);
        return container.read(savedSoundsServiceProvider);
      }

      File writeImportedAudio() {
        final file = File(p.join(documents.path, relativePath));
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      test('removing an imported sound reclaims its audio file', () async {
        final audio = writeImportedAudio();
        final service = createService();
        await service.saveSound(
          AudioEvent.fromLocalImport(
            id: 'local_import_1',
            filePath: audio.path,
            createdAt: 1700000000,
            title: 'Imported sound',
            mimeType: 'audio/mp4',
          ),
        );

        await service.removeSound('local_import_1');

        expect(
          audio.existsSync(),
          isFalse,
          reason:
              'the provider must wire a reclaimer, or the file leaks for '
              'the life of the install (#8025)',
        );
      });
    });
  });
}
