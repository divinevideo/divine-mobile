// ABOUTME: Tests for ClipGallerySaveCubit: late signing before the save, the
// ABOUTME: per-clip proof warnings, retrying, and a save outliving close().

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clip_gallery_save/clip_gallery_save_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/clips/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(ClipGallerySaveCubit, () {
    late _MockGallerySaveService gallery;
    late _MockClipProvenanceVerifier verifier;
    late List<String> events;
    late Set<String> stillUnsigned;

    void verifiesAs(DivineVideoClip clip, ClipProvenanceStatus status) => when(
      () => verifier.verify('/clips/${clip.id}.mp4'),
    ).thenAnswer((_) async => ClipProvenanceResult(status));

    Future<Set<String>> signOwnClips(List<DivineVideoClip> clips) async {
      events.add('sign ${clips.map((clip) => clip.id).join(',')}');
      return stillUnsigned;
    }

    ClipGallerySaveCubit build({
      bool canSign = true,
      bool withVerifier = true,
      List<ClipGallerySaveResult> results = const [],
    }) => ClipGallerySaveCubit(
      gallerySaveService: gallery,
      verifier: withVerifier ? verifier : null,
      signOwnClips: signOwnClips,
      canSign: canSign,
      results: results,
    );

    setUp(() {
      gallery = _MockGallerySaveService();
      verifier = _MockClipProvenanceVerifier();
      events = [];
      stillUnsigned = {};
      when(() => gallery.saveVideoToGallery(any())).thenAnswer((invocation) {
        final video = invocation.positionalArguments.single as EditorVideo;
        events.add('save ${video.file!.path}');
        return Future.value(const GallerySaveSuccess());
      });
    });

    group('saveClips', () {
      final signed = _clip('signed');
      final signedLate = _clip('signed-late');
      final offline = _clip('offline');
      final unsignable = _clip('unsignable');
      final altered = _clip('altered');

      setUp(() {
        verifiesAs(signed, ClipProvenanceStatus.verified);
        verifiesAs(signedLate, ClipProvenanceStatus.verified);
        verifiesAs(offline, ClipProvenanceStatus.noCredentials);
        verifiesAs(unsignable, ClipProvenanceStatus.noCredentials);
        verifiesAs(altered, ClipProvenanceStatus.invalid);
      });

      test(
        'signs own clips first, saves every clip and names those without '
        'proof',
        () async {
          stillUnsigned = {offline.id};
          final cubit = build();
          addTearDown(cubit.close);

          final outcome = await cubit.saveClips([
            signed,
            signedLate,
            offline,
            unsignable,
            altered,
          ]);

          // Signing comes first, so a clip signed late leaves with its proof.
          expect(events.first, startsWith('sign signed,signed-late,offline'));
          expect(events.skip(1), everyElement(startsWith('save ')));
          expect(events.skip(1), hasLength(5));
          expect(outcome!.savedCount, 5);
          expect(
            [
              for (final result in outcome.savedWithoutProof)
                (result.clip.id, result.warning),
            ],
            [
              (offline.id, ClipGallerySaveWarning.signingUnavailable),
              (unsignable.id, ClipGallerySaveWarning.noProof),
              (altered.id, ClipGallerySaveWarning.notVerified),
            ],
          );
          expect(cubit.state.status, ClipGallerySaveStatus.idle);
          expect(cubit.state.hasRetryableClips, isTrue);
        },
      );

      test('counts the clips done while it saves', () async {
        final cubit = build();
        addTearDown(cubit.close);
        final states = <ClipGallerySaveState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);

        await cubit.saveClips([signed, signedLate]);
        await pumpEventQueue();

        expect(
          [for (final state in states) (state.status, state.doneCount)],
          [
            (ClipGallerySaveStatus.signing, 0),
            (ClipGallerySaveStatus.saving, 0),
            (ClipGallerySaveStatus.saving, 1),
            (ClipGallerySaveStatus.idle, 0),
          ],
        );
      });

      test('warns about a stop-motion clip, made from stills', () async {
        final tempDir = Directory.systemTemp.createTempSync('clip_gallery');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final rendered = File('${tempDir.path}/stills.mp4')
          ..writeAsStringSync('rendered');
        StopMotionRenderService.assembleOverride = ({
          required frames,
          required aspectRatio,
          frameRate = StopMotionRenderService.defaultFrameRate,
          String? taskId,
        }) async => rendered.path;
        StopMotionRenderService.probeDurationOverride = (_) async => null;
        addTearDown(() {
          StopMotionRenderService.assembleOverride = null;
          StopMotionRenderService.probeDurationOverride = null;
        });
        final stills = DivineVideoClip(
          id: 'stills',
          stopMotionFrames: const [
            StopMotionClipFrame(
              path: '/frames/f0.jpg',
              duration: Duration(milliseconds: 83),
            ),
          ],
          duration: const Duration(milliseconds: 83),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final cubit = build();
        addTearDown(cubit.close);

        final outcome = await cubit.saveClips([stills]);

        expect(
          outcome!.savedWithoutProof.single.warning,
          ClipGallerySaveWarning.stopMotion,
        );
        // The mp4 rendered for the save is not kept.
        expect(rendered.existsSync(), isFalse);
      });

      test('blames the build when it cannot sign at all', () async {
        final cubit = build(canSign: false);
        addTearDown(cubit.close);

        final outcome = await cubit.saveClips([unsignable]);

        expect(events.where((event) => event.startsWith('sign')), isEmpty);
        expect(
          outcome!.savedWithoutProof.single.warning,
          ClipGallerySaveWarning.signingUnsupported,
        );
      });

      test('neither signs nor warns without a C2PA check', () async {
        final cubit = build(withVerifier: false);
        addTearDown(cubit.close);

        final outcome = await cubit.saveClips([unsignable]);

        expect(events, ['save /clips/unsignable.mp4']);
        expect(outcome!.savedWithoutProof, isEmpty);
      });

      test('stops at the first clip the gallery refuses access for', () async {
        when(
          () => gallery.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());
        final cubit = build();
        addTearDown(cubit.close);

        final outcome = await cubit.saveClips([signed, signedLate]);

        expect(outcome!.permissionDenied, isTrue);
        expect(outcome.results, isEmpty);
        expect(outcome.total, 2);
      });

      test('counts a clip the gallery could not take as failed', () async {
        when(
          () => gallery.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySaveFailure('timeout'));
        final cubit = build();
        addTearDown(cubit.close);

        final outcome = await cubit.saveClips([signed]);

        expect(outcome!.savedCount, 0);
        expect(outcome.failedCount, 1);
      });

      test('ignores a second save while one is running', () async {
        final gate = Completer<void>();
        when(() => gallery.saveVideoToGallery(any())).thenAnswer((_) async {
          await gate.future;
          return const GallerySaveSuccess();
        });
        final cubit = build();
        addTearDown(cubit.close);

        final first = cubit.saveClips([signed]);
        await pumpEventQueue();

        expect(await cubit.saveClips([signedLate]), isNull);
        gate.complete();
        expect((await first)!.savedCount, 1);
      });

      test('finishes the save after the cubit is closed', () async {
        final gate = Completer<void>();
        when(() => gallery.saveVideoToGallery(any())).thenAnswer((_) async {
          await gate.future;
          return const GallerySaveSuccess();
        });
        final cubit = build();

        final saving = cubit.saveClips([signed]);
        await pumpEventQueue();
        await cubit.close();
        gate.complete();

        expect((await saving)!.savedCount, 1);
      });
    });

    group('retry', () {
      final offline = _clip('offline');
      final unsignable = _clip('unsignable');

      test(
        'saves again only the clips whose proof can now be added',
        () async {
          final stillOffline = _clip('still-offline');
          verifiesAs(offline, ClipProvenanceStatus.verified);
          verifiesAs(stillOffline, ClipProvenanceStatus.noCredentials);
          stillUnsigned = {stillOffline.id};
          final cubit = build(
            results: [
              ClipGallerySaveResult(
                offline,
                saved: true,
                warning: ClipGallerySaveWarning.signingUnavailable,
              ),
              ClipGallerySaveResult(
                stillOffline,
                saved: true,
                warning: ClipGallerySaveWarning.signingUnavailable,
              ),
              ClipGallerySaveResult(
                unsignable,
                saved: true,
                warning: ClipGallerySaveWarning.noProof,
              ),
            ],
          );
          addTearDown(cubit.close);

          await cubit.retry();

          expect(events, [
            'sign offline,still-offline',
            'save /clips/offline.mp4',
          ]);
          expect(
            [
              for (final result in cubit.state.results)
                (result.clip.id, result.saved, result.warning),
            ],
            [
              (offline.id, true, null),
              (
                'still-offline',
                false,
                ClipGallerySaveWarning.signingUnavailable,
              ),
              (unsignable.id, true, ClipGallerySaveWarning.noProof),
            ],
          );
        },
      );
    });
  });
}
