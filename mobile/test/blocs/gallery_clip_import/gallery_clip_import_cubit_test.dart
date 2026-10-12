// ABOUTME: Unit tests for GalleryClipImportCubit.
// ABOUTME: A gallery video reaches the clip library only when its C2PA check
// ABOUTME: passes, each video's status is reported, and temp copies go away.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/gallery_clip_import/gallery_clip_import_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

const _manifestId = 'urn:c2pa:3fa85f64-5717-4562-b3fc-2c963f66afa6';
final String _friendPubkey = 'c' * 64;
final Uint8List _thumbnail = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

void main() {
  late Directory pickerDir;
  late _MockClipProvenanceVerifier verifier;
  late _MockVideoClipImportService importService;

  setUpAll(() {
    registerFallbackValue(File(''));
  });

  setUp(() {
    pickerDir = Directory.systemTemp.createTempSync('gallery_clip_import_');
    verifier = _MockClipProvenanceVerifier();
    importService = _MockVideoClipImportService();
  });

  tearDown(() {
    if (pickerDir.existsSync()) pickerDir.deleteSync(recursive: true);
  });

  /// A temp copy the picker made, as it would hand one over.
  String pickedCopy(String name) {
    final file = File('${pickerDir.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  GalleryClipImportCubit buildCubit({
    GalleryClipThumbnailLoader? loadThumbnail,
  }) => GalleryClipImportCubit(
    verifier: verifier,
    resolveImporter: () => importService.importGalleryClip,
    loadThumbnail: loadThumbnail ?? (_) async => _thumbnail,
  );

  void stubVerification(
    String path,
    ClipProvenanceStatus status, {
    List<String> contributors = const [],
  }) {
    when(() => verifier.verify(path)).thenAnswer(
      (_) async => ClipProvenanceResult(
        status,
        activeManifestId: status == ClipProvenanceStatus.verified
            ? _manifestId
            : null,
        contributors: contributors,
      ),
    );
  }

  void stubImport(VideoClipImportResult result) {
    when(
      () => importService.importGalleryClip(
        source: any(named: 'source'),
        c2paManifestId: any(named: 'c2paManifestId'),
        contributorPubkeys: any(named: 'contributorPubkeys'),
      ),
    ).thenAnswer((_) async => result);
  }

  final success = VideoClipImportSuccess(
    DivineVideoClip(
      id: 'gallery_clip_1',
      video: EditorVideo.file('/documents/gallery_clip_1.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime.utc(2026, 10, 12),
      targetAspectRatio: AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    ),
  );

  /// The status every picked video ended on.
  List<GalleryClipImportItemStatus> finalStatuses(
    GalleryClipImportCubit cubit,
  ) => [for (final item in cubit.state.items) item.status];

  group(GalleryClipImportCubit, () {
    group('importClips', () {
      late String path;

      setUp(() => path = pickedCopy('clip.mp4'));

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'lists the video, checks it and adds it with its history',
        setUp: () {
          stubVerification(
            path,
            ClipProvenanceStatus.verified,
            contributors: [_friendPubkey],
          );
          stubImport(success);
        },
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        expect: () => [
          GalleryClipImportState(items: [GalleryClipImportItem(path: path)]),
          GalleryClipImportState(
            items: [GalleryClipImportItem(path: path, thumbnail: _thumbnail)],
          ),
          GalleryClipImportState(
            items: [
              GalleryClipImportItem(
                path: path,
                thumbnail: _thumbnail,
                status: GalleryClipImportItemStatus.checking,
              ),
            ],
          ),
          GalleryClipImportState(
            items: [
              GalleryClipImportItem(
                path: path,
                thumbnail: _thumbnail,
                status: GalleryClipImportItemStatus.added,
              ),
            ],
          ),
        ],
        verify: (cubit) {
          expect(cubit.state.addedCount, equals(1));
          expect(cubit.state.isImporting, isFalse);
          final source =
              verify(
                    () => importService.importGalleryClip(
                      source: captureAny(named: 'source'),
                      c2paManifestId: _manifestId,
                      contributorPubkeys: [_friendPubkey],
                    ),
                  ).captured.single
                  as File;
          expect(source.path, equals(path));
          expect(File(path).existsSync(), isFalse);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'reports footage the library already holds without counting it '
        'as added',
        setUp: () {
          stubVerification(path, ClipProvenanceStatus.verified);
          stubImport(
            VideoClipImportSuccess(success.clip, alreadyInLibrary: true),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.alreadyInLibrary]),
          );
          expect(cubit.state.addedCount, equals(0));
          expect(cubit.state.isImporting, isFalse);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'keeps a video that fails the check out of the library',
        setUp: () => stubVerification(path, ClipProvenanceStatus.noCredentials),
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.notVerified]),
          );
          verifyZeroInteractions(importService);
          expect(File(path).existsSync(), isFalse);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'refuses a container the C2PA reader is not given',
        setUp: () => path = pickedCopy('clip.webm'),
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.notVerified]),
          );
          verifyZeroInteractions(verifier);
          expect(File(path).existsSync(), isFalse);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'reports a check that could not run without adding the video',
        setUp: () => stubVerification(path, ClipProvenanceStatus.unavailable),
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.checkUnavailable]),
          );
          verifyZeroInteractions(importService);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'reports the check as unavailable when the credit cannot be resolved',
        setUp: () {
          stubVerification(path, ClipProvenanceStatus.verified);
          stubImport(
            const VideoClipImportFailure(
              VideoClipImportFailureReason.sourceLookupFailed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) => expect(
          finalStatuses(cubit),
          equals([GalleryClipImportItemStatus.checkUnavailable]),
        ),
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'fails a verified video the library could not store',
        setUp: () {
          stubVerification(path, ClipProvenanceStatus.verified);
          stubImport(
            const VideoClipImportFailure(
              VideoClipImportFailureReason.copyFailed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.importClips([path]),
        errors: () => [
          isA<GalleryClipImportFailure>().having(
            (failure) => failure.reason,
            'reason',
            VideoClipImportFailureReason.copyFailed,
          ),
        ],
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.failed]),
          );
          expect(File(path).existsSync(), isFalse);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'gives each video its own result in the picked order',
        setUp: () {
          final rejected = pickedCopy('other.mp4');
          stubVerification(path, ClipProvenanceStatus.verified);
          stubVerification(rejected, ClipProvenanceStatus.untrustedSigner);
          stubImport(success);
        },
        build: buildCubit,
        act: (cubit) =>
            cubit.importClips([path, '${pickerDir.path}/other.mp4']),
        verify: (cubit) {
          expect(
            finalStatuses(cubit),
            equals([
              GalleryClipImportItemStatus.added,
              GalleryClipImportItemStatus.notVerified,
            ]),
          );
          expect(cubit.state.addedCount, equals(1));
          expect(pickerDir.listSync(), isEmpty);
        },
      );

      blocTest<GalleryClipImportCubit, GalleryClipImportState>(
        'still imports a video whose preview cannot be read',
        setUp: () {
          stubVerification(path, ClipProvenanceStatus.verified);
          stubImport(success);
        },
        build: () => buildCubit(
          loadThumbnail: (_) async => throw Exception('no frame'),
        ),
        act: (cubit) => cubit.importClips([path]),
        verify: (cubit) {
          expect(cubit.state.items.single.thumbnail, isNull);
          expect(
            finalStatuses(cubit),
            equals([GalleryClipImportItemStatus.added]),
          );
        },
      );

      test('ignores a second import while the first is running', () async {
        final verification = Completer<ClipProvenanceResult>();
        when(
          () => verifier.verify(path),
        ).thenAnswer((_) => verification.future);
        stubImport(success);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final first = cubit.importClips([path]);
        await pumpEventQueue();
        await cubit.importClips([pickedCopy('second.mp4')]);
        verification.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );
        await first;

        expect(cubit.state.items.map((item) => item.path), equals([path]));
        verify(() => verifier.verify(any())).called(1);
      });

      test('adds the videos to the library of the account that asked, even '
          'when the account switches during the check', () async {
        final verification = Completer<ClipProvenanceResult>();
        when(
          () => verifier.verify(path),
        ).thenAnswer((_) => verification.future);
        stubImport(success);
        final otherAccountImport = _MockVideoClipImportService();
        var signedIn = importService;
        final cubit = GalleryClipImportCubit(
          verifier: verifier,
          resolveImporter: () => signedIn.importGalleryClip,
          loadThumbnail: (_) async => null,
        );
        addTearDown(cubit.close);

        final result = cubit.importClips([path]);
        await pumpEventQueue();
        signedIn = otherAccountImport;
        verification.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );
        await result;

        expect(cubit.state.addedCount, equals(1));
        verifyZeroInteractions(otherAccountImport);
      });

      test('finishes the import after close', () async {
        final verification = Completer<ClipProvenanceResult>();
        when(
          () => verifier.verify(path),
        ).thenAnswer((_) => verification.future);
        stubImport(success);
        final cubit = buildCubit();

        final result = cubit.importClips([path]);
        await pumpEventQueue();
        await cubit.close();
        verification.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );
        await result;

        verify(
          () => importService.importGalleryClip(
            source: any(named: 'source'),
            c2paManifestId: _manifestId,
            contributorPubkeys: any(named: 'contributorPubkeys'),
          ),
        ).called(1);
        expect(File(path).existsSync(), isFalse);
      });
    });
  });
}
