// ABOUTME: Tests for RecordingGalleryBackupService — gallery copies of takes
// ABOUTME: Covers signed, late-signed and unsignable recordings (#10067)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/clip_gallery_backup.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:openvine/services/recording_gallery_backup_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

/// The library entries the service reads and writes, kept in memory so a
/// status the service writes is what its next read sees.
class _FakeClipLibrary extends Fake implements ClipLibraryService {
  final clips = <String, DivineVideoClip>{};

  @override
  Future<DivineVideoClip?> getClipById(String id) async => clips[id];

  @override
  Future<List<DivineVideoClip>> getAllClips() async => [
    for (final clip in clips.values)
      if (clip.deletedAt == null) clip,
  ];

  @override
  Future<bool> setGalleryBackup({
    required String clipId,
    required ClipGalleryBackup? backup,
  }) async {
    final clip = clips[clipId];
    if (clip == null) return false;
    clips[clipId] = backup == null
        ? clip.copyWith(clearGalleryBackup: true)
        : clip.copyWith(galleryBackup: backup);
    return true;
  }
}

const _signedProof = NativeProofData(
  videoHash: 'a1b2c3',
  c2paManifestId: 'urn:c2pa:capture',
);
const _unsignedProof = NativeProofData(videoHash: 'a1b2c3');

