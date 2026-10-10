// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

import 'dart:async';
import 'dart:ui' show Color;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/editor_background_work.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/captured_chroma_key_baker.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

/// Mirrors the stub shape used by the widget suites (for example
/// `library_screen_test.dart`): seed a clip list from `build` without calling
/// `super.build()`.
class _BuildOverrideClipManagerNotifier extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;
    late _MockDraftStorageService mockDraftStorageService;
    late _MockClipLibraryService mockClipLibraryService;

    /// Read lazily through the override below, so only the groups that bake
    /// have to set it.
    late CapturedChromaKeyBaker chromaKeyBaker;

    setUpAll(() {
      registerFallbackValue(
        DivineVideoClip(
          id: 'fallback',
          video: EditorVideo.file('/fallback.mp4'),
          duration: Duration.zero,
          recordedAt: DateTime(2024),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockDraftStorageService = _MockDraftStorageService();
      mockClipLibraryService = _MockClipLibraryService();
      when(
        () => mockDraftStorageService.deleteDraft(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockClipLibraryService.softDelete(
          any(),
          clearDraftId: any(named: 'clearDraftId'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockClipLibraryService.restore(any()),
      ).thenAnswer((_) async => true);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
          capturedChromaKeyBakerProvider.overrideWith((_) => chromaKeyBaker),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no clips', () {
      final state = container.read(clipManagerProvider);

      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
    });

    test('addClip updates state with new clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    group('resetRecording', () {
      test(
        'clears the in-progress duration of a recording that made no clip',
        () {
          fakeAsync((async) {
            final notifier = container.read(clipManagerProvider.notifier)
              ..startRecording();
            async.elapse(const Duration(milliseconds: 50));
            notifier.stopRecording();
            expect(
              container.read(clipManagerProvider).activeRecordingDuration,
              greaterThan(Duration.zero),
            );

            notifier.resetRecording();

            // The recorder bars draw clips plus this duration, so a stale
            // value shows a segment for a clip that does not exist.
            expect(
              container.read(clipManagerProvider).activeRecordingDuration,
              Duration.zero,
            );
          });
        },
      );
    });

    group('trim completion lifecycle', () {
      late void Function(bool success) completeTrim;

      setUp(() {
        VideoEditorRenderService.limitClipDurationOverride =
            ({required clip, required duration, required onComplete}) async {
              completeTrim = onComplete;
            };
        NativeProofModeService.proofFileOverride = (
          _, {
          required enableAdvancedCawgEmbedding,
          creatorBindingAssertion,
          cawgIdentityAssertion,
          verifiedIdentityBundle,
          clips,
          editorStateHistory,
          derivedFrom,
        }) async => null;
      });

      tearDown(() {
        VideoEditorRenderService.limitClipDurationOverride = null;
        NativeProofModeService.proofFileOverride = null;
      });

      test('settles background work when disposed during trim', () async {
        final backgroundWork = container.read(editorBackgroundWorkProvider);
        final notifier = container.read(clipManagerProvider.notifier);
        final clip = notifier.addClip(
          limitClipDuration: true,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration:
              VideoEditorConstants.maxDuration +
              const Duration(milliseconds: 1),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.processingCompleter, isNotNull);
        expect(clip.processingCompleter!.isCompleted, isFalse);
        expect(backgroundWork.isNotEmptyForTest, isTrue);

        container.dispose();
        completeTrim(true);

        expect(clip.processingCompleter!.isCompleted, isTrue);
        await backgroundWork.settle().timeout(
          const Duration(seconds: 10),
          onTimeout: () => fail('editor background work did not settle'),
        );
        expect(backgroundWork.isNotEmptyForTest, isFalse);
      });
    });

    group('provider lifecycle', () {
      test('rebuilds after the provider is invalidated', () {
        final first = container.read(clipManagerProvider.notifier);

        container.invalidate(clipManagerProvider);
        final second = container.read(clipManagerProvider.notifier);

        // Riverpod reuses the notifier and re-runs build, so anything build
        // assigns has to tolerate being assigned twice.
        expect(identical(first, second), isTrue);
        expect(container.read(clipManagerProvider).clips, isEmpty);
      });

      test('addClip works when a subclass replaces build', () async {
        final overridden = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            draftStorageServiceProvider.overrideWithValue(
              mockDraftStorageService,
            ),
            clipLibraryServiceProvider.overrideWithValue(
              mockClipLibraryService,
            ),
            clipManagerProvider.overrideWith(
              _BuildOverrideClipManagerNotifier.new,
            ),
          ],
        );
        addTearDown(overridden.dispose);
        final notifier = overridden.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(overridden.read(clipManagerProvider).clips, hasLength(1));
      });
    });

    group('muteAllClips', () {
      test('sets every clip volume to zero', () {
        final notifier = container.read(clipManagerProvider.notifier);
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(
          container.read(clipManagerProvider).clips.every((c) => c.volume == 1),
          isTrue,
        );

        notifier.muteAllClips();

        expect(
          container.read(clipManagerProvider).clips.every((c) => c.volume == 0),
          isTrue,
        );
      });

      test('does nothing when there are no clips', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.muteAllClips();

        expect(container.read(clipManagerProvider).clips, isEmpty);
      });
    });

    test('deleteClip removes clip from state', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      await notifier.removeClipById(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test(
      'removeClipById resolves true even when post-mutation cleanup throws',
      () async {
        // The autosave / database / file-cleanup chain that runs after the
        // state mutation is best-effort. A test environment without a real
        // database (or a production environment with a transient disk
        // failure) must not turn `removeClipById` into a rejected future —
        // the clip is already gone from state and that contract is what
        // callers rely on. This test pins that contract.
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final clipId = container.read(clipManagerProvider).clips[0].id;

        final result = await notifier.removeClipById(clipId);

        expect(result, isTrue);
        expect(container.read(clipManagerProvider).clips, isEmpty);
      },
    );

    test('selectClip updates selected clip state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.selectClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.selectedClipId, equals(clipId));
    });

    test('updateThumbnail updates clip thumbnail', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateThumbnail(
        clipId: clipId,
        thumbnailPath: '/path/to/thumb.jpg',
        thumbnailTimestamp: const Duration(milliseconds: 210),
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(
        state.clips[0].thumbnailTimestamp,
        equals(const Duration(milliseconds: 210)),
      );
    });

    test('updateClipDuration updates clip duration', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateClipDuration(clipId, const Duration(seconds: 3));

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].duration, equals(const Duration(seconds: 3)));
      expect(state.totalDuration, equals(const Duration(seconds: 3)));
    });

    test('deleteLastClip deletes last clip', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(container.read(clipManagerProvider).clips.length, equals(2));

      await notifier.scheduleDeleteLastClip();

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test(
      'commitPendingDeletion finalizes the delete so a later undo no-ops',
      () async {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        await notifier.scheduleDeleteLastClip();
        expect(container.read(clipManagerProvider).pendingDeletion, isNotNull);

        await notifier.commitPendingDeletion();

        expect(container.read(clipManagerProvider).pendingDeletion, isNull);

        await notifier.undoPendingDeletion();

        expect(container.read(clipManagerProvider).clips.length, equals(1));
        verifyNever(() => mockClipLibraryService.restore(any()));
      },
    );

    test('clearAll removes all clips and resets state', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await notifier.clearAll();

      final state = container.read(clipManagerProvider);
      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
      expect(state.totalDuration, equals(Duration.zero));
      expect(state.errorMessage, isNull);
      expect(state.isProcessing, isFalse);
    });

    group('clearAll autosave draft handling', () {
      // The recorder and editor exits differ only in this flag, and the
      // widget-level suites drive it through a fake `VideoPublishNotifier`
      // that records the boolean without running the chain — so these are the
      // assertions that fail if the delete stops reaching storage.
      void addClip(ClipManagerNotifier notifier) => notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test('deletes the autosave draft by default', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        when(
          () => mockDraftStorageService.draftExists(
            VideoEditorConstants.autoSaveId,
          ),
        ).thenAnswer((_) async => true);
        addClip(notifier);

        await notifier.clearAll();

        verify(
          () => mockDraftStorageService.deleteDraft(
            VideoEditorConstants.autoSaveId,
          ),
        ).called(greaterThanOrEqualTo(1));
      });

      test('leaves the autosave draft untouched when keeping it', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        addClip(notifier);

        await notifier.clearAll(keepAutosavedDraft: true);

        // The shared `draft_autosave` slot is never touched — the editor's
        // save path relies on that, having already reaped it itself.
        verifyNever(() => mockDraftStorageService.deleteDraft(any()));
        // ...and the session still empties, which is what cures the inherited
        // aspect ratio. The flag only decides the draft's fate.
        expect(container.read(clipManagerProvider).clips, isEmpty);
      });
    });

    test('canRecordMore is true when under limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: VideoEditorConstants.maxDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isFalse);
    });

    test('addClip allows adding duplicate clips with same id', () {
      final notifier = container.read(clipManagerProvider.notifier);

      // Simulate adding the same clip multiple times (like from library selection)
      const sharedFilePath = '/path/to/library/clip.mp4';
      const clipDuration = Duration(seconds: 2);

      final clip1 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip2 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip3 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final state = container.read(clipManagerProvider);

      // All three clips should be added
      expect(state.clips.length, equals(3));

      // Each clip should have a unique ID
      expect(clip1.id, isNot(equals(clip2.id)));
      expect(clip2.id, isNot(equals(clip3.id)));
      expect(clip1.id, isNot(equals(clip3.id)));

      // Total duration should account for all clips
      expect(state.totalDuration, equals(const Duration(seconds: 6)));
    });

    group('clearClips', () {
      test('should remove all clips without affecting files', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 3),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(container.read(clipManagerProvider).clips.length, equals(2));

        notifier.clearClips();

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
        expect(state.hasClips, isFalse);
      });

      test(
        'clearClips before addMultipleClips prevents clip duplication (draft restore)',
        () {
          final notifier = container.read(clipManagerProvider.notifier);

          // Simulate initial clips already in manager
          notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/existing1.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/existing2.mp4'),
            duration: const Duration(seconds: 3),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          expect(container.read(clipManagerProvider).clips.length, equals(2));

          // Simulate draft restoration pattern:
          // 1. Clear existing clips first
          notifier.clearClips();

          // 2. Add clips from draft
          final draftClip1 = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/draft1.mp4'),
            duration: const Duration(seconds: 1),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );
          final draftClip2 = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/draft2.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );

          final state = container.read(clipManagerProvider);

          // Should only have the 2 draft clips, not 4 (2 existing + 2 draft)
          expect(
            state.clips.length,
            equals(2),
            reason: 'Draft restore should replace clips, not append to them',
          );

          // Verify they are the correct clips
          expect(state.clips[0].id, equals(draftClip1.id));
          expect(state.clips[1].id, equals(draftClip2.id));
          expect(state.totalDuration, equals(const Duration(seconds: 3)));
        },
      );

      test('addMultipleClips without clearClips causes duplication', () {
        final notifier = container.read(clipManagerProvider.notifier);

        // Add initial clips
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/existing.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(container.read(clipManagerProvider).clips.length, equals(1));

        // Create clips to add (simulating draft clips)
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/draft.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .square,
          originalAspectRatio: 1,
        );

        // Without clearClips, we now have 2 clips
        final state = container.read(clipManagerProvider);
        expect(
          state.clips.length,
          equals(2),
          reason: 'Without clearClips, clips are appended',
        );
      });

      test(
        'replaceClips swaps clips atomically without empty intermediate state',
        () {
          final notifier = container.read(clipManagerProvider.notifier);

          notifier.addClip(
            video: EditorVideo.file('/path/to/existing.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            limitClipDuration: false,
          );

          final replacementClip = DivineVideoClip(
            id: 'replacement-clip',
            video: EditorVideo.file('/path/to/replacement.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );

          notifier.replaceClips([replacementClip]);

          final state = container.read(clipManagerProvider);
          expect(state.clips, hasLength(1));
          expect(state.clips.single.id, equals('replacement-clip'));
          expect(state.firstClipOrNull, equals(replacementClip));
        },
      );
    });

    group('addClip proof generation', () {
      group('when the recording could not be signed', () {
        const recordingHash = 'abc123';

        setUp(() {
          NativeProofModeService.proofFileOverride = (
            _, {
            required enableAdvancedCawgEmbedding,
            creatorBindingAssertion,
            cawgIdentityAssertion,
            verifiedIdentityBundle,
            clips,
            editorStateHistory,
            derivedFrom,
          }) async => const NativeProofData(videoHash: recordingHash);
          when(
            () => mockClipLibraryService.rememberRecordingHash(
              clipId: any(named: 'clipId'),
              fileName: any(named: 'fileName'),
              sha256: any(named: 'sha256'),
            ),
          ).thenAnswer((_) async => true);
        });

        tearDown(() => NativeProofModeService.proofFileOverride = null);

        test('notes the recording hash on its library entry', () async {
          final backgroundWork = container.read(editorBackgroundWorkProvider);
          final notifier = container.read(clipManagerProvider.notifier);

          final clip = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/documents/take.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          await backgroundWork.settle();

          verify(
            () => mockClipLibraryService.rememberRecordingHash(
              clipId: clip.id,
              fileName: 'take.mp4',
              sha256: recordingHash,
            ),
          ).called(1);
        });

        // The take can be picked from the library long after it left the
        // working set, so the entry is written even when the proof comes back
        // after that.
        test('notes the hash after the clip left the working set', () async {
          final started = Completer<void>();
          final proof = Completer<NativeProofData?>();
          NativeProofModeService.proofFileOverride =
              (
                _, {
                required enableAdvancedCawgEmbedding,
                creatorBindingAssertion,
                cawgIdentityAssertion,
                verifiedIdentityBundle,
                clips,
                editorStateHistory,
                derivedFrom,
              }) {
                started.complete();
                return proof.future;
              };
          final backgroundWork = container.read(editorBackgroundWorkProvider);
          final notifier = container.read(clipManagerProvider.notifier);

          final clip = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/documents/take.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          await started.future;
          notifier.clearClips();
          proof.complete(const NativeProofData(videoHash: recordingHash));
          await backgroundWork.settle();

          verify(
            () => mockClipLibraryService.rememberRecordingHash(
              clipId: clip.id,
              fileName: 'take.mp4',
              sha256: recordingHash,
            ),
          ).called(1);
        });
      });

      test('leaves the library entry alone for a signed recording', () async {
        NativeProofModeService.proofFileOverride =
            (
              _, {
              required enableAdvancedCawgEmbedding,
              creatorBindingAssertion,
              cawgIdentityAssertion,
              verifiedIdentityBundle,
              clips,
              editorStateHistory,
              derivedFrom,
            }) async => const NativeProofData(
              videoHash: 'abc123',
              c2paManifestId: 'urn:c2pa:signed',
            );
        addTearDown(() => NativeProofModeService.proofFileOverride = null);
        final backgroundWork = container.read(editorBackgroundWorkProvider);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/documents/take.mp4'),
              duration: const Duration(seconds: 2),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            );
        await backgroundWork.settle();

        verifyNever(
          () => mockClipLibraryService.rememberRecordingHash(
            clipId: any(named: 'clipId'),
            fileName: any(named: 'fileName'),
            sha256: any(named: 'sha256'),
          ),
        );
      });

      test('newly added clip has no proofManifestJson initially', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.proofManifestJson, isNull);
      });

      test('clip without trimming has no processingCompleter', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.processingCompleter, isNull);
        expect(clip.isProcessing, isFalse);
      });

      test('multiple clips each have independent proof state', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip1 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final clip2 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 3),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Both start without proof
        expect(clip1.proofManifestJson, isNull);
        expect(clip2.proofManifestJson, isNull);

        // Each clip has a unique ID
        expect(clip1.id, isNot(equals(clip2.id)));
      });

      test('refreshClip updates proofManifestJson on existing clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.proofManifestJson, isNull);

        // Simulate what _generateClipProof does after proof generation
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        final state = container.read(clipManagerProvider);
        final updatedClip = state.clips.first;
        expect(updatedClip.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('refreshClip preserves thumbnail when updating proof', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/path/to/thumb.jpg',
        );

        // Update thumbnail first
        notifier.updateThumbnail(
          clipId: clip.id,
          thumbnailPath: '/path/to/updated_thumb.jpg',
          thumbnailTimestamp: const Duration(milliseconds: 500),
        );

        // Then update proof (simulating _generateClipProof)
        final currentClip = notifier.getClipById(clip.id)!;
        notifier.refreshClip(
          currentClip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        final state = container.read(clipManagerProvider);
        final updatedClip = state.clips.first;
        expect(updatedClip.proofManifestJson, equals('{"hash":"abc123"}'));
        expect(updatedClip.thumbnailPath, equals('/path/to/updated_thumb.jpg'));
      });

      test('proof state survives clip reordering', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip1 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Add proof to first clip
        notifier.refreshClip(
          clip1.copyWith(proofManifestJson: '{"hash":"proof1"}'),
        );

        // Verify proof is on first clip
        final state = container.read(clipManagerProvider);
        final proofClip = state.clips.firstWhere(
          (c) => c.proofManifestJson != null,
        );
        expect(proofClip.proofManifestJson, equals('{"hash":"proof1"}'));
      });

      test('clearAll removes clips including their proof data', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Simulate proof generation
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        // Verify proof exists
        expect(
          container.read(clipManagerProvider).clips.first.proofManifestJson,
          isNotNull,
        );

        await notifier.clearAll();

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
      });

      test('getClipById returns clip with current proof state', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Initially no proof
        expect(notifier.getClipById(clip.id)?.proofManifestJson, isNull);

        // Add proof
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        // getClipById returns updated state
        final updated = notifier.getClipById(clip.id);
        expect(updated?.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('getClipById returns null for deleted clip', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(notifier.getClipById(clip.id), isNotNull);

        await notifier.removeClipById(clip.id);

        expect(notifier.getClipById(clip.id), isNull);
      });

      test('refreshClip is no-op for deleted clip '
          '(simulates proof arriving after deletion)', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Delete the clip
        await notifier.removeClipById(clip.id);
        expect(container.read(clipManagerProvider).clips, isEmpty);

        // Simulate late proof arrival — refreshClip should not re-add the clip
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"late_proof"}'),
        );

        final state = container.read(clipManagerProvider);
        expect(
          state.clips,
          isEmpty,
          reason: 'Deleted clip should not reappear from late proof update',
        );
      });
    });

    group('updateGhostFrame', () {
      test('updates ghost frame path for existing clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final clipId = container.read(clipManagerProvider).clips[0].id;

        notifier.updateGhostFrame(
          clipId: clipId,
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final state = container.read(clipManagerProvider);
        expect(state.clips[0].ghostFramePath, equals('/path/to/ghost.jpg'));
      });

      test('does not throw for non-existent clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        // Should log a warning but not throw
        notifier.updateGhostFrame(
          clipId: 'non_existent',
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
      });

      test('preserves other clip fields when updating ghost frame', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/path/to/thumb.jpg',
        );
        final clipId = container.read(clipManagerProvider).clips[0].id;

        notifier.updateGhostFrame(
          clipId: clipId,
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final clip = container.read(clipManagerProvider).clips[0];
        expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
        expect(clip.duration, equals(const Duration(seconds: 2)));
        expect(clip.ghostFramePath, equals('/path/to/ghost.jpg'));
      });
    });

    group('bakeCapturedChromaKey', () {
      const key = ClipChromaKey(
        key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
      );

      late List<String> rendered;
      Completer<void>? renderGate;

      setUp(() {
        rendered = [];
        renderGate = null;
        chromaKeyBaker = CapturedChromaKeyBaker(
          render:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                rendered.add(sourceClip.id);
                await renderGate?.future;
                return (
                  video: EditorVideo.file('/documents/keyed.mp4'),
                  source: sourceClip.video!.file!.path,
                );
              },
          extractPoster: ({required videoPath, required timestamp}) async =>
              null,
          cancelRender: (_) async {},
        );
        when(
          () => mockClipLibraryService.saveClip(any()),
        ).thenAnswer((_) async {});
      });

      DivineVideoClip recordTake(ClipManagerNotifier notifier) =>
          notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/documents/raw.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            captureChromaKey: key,
          );

      test(
        'moves the take and its library copy to the keyed file',
        () async {
          final notifier = container.read(clipManagerProvider.notifier);
          final take = recordTake(notifier);
          when(
            () => mockClipLibraryService.getClipById(take.id),
          ).thenAnswer((_) async => take);

          final keyed = await notifier.bakeCapturedChromaKey(take);

          expect(keyed.video?.file?.path, '/documents/keyed.mp4');
          final held = container.read(clipManagerProvider).clips.single;
          expect(held.video?.file?.path, '/documents/keyed.mp4');
          expect(held.chromaKey, key);
          expect(held.captureChromaKey, isNull);
          final saved =
              verify(
                    () => mockClipLibraryService.saveClip(captureAny()),
                  ).captured.last
                  as DivineVideoClip;
          expect(saved.video?.file?.path, '/documents/keyed.mp4');
          // An open library reloads on this.
          expect(container.read(clipManagerProvider).libraryRevision, 1);
        },
      );

      test('joins the bake already running for the same take', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);
        renderGate = Completer<void>();

        // The recorder asks after the take; an editor opening meanwhile asks
        // too.
        final fromRecorder = notifier.bakeCapturedChromaKey(take);
        final fromEditor = notifier.bakeCapturedChromaKey(take);
        await pumpEventQueue();
        renderGate!.complete();

        expect(
          (await fromEditor).video?.file?.path,
          (await fromRecorder).video?.file?.path,
        );
        expect(rendered, [take.id]);
      });

      test('hands back a take it already keyed without rendering', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);
        await notifier.bakeCapturedChromaKey(take);

        final again = await notifier.bakeCapturedChromaKey(take);

        expect(again.chromaKey, key);
        expect(rendered, [take.id]);
      });

      test('leaves the library alone once the take is gone from it', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);

        await notifier.bakeCapturedChromaKey(take);

        expect(container.read(clipManagerProvider).libraryRevision, 0);
        expect(
          container.read(clipManagerProvider).clips.single.chromaKey,
          key,
        );
      });

      test('renders a take again after its bake failed', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);
        renderGate = Completer<void>();
        final failed = expectLater(
          notifier.bakeCapturedChromaKey(take),
          throwsStateError,
        );
        await pumpEventQueue();
        renderGate!.completeError(StateError('render failed'));
        await failed;
        renderGate = null;
        final keyed = await notifier.bakeCapturedChromaKey(take);

        expect(keyed.chromaKey, key);
        expect(rendered, [take.id, take.id]);
      });

      test('holds bakes back until released', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);

        notifier.holdCapturedChromaKeyBakes();
        final bake = notifier.bakeCapturedChromaKey(take);
        await pumpEventQueue();
        expect(rendered, isEmpty);

        notifier.releaseCapturedChromaKeyBakes();
        await bake;
        expect(rendered, [take.id]);
      });

      test('brings a take deleted while it baked back keyed on undo', () async {
        final notifier = container.read(clipManagerProvider.notifier);
        final take = recordTake(notifier);
        when(
          () => mockClipLibraryService.getClipById(take.id),
        ).thenAnswer((_) async => null);
        renderGate = Completer<void>();
        final bake = notifier.bakeCapturedChromaKey(take);
        await pumpEventQueue();

        await notifier.scheduleDeleteLastClip();
        renderGate!.complete();
        await bake;
        await notifier.undoPendingDeletion();

        final restored = container.read(clipManagerProvider).clips.single;
        expect(restored.video?.file?.path, '/documents/keyed.mp4');
        expect(restored.chromaKey, key);
      });

      test(
        'keys only the library row of the account that recorded the take',
        () async {
          final notifier = container.read(clipManagerProvider.notifier);
          final take = recordTake(notifier);
          final signedOut = _MockClipLibraryService();
          when(() => mockClipLibraryService.ownerPubkey).thenReturn('owner');
          when(() => signedOut.ownerPubkey).thenReturn('anonymous');
          when(
            () => mockClipLibraryService.getClipById(take.id),
          ).thenAnswer((_) async => take);
          renderGate = Completer<void>();
          final bake = notifier.bakeCapturedChromaKey(take);
          await pumpEventQueue();

          container.updateOverrides([
            sharedPreferencesProvider.overrideWithValue(
              container.read(sharedPreferencesProvider),
            ),
            draftStorageServiceProvider.overrideWithValue(
              mockDraftStorageService,
            ),
            clipLibraryServiceProvider.overrideWithValue(signedOut),
            capturedChromaKeyBakerProvider.overrideWith((_) => chromaKeyBaker),
          ]);
          renderGate!.complete();
          await bake;

          final saved =
              verify(
                    () => mockClipLibraryService.saveClip(captureAny()),
                  ).captured.single
                  as DivineVideoClip;
          expect(saved.video?.file?.path, '/documents/keyed.mp4');
          verifyNever(() => signedOut.saveClip(any()));
          // The session, and with it the autosave, is left alone.
          expect(
            container
                .read(clipManagerProvider)
                .clips
                .single
                .hasPendingCaptureChromaKey,
            isTrue,
          );
        },
      );

      test(
        'bakes the library copy of a take the recorder already let go',
        () async {
          final notifier = container.read(clipManagerProvider.notifier);
          final take = recordTake(notifier);
          when(
            () => mockClipLibraryService.getClipById(take.id),
          ).thenAnswer((_) async => take);
          // Leaving the recorder right after the take clears the session.
          notifier.clearClips();

          await notifier.bakeRecordedTake(take.id);

          expect(rendered, [take.id]);
          final saved =
              verify(
                    () => mockClipLibraryService.saveClip(captureAny()),
                  ).captured.last
                  as DivineVideoClip;
          expect(saved.video?.file?.path, '/documents/keyed.mp4');
          expect(saved.chromaKey, key);
        },
      );
    });

    group('applyChromaKeyBakeToLibrary', () {
      const key = ClipChromaKey(
        key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
      );

      DivineVideoClip take(String file) => DivineVideoClip(
        id: 'take',
        video: EditorVideo.file(file),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2024),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      late DivineVideoClip raw;
      late DivineVideoClip baked;

      setUp(() {
        when(
          () => mockClipLibraryService.saveClip(any()),
        ).thenAnswer((_) async {});
        raw = take('/documents/raw.mp4').copyWith(captureChromaKey: key);
        baked = take('/documents/keyed.mp4').copyWith(
          chromaKey: key,
          chromaKeySourcePath: '/documents/raw.mp4',
          thumbnailPath: '/documents/keyed.jpg',
        );
      });

      test('swaps in the keyed take and keeps the rest of the row', () async {
        // Same file under a different container path, as after an iOS update.
        when(() => mockClipLibraryService.getClipById('take')).thenAnswer(
          (_) async => take('/old-container/raw.mp4').copyWith(
            captureChromaKey: key,
            libraryTitle: 'Beach',
            trimStart: const Duration(milliseconds: 300),
          ),
        );
        final notifier = container.read(clipManagerProvider.notifier);

        final updated = await notifier.applyChromaKeyBakeToLibrary(
          raw: raw,
          baked: baked,
        );

        expect(updated, isTrue);
        final saved =
            verify(
                  () => mockClipLibraryService.saveClip(captureAny()),
                ).captured.single
                as DivineVideoClip;
        expect(saved.video?.file?.path, '/documents/keyed.mp4');
        expect(saved.chromaKey, key);
        expect(saved.chromaKeySourcePath, '/documents/raw.mp4');
        expect(saved.captureChromaKey, isNull);
        expect(saved.thumbnailPath, '/documents/keyed.jpg');
        expect(saved.libraryTitle, 'Beach');
        expect(saved.trimStart, const Duration(milliseconds: 300));
      });

      test('leaves a take deleted from the library deleted', () async {
        when(
          () => mockClipLibraryService.getClipById('take'),
        ).thenAnswer((_) async => null);
        final notifier = container.read(clipManagerProvider.notifier);

        final updated = await notifier.applyChromaKeyBakeToLibrary(
          raw: raw,
          baked: baked,
        );

        expect(updated, isFalse);
        verifyNever(() => mockClipLibraryService.saveClip(any()));
      });

      test('leaves a row that plays other footage alone', () async {
        when(
          () => mockClipLibraryService.getClipById('take'),
        ).thenAnswer((_) async => take('/documents/other.mp4'));
        final notifier = container.read(clipManagerProvider.notifier);

        final updated = await notifier.applyChromaKeyBakeToLibrary(
          raw: raw,
          baked: baked,
        );

        expect(updated, isFalse);
        verifyNever(() => mockClipLibraryService.saveClip(any()));
      });
    });

    group('stop-motion session library persistence', () {
      const frame = StopMotionClipFrame(
        path: '/tmp/frame_0.jpg',
        duration: Duration(milliseconds: 83),
      );

      test('addStopMotionClip reuses a caller-supplied id', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addStopMotionClip(
          id: 'clip_sm_frame_0',
          frames: const [frame],
          originalAspectRatio: 9 / 16,
          targetAspectRatio: .vertical,
          duration: const Duration(milliseconds: 83),
          thumbnailPath: frame.path,
        );

        expect(clip.id, equals('clip_sm_frame_0'));
        expect(
          container.read(clipManagerProvider).clips.single.id,
          equals('clip_sm_frame_0'),
        );
      });

      test('addStopMotionClip generates an id when none is supplied', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addStopMotionClip(
          frames: const [frame],
          originalAspectRatio: 9 / 16,
          targetAspectRatio: .vertical,
          duration: const Duration(milliseconds: 83),
        );

        expect(clip.id, startsWith('clip_'));
        expect(clip.id, isNot(equals('clip_sm_frame_0')));
      });

      test(
        'saveStopMotionSessionToLibrary upserts a frames-only clip by id',
        () async {
          when(
            () => mockClipLibraryService.saveClip(any()),
          ).thenAnswer((_) async {});
          final notifier = container.read(clipManagerProvider.notifier);

          final saved = await notifier.saveStopMotionSessionToLibrary(
            id: 'clip_sm_frame_0',
            frames: const [frame],
            originalAspectRatio: 9 / 16,
            targetAspectRatio: .vertical,
            duration: const Duration(milliseconds: 83),
            thumbnailPath: frame.path,
          );

          expect(saved, isTrue);
          final captured =
              verify(
                    () => mockClipLibraryService.saveClip(captureAny()),
                  ).captured.single
                  as DivineVideoClip;
          expect(captured.id, equals('clip_sm_frame_0'));
          expect(captured.isStopMotion, isTrue);
          expect(captured.stopMotionFrames, equals(const [frame]));
          // A frames-only session clip is not added to the working set.
          expect(container.read(clipManagerProvider).clips, isEmpty);
        },
      );

      test('removeStopMotionSessionFromLibrary deletes the row only', () async {
        when(
          () => mockClipLibraryService.deleteClipRow(any()),
        ).thenAnswer((_) async {});
        final notifier = container.read(clipManagerProvider.notifier);

        await notifier.removeStopMotionSessionFromLibrary('clip_sm_frame_0');

        verify(
          () => mockClipLibraryService.deleteClipRow('clip_sm_frame_0'),
        ).called(1);
      });
    });
  });
}
