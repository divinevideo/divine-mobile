// ABOUTME: Tests the reference sweep that guards draft-local audio deletion.
// ABOUTME: Pins what counts as a reference and when reclaiming must refuse.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio, AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/local_audio_cleanup_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group(LocalAudioCleanupService, () {
    late Directory documents;
    late AppDatabase database;
    late SharedPreferences preferences;
    late DraftStorageService drafts;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      documents = Directory.systemTemp.createTempSync('local_audio_cleanup');
      originalPathProviderInstance = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documents.path);

      database = AppDatabase.test(NativeDatabase.memory());
      SavedSoundsService.resetLegacyMigrationClaimForTesting();
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      drafts = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProviderInstance;
      await database.close();
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });

    LocalAudioCleanupService createService({bool withPreferences = true}) =>
        LocalAudioCleanupService(
          draftsDao: database.draftsDao,
          clipsDao: database.clipsDao,
          preferences: withPreferences ? preferences : null,
        );

    File writeAudio(String relativePath) {
      final file = File(p.join(documents.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(const [0, 1, 2, 3]);
      return file;
    }

    AudioEvent localTrack({required String id, required String filePath}) =>
        AudioEvent.fromLocalImport(
          id: id,
          filePath: filePath,
          createdAt: 1700000000,
          title: 'Local audio',
          mimeType: 'audio/mp4',
        );

    Future<void> saveDraftWithAudio({
      required String id,
      required String audioPath,
      required String audioId,
    }) => drafts.saveDraft(
      DivineVideoDraft.create(
        id: id,
        clips: [
          DivineVideoClip(
            id: 'clip_$id',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime(2025),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Audio draft',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
        editorStateHistory: {
          'position': 0,
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [
                  localTrack(id: audioId, filePath: audioPath).toJson(),
                ],
              },
            },
          ],
        },
      ),
    );

    Future<void> saveSound({required String id, required String filePath}) =>
        SavedSoundsService(
          preferences,
          documentsPath: documents.path,
        ).saveSound(localTrack(id: id, filePath: filePath));

    /// Inserts a draft row whose `data` blob cannot be decoded, so the sweep
    /// cannot tell whether it referenced the file under test.
    Future<void> writeCorruptDraftRow() => database.draftsDao.upsertDraft(
      id: 'draft_corrupt',
      title: 'Corrupt',
      description: '',
      publishStatus: 'draft',
      createdAt: DateTime(2025),
      lastModified: DateTime(2025),
      renderedFilePath: null,
      renderedThumbnailPath: null,
      data: 'not json',
    );

    /// Replaces the current account's stored bucket with [raw], simulating a
    /// payload this build cannot decode.
    Future<void> writeRawSoundBucket(String raw) => preferences.setString(
      SavedSoundsService.accountStorageKey(''),
      raw,
    );

    group('savedSoundReferences', () {
      test('collects basenames from every account bucket', () async {
        await preferences.setString(
          SavedSoundsService.accountStorageKey('aa'),
          jsonEncode({
            'schemaVersion': 1,
            'sounds': [
              {
                'audio': localTrack(
                  id: 'local_import_other_account',
                  filePath: p.join(
                    documents.path,
                    'draft_audio_imports',
                    'd1',
                    'other.m4a',
                  ),
                ).toJson(),
              },
            ],
          }),
        );

        final references = createService().savedSoundReferences();

        expect(references.filenames, equals({'other.m4a'}));
        expect(references.isComplete, isTrue);
      });

      test('reports incomplete without preferences', () {
        final references = createService(
          withPreferences: false,
        ).savedSoundReferences();

        expect(references.filenames, isEmpty);
        expect(
          references.isComplete,
          isFalse,
          reason:
              'an instance that cannot read My Sounds has not proven '
              'anything about it',
        );
      });
    });

    group('referencedAudioFilenames', () {
      test('unions surviving drafts with every saved sound', () async {
        await saveDraftWithAudio(
          id: 'draft_a',
          audioPath: p.join(
            documents.path,
            'draft_audio_imports',
            'draft_a',
            'from_draft.m4a',
          ),
          audioId: 'local_import_draft',
        );
        await saveSound(
          id: 'local_import_saved',
          filePath: p.join(
            documents.path,
            'draft_audio_imports',
            'draft_a',
            'from_sound.m4a',
          ),
        );

        final references = await createService().referencedAudioFilenames();

        expect(
          references.filenames,
          equals({'from_draft.m4a', 'from_sound.m4a'}),
        );
        expect(references.isComplete, isTrue);
      });

      test('reports incomplete when a draft blob will not parse', () async {
        await saveDraftWithAudio(
          id: 'draft_ok',
          audioPath: p.join(
            documents.path,
            'draft_audio_imports',
            'draft_ok',
            'readable.m4a',
          ),
          audioId: 'local_import_ok',
        );
        await writeCorruptDraftRow();

        final references = await createService().referencedAudioFilenames();

        expect(
          references.filenames,
          contains('readable.m4a'),
          reason:
              'a corrupt sibling must not cost the readable draft its '
              'reference',
        );
        expect(references.isComplete, isFalse);
      });

      test(
        'reports incomplete when a saved-sound bucket will not decode',
        () async {
          await writeRawSoundBucket('{ not json');

          final references = await createService().referencedAudioFilenames();

          expect(references.filenames, isEmpty);
          expect(references.isComplete, isFalse);
        },
      );
    });

    group('reclaimUnreferencedAudio', () {
      test('deletes a file nothing references', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_gone', 'orphan.m4a'),
        );

        await createService().reclaimUnreferencedAudio(audio.path);

        expect(audio.existsSync(), isFalse);
      });

      test('keeps a file a surviving draft still references', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_live', 'shared.m4a'),
        );
        await saveDraftWithAudio(
          id: 'draft_live',
          audioPath: audio.path,
          audioId: 'local_import_shared',
        );

        await createService().reclaimUnreferencedAudio(audio.path);

        expect(
          audio.existsSync(),
          isTrue,
          reason: 'a draft still renders and plays this track',
        );
      });

      test('keeps a file another saved sound still references', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_autosave', 'twice_saved.m4a'),
        );
        await saveSound(id: 'local_import_survivor', filePath: audio.path);

        await createService().reclaimUnreferencedAudio(audio.path);

        expect(
          audio.existsSync(),
          isTrue,
          reason: 'a second My Sounds entry still points at this file',
        );
      });

      test('keeps a file when a draft blob could not be read', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_gone', 'unprovable.m4a'),
        );
        await writeCorruptDraftRow();

        await createService().reclaimUnreferencedAudio(audio.path);

        expect(
          audio.existsSync(),
          isTrue,
          reason:
              'an unreadable draft may hold the last reference, so the '
              'sweep cannot prove the file is an orphan',
        );
      });

      test(
        'keeps a file when a saved-sound bucket could not be read',
        () async {
          final audio = writeAudio(
            p.join('draft_audio_imports', 'draft_gone', 'foreign.m4a'),
          );
          await writeRawSoundBucket('{ not json');

          await createService().reclaimUnreferencedAudio(audio.path);

          expect(audio.existsSync(), isTrue);
        },
      );

      test('keeps a file when built without access to My Sounds', () async {
        final audio = writeAudio(
          p.join('draft_audio_imports', 'draft_gone', 'unchecked.m4a'),
        );

        await createService(
          withPreferences: false,
        ).reclaimUnreferencedAudio(audio.path);

        expect(audio.existsSync(), isTrue);
      });

      test("keeps a file outside this app's audio storage", () async {
        final audio = writeAudio(p.join('picker_cache', 'user_original.m4a'));

        await createService().reclaimUnreferencedAudio(audio.path);

        expect(
          audio.existsSync(),
          isTrue,
          reason:
              'a path that never went through an importer is not ours to '
              'reclaim, whatever nothing references it',
        );
      });

      test('ignores a null path', () async {
        await createService().reclaimUnreferencedAudio(null);

        expect(
          documents.listSync(),
          isEmpty,
          reason: 'nothing to reclaim must not create or remove anything',
        );
      });
    });
  });
}
