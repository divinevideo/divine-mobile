import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/sound_requests/sound_request_drift_store.dart';

void main() {
  group('account workflow persistence', () {
    late AppDatabase db;
    late bool previousWarning;
    setUp(() {
      previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase.test(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
    });

    test(
      'round trips all sections and removes only changed account rows',
      () async {
        final store = SoundRequestDriftStore(db.soundRequestStateDao);
        const request = SoundRequestEntry(
          id: 'request',
          requester: 'viewer',
          videoAddress: 'video',
        );
        const job = SoundRequestSendIntent(
          key: 'job',
          recipient: 'creator',
          content: 'request',
          tags: [],
          createdAt: 1,
          videoAddress: 'video',
        );
        const snapshot = SoundRequestSnapshot(
          requests: {'request': request},
          jobs: {'job': job},
          audioByVideo: {'video': 'audio'},
          approvedVideos: {'video'},
          metadataPublishedVideos: {'video'},
          metadataBaselineByVideo: {'video': 'revision'},
        );
        await store.write('owner', snapshot);
        await store.write('other', snapshot);
        final restored = SoundRequestDriftStore(db.soundRequestStateDao);
        expect(await restored.read('owner'), snapshot);
        final changed = snapshot.copyWith(jobs: {}, approvedVideos: {});
        await restored.write('owner', changed);
        expect(await restored.read('owner'), changed);
        expect(await restored.read('other'), snapshot);
        expect(
          await db.soundRequestStateDao.readAccount('owner'),
          hasLength(4),
        );
        await db.soundRequestStateDao.clearAccount('owner');
        expect(await restored.read('owner'), const SoundRequestSnapshot());
        expect(await restored.read('other'), snapshot);
      },
    );
  });
}