void main() {
  setUpAll(() {
    registerFallbackValue(EditorVideo.file(''));
  });

  group(RecordingGalleryBackupService, () {
    late Directory tempDir;
    late SharedPreferences prefs;
    late _FakeClipLibrary library;
    late _MockGallerySaveService gallery;
    late Set<String> signedFiles;
    late List<C2paEditSource> signAttempts;
    late bool signingRuns;
    late bool buildCanSign;
    late bool signerReady;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('gallery_backup_test_');
      SharedPreferences.setMockInitialValues({
        RecordingGalleryBackupPreferenceService.prefsKey: true,
      });
      prefs = await SharedPreferences.getInstance();
      library = _FakeClipLibrary();
      gallery = _MockGallerySaveService();
      when(
        () => gallery.saveVideoToGallery(
          any(),
          requestPermission: any(named: 'requestPermission'),
        ),
      ).thenAnswer((_) async => const GallerySaveSuccess());
      signedFiles = {};
      signAttempts = [];
      signingRuns = true;
      buildCanSign = true;
      signerReady = true;
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    RecordingGalleryBackupService buildService() =>
        RecordingGalleryBackupService(
          preferences: RecordingGalleryBackupPreferenceService(prefs),
          gallerySaveService: gallery,
          clipLibrary: () => library,
          canSignNow: () => signerReady,
          buildCanSign: () => buildCanSign,
          hasCredential: (path) async => signedFiles.contains(path),
          signRecording: (recording) async {
            signAttempts.add(recording);
            if (!signingRuns) return true;
            signedFiles.add(recording.path);
            return false;
          },
        );

    String recordingFile(String name) {
      final file = File('${tempDir.path}/$name')..writeAsBytesSync([0, 1, 2]);
      return file.path;
    }

    DivineVideoClip libraryClip(
      String id,
      String recordingPath, {
      ClipGalleryBackupStatus? backupStatus,
      DateTime? deletedAt,
    }) {
      final clip = DivineVideoClip(
        id: id,
        video: EditorVideo.file(recordingPath),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026, 10, 13),
        targetAspectRatio: .square,
        originalAspectRatio: 9 / 16,
        deletedAt: deletedAt,
        galleryBackup: backupStatus == null
            ? null
            : ClipGalleryBackup(
                status: backupStatus,
                recordingPath: recordingPath,
              ),
      );
      library.clips[id] = clip;
      return clip;
    }

    ClipGalleryBackupStatus? statusOf(String id) =>
        library.clips[id]?.galleryBackup?.status;

    void verifyCopied(String path, {int times = 1}) {
      verify(
        () => gallery.saveVideoToGallery(
          any(
            that: isA<EditorVideo>().having(
              (video) => video.file?.path,
              'path',
              path,
            ),
          ),
          requestPermission: false,
        ),
      ).called(times);
    }

    void verifyNothingCopied() => verifyNever(
      () => gallery.saveVideoToGallery(
        any(),
        requestPermission: any(named: 'requestPermission'),
      ),
    );

    group('backUpRecording', () {
      test(
        'copies a signed recording without prompting and marks it saved',
        () async {
          final path = recordingFile('VID_1.mp4');
          libraryClip('clip_1', path);

          await buildService().backUpRecording(
            clipId: 'clip_1',
            recordingPath: path,
            proof: _signedProof,
          );

          verifyCopied(path);
          expect(statusOf('clip_1'), ClipGalleryBackupStatus.saved);
        },
      );

      test('holds back a recording whose signing failed', () async {
        final path = recordingFile('VID_1.mp4');
        libraryClip('clip_1', path);

        await buildService().backUpRecording(
          clipId: 'clip_1',
          recordingPath: path,
          proof: _unsignedProof,
        );

        verifyNothingCopied();
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.pending);
      });

      test(
        'copies and flags a recording this build can never sign',
        () async {
          buildCanSign = false;
          final path = recordingFile('VID_1.mp4');
          libraryClip('clip_1', path);

          await buildService().backUpRecording(
            clipId: 'clip_1',
            recordingPath: path,
            proof: _unsignedProof,
          );

          verifyCopied(path);
          expect(statusOf('clip_1'), ClipGalleryBackupStatus.savedUnsigned);
        },
      );

      test('copies a recording with no capture proof as unsigned', () async {
        final path = recordingFile('VID_1.mp4');
        libraryClip('clip_1', path);

        await buildService().backUpRecording(
          clipId: 'clip_1',
          recordingPath: path,
          proof: null,
        );

        verifyCopied(path);
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.savedUnsigned);
      });

      test('keeps the backup pending when the copy fails', () async {
        when(
          () => gallery.saveVideoToGallery(
            any(),
            requestPermission: any(named: 'requestPermission'),
          ),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());
        final path = recordingFile('VID_1.mp4');
        libraryClip('clip_1', path);

        await buildService().backUpRecording(
          clipId: 'clip_1',
          recordingPath: path,
          proof: _signedProof,
        );

        expect(statusOf('clip_1'), ClipGalleryBackupStatus.pending);
      });

      test('waits for a take in the trash to be restored', () async {
        final path = recordingFile('VID_1.mp4');
        libraryClip('clip_1', path, deletedAt: DateTime(2026, 10, 13));

        await buildService().backUpRecording(
          clipId: 'clip_1',
          recordingPath: path,
          proof: _signedProof,
        );

        verifyNothingCopied();
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.pending);
      });

      test('does nothing while the setting is off', () async {
        await prefs.setBool(
          RecordingGalleryBackupPreferenceService.prefsKey,
          false,
        );
        final path = recordingFile('VID_1.mp4');
        libraryClip('clip_1', path);

        await buildService().backUpRecording(
          clipId: 'clip_1',
          recordingPath: path,
          proof: _signedProof,
        );

        verifyNothingCopied();
        expect(statusOf('clip_1'), isNull);
      });

      test(
        'finishes earlier pending backups once a new take was signed',
        () async {
          final earlier = recordingFile('VID_0.mp4');
          libraryClip(
            'clip_0',
            earlier,
            backupStatus: ClipGalleryBackupStatus.pending,
          );
          final path = recordingFile('VID_1.mp4');
          libraryClip('clip_1', path);

          await buildService().backUpRecording(
            clipId: 'clip_1',
            recordingPath: path,
            proof: _signedProof,
          );
          await pumpEventQueue();

          expect(signAttempts.map((source) => source.path), [earlier]);
          verifyCopied(earlier);
          expect(statusOf('clip_0'), ClipGalleryBackupStatus.saved);
        },
      );
    });

    group('finishPendingBackups', () {
      test('signs a pending recording late, then copies it', () async {
        final path = recordingFile('VID_1.mp4');
        libraryClip(
          'clip_1',
          path,
          backupStatus: ClipGalleryBackupStatus.pending,
        );

        await buildService().finishPendingBackups();

        expect(signAttempts.map((source) => source.path), [path]);
        verifyCopied(path);
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.saved);
      });

      test('stops at the first recording whose signing cannot run', () async {
        signingRuns = false;
        final first = recordingFile('VID_1.mp4');
        final second = recordingFile('VID_2.mp4');
        libraryClip(
          'clip_1',
          first,
          backupStatus: ClipGalleryBackupStatus.pending,
        );
        libraryClip(
          'clip_2',
          second,
          backupStatus: ClipGalleryBackupStatus.pending,
        );

        await buildService().finishPendingBackups();

        expect(signAttempts, hasLength(1));
        verifyNothingCopied();
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.pending);
        expect(statusOf('clip_2'), ClipGalleryBackupStatus.pending);
      });

      test('waits for a signer that can name the account', () async {
        signerReady = false;
        final path = recordingFile('VID_1.mp4');
        libraryClip(
          'clip_1',
          path,
          backupStatus: ClipGalleryBackupStatus.pending,
        );

        await buildService().finishPendingBackups();

        expect(signAttempts, isEmpty);
        verifyNothingCopied();
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.pending);
      });

      test(
        'copies a recording signed meanwhile without signing it again',
        () async {
          signerReady = false;
          final path = recordingFile('VID_1.mp4');
          signedFiles.add(path);
          libraryClip(
            'clip_1',
            path,
            backupStatus: ClipGalleryBackupStatus.pending,
          );

          await buildService().finishPendingBackups();

          expect(signAttempts, isEmpty);
          verifyCopied(path);
          expect(statusOf('clip_1'), ClipGalleryBackupStatus.saved);
        },
      );

      test(
        'copies a recording that no longer qualifies as a capture as '
        'unsigned',
        () async {
          final path = recordingFile('VID_1.mp4');
          libraryClip(
            'clip_1',
            path,
            backupStatus: ClipGalleryBackupStatus.pending,
          );
          final service = RecordingGalleryBackupService(
            preferences: RecordingGalleryBackupPreferenceService(prefs),
            gallerySaveService: gallery,
            clipLibrary: () => library,
            canSignNow: () => true,
            buildCanSign: () => true,
            hasCredential: (_) async => false,
            // Nothing qualified, so nothing is left unsigned either.
            signRecording: (_) async => false,
          );

          await service.finishPendingBackups();

          verifyCopied(path);
          expect(statusOf('clip_1'), ClipGalleryBackupStatus.savedUnsigned);
        },
      );

      test('clears the backup of a recording that is gone', () async {
        libraryClip(
          'clip_1',
          '${tempDir.path}/VID_gone.mp4',
          backupStatus: ClipGalleryBackupStatus.pending,
        );

        await buildService().finishPendingBackups();

        verifyNothingCopied();
        expect(statusOf('clip_1'), isNull);
      });

      test('copies a recording once when asked again mid-run', () async {
        final copy = Completer<GallerySaveResult>();
        when(
          () => gallery.saveVideoToGallery(
            any(),
            requestPermission: any(named: 'requestPermission'),
          ),
        ).thenAnswer((_) => copy.future);
        final path = recordingFile('VID_1.mp4');
        libraryClip(
          'clip_1',
          path,
          backupStatus: ClipGalleryBackupStatus.pending,
        );
        final service = buildService();

        final first = service.finishPendingBackups();
        await pumpEventQueue();
        final second = service.finishPendingBackups();
        copy.complete(const GallerySaveSuccess());
        await Future.wait([first, second]);

        verifyCopied(path);
        expect(statusOf('clip_1'), ClipGalleryBackupStatus.saved);
      });
    });
  });
}
