import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:unified_logger/unified_logger.dart';

class _SecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = LogCaptureService();
  const key =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  List<String> timings() => capture
      .getRecentLogs()
      .where((entry) => entry.name == 'StartupTiming')
      .map((entry) => entry.message)
      .toList();

  setUp(capture.clearAllLogs);

  group('DatabaseEncryptionBootstrap.resolveCipherKey', () {
    test(
      'times the bootstrap boundaries without logging the cipher key',
      () async {
        final storage = _SecureStorage();
        when(() => storage.read(key: any(named: 'key')))
            .thenAnswer((_) async => key);
        final runtime = Completer<void>();
        final bootstrap = DatabaseEncryptionBootstrap(
          secureStorage: storage,
          ensureRuntime: () => runtime.future,
          isCipherAvailable: () => true,
          migrate: (_) async => CipherMigrationOutcome.alreadyEncrypted,
          canOpenEncryptedDatabase: (_) async => true,
        );
        final pending = bootstrap.resolveCipherKey();
        expect(timings(), contains('databaseRuntime started'));
        runtime.complete();
        expect(await pending, key);
        for (final stage in [
          'databaseRuntime',
          'databaseKey',
          'databaseMigration',
          'databaseProbe',
        ]) {
          expect(timings(), contains('$stage started'));
          expect(
            timings(),
            contains(
              matches('^$stage completed in [0-9]+ms outcome=success\$'),
            ),
          );
        }
        expect(timings().join(), isNot(contains(key)));
      },
    );

    test(
      'records failed stages while preserving the original failure',
      () async {
        final failure = StateError('private diagnostic content');
        final bootstrap = DatabaseEncryptionBootstrap(
          secureStorage: _SecureStorage(),
          ensureRuntime: () async => throw failure,
        );
        await expectLater(bootstrap.resolveCipherKey(), throwsA(same(failure)));
        expect(
          timings(),
          contains(
            matches(r'^databaseRuntime completed in [0-9]+ms outcome=failure$'),
          ),
        );
        expect(timings().join(), isNot(contains('private diagnostic content')));
      },
    );
  });

  group('createAppDatabase', () {
    test(
      'times the actual database open once across subsequent queries',
      () async {
        final db = createAppDatabase(cipherKey: null, corruptionService: null);
        addTearDown(db.close);
        await Future.wait([
          db.customSelect('SELECT 1').get(),
          db.customSelect('SELECT 2').get(),
        ]);
        await db.customSelect('SELECT 3').get();
        expect(
          timings().where((line) => line == 'databaseOpen started'),
          hasLength(1),
        );
        expect(
          timings().where((line) => line.startsWith('databaseOpen completed')),
          hasLength(1),
        );
      },
    );
  });
}
