// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CompleteParameters, WidgetLayer, WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// An operation-scoped trace handle that records its attributes and stop count
/// so tests can assert the `video_generation` per-render trace behaviour —
/// which the real (uninitialised) service would silently no-op.
class _RecordingTrace implements PerformanceTrace {
  _RecordingTrace(this.name);

  final String name;
  final Map<String, String> attributes = {};
  final Map<String, int> metrics = {};
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stopCount++;
}

/// Hands out — and retains — a [_RecordingTrace] per [startOperationTrace] call.
class _RecordingPerformanceMonitor extends PerformanceMonitoringService {
  final List<_RecordingTrace> traces = [];

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    final trace = _RecordingTrace(traceName);
    traces.add(trace);
    return trace;
  }
}

void main() {
  group('VideoEditorProvider', () {
    late ProviderContainer container;
    late _RecordingPerformanceMonitor performanceMonitor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      performanceMonitor = _RecordingPerformanceMonitor();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          performanceMonitoringServiceProvider.overrideWithValue(
            performanceMonitor,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('should have default values', () {
        final state = container.read(videoEditorProvider);

        expect(
          state.isProcessing,
          false,
          reason: 'isProcessing should default to false',
        );
        expect(
          state.isSavingDraft,
          false,
          reason: 'isSavingDraft should default to false',
        );
        expect(
          state.allowAudioReuse,
          false,
          reason: 'allowAudioReuse should default to false',
        );
        expect(state.title, isEmpty, reason: 'title should default to empty');
        expect(
          state.description,
          isEmpty,
          reason: 'description should default to empty',
        );
        expect(state.tags, isEmpty, reason: 'tags should default to empty');
        expect(
          state.metadataLimitReached,
          false,
          reason: 'metadataLimitReached should default to false',
        );
        expect(
          state.finalRenderedClip,
          isNull,
          reason: 'finalRenderedClip should default to null',
        );
      });
    });

    group('reset', () {
      test('should reset all state to defaults', () {
        // Modify some provider-owned state
        container
            .read(videoEditorProvider.notifier)
            .updateMetadata(title: 'Test Title');

        // Verify state changed
        var state = container.read(videoEditorProvider);
        expect(state.title, 'Test Title');

        // Reset
        container.read(videoEditorProvider.notifier).reset();
        state = container.read(videoEditorProvider);

        expect(state.title, isEmpty, reason: 'title should reset to empty');
        expect(
          state.isProcessing,
          false,
          reason: 'isProcessing should reset to false',
        );
        expect(
          state.metadataLimitReached,
          false,
          reason: 'metadataLimitReached should reset to false',
        );
      });
    });

    group('updateMetadata hashtag extraction', () {
      test('extracts hashtag when # is typed before existing word', () {
        final notifier = container.read(videoEditorProvider.notifier);

        // First type "hello"
        notifier.updateMetadata(description: 'hello');
        expect(container.read(videoEditorProvider).tags, isEmpty);

        // Then insert # before "hello" to make "#hello"
        notifier.updateMetadata(description: '#hello');
        expect(container.read(videoEditorProvider).tags, contains('hello'));
      });

      test('extracts hashtag at end of description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'check out #flutter');
        expect(container.read(videoEditorProvider).tags, contains('flutter'));
      });

      test('extracts hashtag in middle of description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'check #dart today');
        expect(container.read(videoEditorProvider).tags, contains('dart'));
      });

      test('removes tag when # is deleted from description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'hello #world');
        expect(container.read(videoEditorProvider).tags, contains('world'));

        notifier.updateMetadata(description: 'hello world');
        expect(
          container.read(videoEditorProvider).tags,
          isNot(contains('world')),
        );
      });

      test('preserves manually added tags when description changes', () {
        final notifier = container.read(videoEditorProvider.notifier);

        // Manually add a tag
        notifier.updateMetadata(tags: {'manual'});
        expect(container.read(videoEditorProvider).tags, contains('manual'));

        // Change description - manual tag should persist
        notifier.updateMetadata(description: 'some text');
        expect(container.read(videoEditorProvider).tags, contains('manual'));
      });

      test('extracts hashtag from title field', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(title: 'My #video title');
        expect(container.read(videoEditorProvider).tags, contains('video'));
      });
    });

    group('updateMetadata description trimming', () {
      test(
        'truncates description by grapheme clusters without splitting emoji',
        () {
          final notifier = container.read(videoEditorProvider.notifier);

          // Build a description that exceeds descriptionLimit by repeating a
          // multi-code-unit emoji ("🎉" is one grapheme but 2 UTF-16 code
          // units). Naive substring on UTF-16 code units would split the
          // surrogate pair at the boundary and produce an invalid string.
          const emoji = '🎉';
          final longDescription =
              emoji * (VideoEditorConstants.descriptionLimit + 10);

          notifier.updateMetadata(description: longDescription);
          final stored = container.read(videoEditorProvider).description;

          expect(
            stored.characters.length,
            VideoEditorConstants.descriptionLimit,
            reason: 'should be truncated to limit measured in graphemes',
          );
          // The truncated string must remain composed of full emoji
          // graphemes — i.e. its UTF-16 code-unit length must be exactly
          // 2 * descriptionLimit (each emoji = 2 code units).
          expect(
            stored.length,
            VideoEditorConstants.descriptionLimit * 2,
            reason: 'no surrogate pair was split mid-character',
          );
          expect(
            stored.characters.every((g) => g == emoji),
            isTrue,
            reason: 'every grapheme is the original emoji',
          );
        },
      );

      test('preserves descriptions shorter than the limit verbatim', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'short text');
        expect(container.read(videoEditorProvider).description, 'short text');
      });

      test('trims whitespace before applying the grapheme limit', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: '   hello world   ');
        expect(container.read(videoEditorProvider).description, 'hello world');
      });
    });

    group('setDraftId', () {
      test('should set the draft ID', () {
        const id = 'test-draft-id';
        container.read(videoEditorProvider.notifier).setDraftId(id);

        expect(id, container.read(videoEditorProvider.notifier).draftId);
      });
    });

    group('audio render mapping', () {
      test('selected local import is rendered as file audio', () {
        final sound = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/imported/snare.mp3',
          createdAt: 1700000000,
          title: 'snare',
          mimeType: 'audio/mpeg',
          duration: 2,
        );

        final track = audioTrackFromSoundForRender(sound);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/imported/snare.mp3'));
        expect(track.audio.hasNetworkUrl, isFalse);
      });

      test('selected absolute-path url is rendered as file audio', () {
        final sound = AudioEvent(
          id: 'video_source_copy_3',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: '/tmp/extracted/selected.m4a',
          duration: 3,
        );

        final track = audioTrackFromSoundForRender(sound);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/extracted/selected.m4a'));
        expect(track.audio.hasNetworkUrl, isFalse);
      });

      test('selected sound without a resolvable source is skipped', () {
        final sound = AudioEvent(
          id: 'video_source_no_url',
          pubkey: 'pk',
          createdAt: 1700000000,
          duration: 3,
        );

        expect(audioTrackFromSoundForRender(sound), isNull);
      });

      test('selected sound without a known duration is skipped', () {
        final sound = AudioEvent(
          id: 'video_source_no_duration',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: 'https://media.divine.video/abc',
        );

        expect(audioTrackFromSoundForRender(sound), isNull);
      });

      test(
        'selected sound with a start offset gets a valid composition window',
        () {
          final sound = AudioEvent(
            id: 'video_selected_offset',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc',
            duration: 6.533,
            startOffset: const Duration(milliseconds: 292),
          );

          final track = audioTrackFromSoundForRender(sound);

          // Regression: previously startTime=startOffset and endTime=null
          // produced an invalid [0.292s, 0.0s] window the native renderer
          // dropped with "no time remaining in composition".
          expect(track, isNotNull);
          expect(track!.startTime, equals(Duration.zero));
          expect(track.endTime, equals(const Duration(milliseconds: 6533)));
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 292)),
          );
          // Null = play to file end, clipped by the composition window.
          expect(track.audioEndTime, isNull);
        },
      );

      test(
        'meta network original sound renders with its composition window and '
        'plays to file end',
        () {
          final event = AudioEvent(
            id: 'video_source_copy_1',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc123',
            duration: 6.533,
            startOffset: const Duration(milliseconds: 292),
            endTime: const Duration(milliseconds: 3966),
          );

          final track = audioTrackFromMetaForRender(event);

          expect(track, isNotNull);
          expect(track!.audio.hasNetworkUrl, isTrue);
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 292)),
          );
          // Null = play to the end of the file; the composition window clips
          // it. (Previously startOffset + full length overran the file end.)
          expect(track.audioEndTime, isNull);
          expect(track.startTime, equals(Duration.zero));
          expect(track.endTime, equals(const Duration(milliseconds: 3966)));
        },
      );

      test(
        'meta track with an invalid window plays across the whole video',
        () {
          // A sound added before its duration was known persists endTime=0.
          final event = AudioEvent(
            id: 'video_source_no_window',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc123',
            startOffset: const Duration(milliseconds: 100),
          );

          final track = audioTrackFromMetaForRender(event);

          expect(track, isNotNull);
          // Both null = play for the entire video, instead of an invalid
          // zero-length [start, 0] window the native renderer would drop.
          expect(track!.startTime, isNull);
          expect(track.endTime, isNull);
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 100)),
          );
          expect(track.audioEndTime, isNull);
        },
      );

      test('meta absolute-path url renders as file audio', () {
        final event = AudioEvent(
          id: 'video_source_copy_2',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: '/tmp/extracted/original.m4a',
          duration: 3,
        );

        final track = audioTrackFromMetaForRender(event);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/extracted/original.m4a'));
      });

      test('meta local import renders as file audio', () {
        final event = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/imported/beat.mp3',
          createdAt: 1700000000,
          title: 'beat',
          mimeType: 'audio/mpeg',
          duration: 4,
        );

        final track = audioTrackFromMetaForRender(event);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/imported/beat.mp3'));
      });

      test('meta track without a resolvable source is skipped', () {
        final event = AudioEvent(
          id: 'video_source_no_url',
          pubkey: 'pk',
          createdAt: 1700000000,
        );

        expect(audioTrackFromMetaForRender(event), isNull);
      });
    });

    group('setProcessing', () {
      test('sets isProcessing to true', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);

        expect(container.read(videoEditorProvider).isProcessing, isTrue);
      });

      test('sets isProcessing to false', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);
        container.read(videoEditorProvider.notifier).setProcessing(false);

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
      });

      test('is no-op when value unchanged', () {
        final stateBefore = container.read(videoEditorProvider);

        container.read(videoEditorProvider.notifier).setProcessing(false);

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
        );
      });
    });

    group('startRenderVideo', () {
      tearDown(() {
        VideoEditorRenderService.renderVideoToClipOverride = null;
      });

      test('resets isProcessing to false when finalRenderedClip '
          'already exists', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        // Simulate the UI calling setProcessing(true) before render
        notifier.setProcessing(true);
        expect(
          container.read(videoEditorProvider).isProcessing,
          isTrue,
          reason: 'isProcessing should be true before startRenderVideo',
        );

        // Set finalRenderedClip on the notifier state to simulate
        // a previously completed render
        notifier.state = notifier.state.copyWith(
          finalRenderedClip: DivineVideoClip(
            id: 'already-rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        // Call startRenderVideo — should early-return and reset
        // isProcessing to false
        await notifier.startRenderVideo();

        expect(
          container.read(videoEditorProvider).isProcessing,
          isFalse,
          reason:
              'isProcessing should be false after early return '
              'when finalRenderedClip already exists',
        );
      });

      test('sets finalRenderedClip when render completes', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        final renderedClip = DivineVideoClip(
          id: 'rendered',
          video: EditorVideo.file('/docs/rendered.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => (renderedClip, null);

        await notifier.startRenderVideo();

        final state = container.read(videoEditorProvider);
        expect(state.finalRenderedClip, equals(renderedClip));
        expect(state.isProcessing, isFalse);
      });

      test('flags renderFailed and clears isProcessing when render returns '
          'null (#6058)', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => throw const VideoRenderFailedException(
              VideoRenderFailureReason.nativeRender,
            );

        await notifier.startRenderVideo();

        final state = container.read(videoEditorProvider);
        expect(state.isProcessing, isFalse);
        expect(state.finalRenderedClip, isNull);
        // A render that produced no video is the primary way a genuine failure
        // surfaces the retry overlay — a regression that drops this flag would
        // leave the user stuck with no way to retry (#6058).
        expect(
          state.renderFailed,
          isTrue,
          reason: 'a failed render surfaces the retry affordance',
        );
      });

      test('flags renderFailed and clears isProcessing when render throws, '
          'then a retry re-renders (#6058)', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => throw Exception('C2PA network failure'); // hung proof

        await notifier.startRenderVideo();

        final failed = container.read(videoEditorProvider);
        expect(failed.isProcessing, isFalse);
        expect(
          failed.renderFailed,
          isTrue,
          reason: 'a failed render surfaces the retry affordance',
        );
        expect(failed.finalRenderedClip, isNull);

        // Retry: the render now succeeds and the failure state clears.
        final renderedClip = DivineVideoClip(
          id: 'rendered-after-retry',
          video: EditorVideo.file('/docs/rendered.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => (renderedClip, null);

        await notifier.startRenderVideo();

        final retried = container.read(videoEditorProvider);
        expect(retried.renderFailed, isFalse);
        expect(retried.isProcessing, isFalse);
        expect(retried.finalRenderedClip, equals(renderedClip));
      });

      test('discards stale render when a newer render was started', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        final slowCompleter = Completer<(DivineVideoClip, String?)>();
        final fastCompleter = Completer<(DivineVideoClip, String?)>();

        var callCount = 0;
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) {
              callCount++;
              // First call = slow render, second call = fast render
              return callCount == 1
                  ? slowCompleter.future
                  : fastCompleter.future;
            };

        final staleClip = DivineVideoClip(
          id: 'stale',
          video: EditorVideo.file('/docs/stale.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final freshClip = DivineVideoClip(
          id: 'fresh',
          video: EditorVideo.file('/docs/fresh.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Start first (slow) render
        final render1 = notifier.startRenderVideo();
        // Start second (fast) render — increments _renderGeneration
        final render2 = notifier.startRenderVideo();

        expect(callCount, equals(2));

        // Fast render completes first
        fastCompleter.complete((freshClip, null));
        await render2;

        // Slow render completes after — should be discarded
        slowCompleter.complete((staleClip, null));
        await render1;

        final state = container.read(videoEditorProvider);
        expect(
          state.finalRenderedClip?.id,
          equals('fresh'),
          reason:
              'should keep the result from the latest render, '
              'not the stale one',
        );
      });

      test('stale render does not reset isProcessing', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        final slowCompleter = Completer<(DivineVideoClip, String?)>();
        final fastCompleter = Completer<(DivineVideoClip, String?)>();

        var callCount = 0;
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) {
              callCount++;
              return callCount == 1
                  ? slowCompleter.future
                  : fastCompleter.future;
            };

        // Start first (slow) render
        final render1 = notifier.startRenderVideo();
        // Start second render — will fail
        final render2 = notifier.startRenderVideo();

        // Second render produces no video (simulating a native failure)
        fastCompleter.completeError(
          const VideoRenderFailedException(
            VideoRenderFailureReason.nativeRender,
          ),
        );
        await render2;

        // isProcessing should be false after the latest render failed
        expect(container.read(videoEditorProvider).isProcessing, isFalse);

        // Now the stale render completes — should be silently
        // discarded without touching state
        final staleClip = DivineVideoClip(
          id: 'stale',
          video: EditorVideo.file('/docs/stale.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        slowCompleter.complete((staleClip, null));
        await render1;

        expect(
          container.read(videoEditorProvider).finalRenderedClip,
          isNull,
          reason:
              'stale render result must not set '
              'finalRenderedClip',
        );
      });

      test('passes draftId as taskId to render service', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        notifier.setDraftId('my-draft-123');

        String? capturedTaskId;
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async {
              capturedTaskId = taskId;
              throw const VideoRenderFailedException(
                VideoRenderFailureReason.nativeRender,
              );
            };

        await notifier.startRenderVideo();

        expect(
          capturedTaskId,
          equals('my-draft-123'),
          reason: 'draftId should be used as the render taskId',
        );
      });

      test('uses autoSaveId as taskId when no draftId is set', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        String? capturedTaskId;
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async {
              capturedTaskId = taskId;
              throw const VideoRenderFailedException(
                VideoRenderFailureReason.nativeRender,
              );
            };

        await notifier.startRenderVideo();

        expect(
          capturedTaskId,
          equals(VideoEditorConstants.autoSaveId),
          reason:
              'should fall back to autoSaveId when '
              'no draftId is set',
        );
      });

      // #8488: a native call in the render chain can hang — the platform
      // channel neither returns nor throws, so the awaiting coroutine stays
      // suspended and every `catch`/`finally` that would reset the flags is
      // unreachable. Without a bound the editor sits on a 0% spinner with Post
      // disabled forever, and the retry overlay that already exists is never
      // shown.
      test('surfaces a failure when the render never settles', () {
        fakeAsync((async) {
          final notifier = container.read(videoEditorProvider.notifier);
          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          // Never completes and never throws — a hung native call.
          final hung = Completer<(DivineVideoClip, String?)>();
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                parameters,
                taskId,
              }) => hung.future;

          unawaited(notifier.startRenderVideo());
          async.flushMicrotasks();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isTrue,
            reason: 'the render is in flight',
          );

          async.elapse(VideoEditorConstants.renderWatchdogTimeout);
          async.flushMicrotasks();

          final state = container.read(videoEditorProvider);
          expect(
            state.isProcessing,
            isFalse,
            reason: 'a render that cannot finish must stop reporting progress',
          );
          expect(
            state.renderFailed,
            isTrue,
            reason: 'the retry overlay is the only way out of a hung render',
          );
          expect(
            state.isValidToPost,
            isFalse,
            reason: 'there is no rendered clip to post',
          );
        });
      });
    });

    group('c2paSigningFailedFor (#6058)', () {
      String proofJson({String? c2paManifestId}) => jsonEncode(
        NativeProofData(
          videoHash: 'hash',
          c2paManifestId: c2paManifestId,
        ).toJson(),
      );

      test('is false when signing is not configured (CI / unconfigured)', () {
        expect(
          VideoEditorNotifier.c2paSigningFailedFor(
            signingConfigured: false,
            proofManifestJson: proofJson(),
          ),
          isFalse,
        );
      });

      test('is true when configured but the proof has no C2PA manifest', () {
        expect(
          VideoEditorNotifier.c2paSigningFailedFor(
            signingConfigured: true,
            proofManifestJson: proofJson(),
          ),
          isTrue,
        );
      });

      test('is true when configured and there is no proof at all', () {
        expect(
          VideoEditorNotifier.c2paSigningFailedFor(
            signingConfigured: true,
            proofManifestJson: null,
          ),
          isTrue,
        );
      });

      test(
        'is false when configured and the proof carries a C2PA manifest',
        () {
          expect(
            VideoEditorNotifier.c2paSigningFailedFor(
              signingConfigured: true,
              proofManifestJson: proofJson(c2paManifestId: 'urn:c2pa:abc'),
            ),
            isFalse,
          );
        },
      );
    });

    group('copyWith clearFinalRenderedClip (#6058)', () {
      test(
        'drops renderFailed and c2paSigningFailed when the clip is cleared',
        () {
          final rendered = DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          final failed = VideoEditorProviderState(
            renderFailed: true,
            c2paSigningFailed: true,
            finalRenderedClip: rendered,
          );

          // invalidateFinalRenderedClip clears the clip on every post-render
          // edit; a stuck failure/prompt over a clip that no longer exists must
          // not survive that clear (#6058).
          final cleared = failed.copyWith(clearFinalRenderedClip: true);

          expect(cleared.finalRenderedClip, isNull);
          expect(cleared.renderFailed, isFalse);
          expect(cleared.c2paSigningFailed, isFalse);
        },
      );

      test('keeps editorEditingParameters when the clip is cleared', () {
        final params = CompleteParameters.fromMap(
          <String, dynamic>{},
        ).copyWith(blur: 0.25);
        final state = VideoEditorProviderState(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
          editorEditingParameters: params,
        );

        final cleared = state.copyWith(clearFinalRenderedClip: true);

        expect(cleared.finalRenderedClip, isNull);
        expect(
          cleared.editorEditingParameters,
          same(params),
          reason:
              'restoring a draft with a missing cached render must keep the '
              'editing parameters needed to re-render overlays at publish time',
        );
      });
    });

    group('acknowledgeC2paSigningFailure (#6058)', () {
      test('clears the pending C2PA prompt flag', () {
        final notifier = container.read(videoEditorProvider.notifier);
        notifier.state = notifier.state.copyWith(c2paSigningFailed: true);

        notifier.acknowledgeC2paSigningFailure();

        expect(container.read(videoEditorProvider).c2paSigningFailed, isFalse);
      });
    });

    group('retryC2paSigning (#6058)', () {
      tearDown(() {
        VideoEditorRenderService.renderVideoToClipOverride = null;
        NativeProofModeService.proofFileOverride = null;
      });

      test('re-signs the existing render without re-encoding', () async {
        final notifier = container.read(videoEditorProvider.notifier);
        final rendered = DivineVideoClip(
          id: 'rendered',
          video: EditorVideo.file('/docs/rendered.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.state = notifier.state.copyWith(
          finalRenderedClip: rendered,
          c2paSigningFailed: true,
        );

        var reRendered = false;
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async {
              reRendered = true;
              throw const VideoRenderFailedException(
                VideoRenderFailureReason.nativeRender,
              );
            };
        NativeProofModeService.proofFileOverride =
            (
              file, {
              required enableAdvancedCawgEmbedding,
              creatorBindingAssertion,
              cawgIdentityAssertion,
              verifiedIdentityBundle,
              clips,
              editorStateHistory,
            }) async => const NativeProofData(
              videoHash: 'h',
              c2paManifestId: 'urn:c2pa:new',
            );

        await notifier.retryC2paSigning();

        final state = container.read(videoEditorProvider);
        expect(
          reRendered,
          isFalse,
          reason: 'a C2PA-only retry must not re-encode the video',
        );
        expect(
          state.finalRenderedClip,
          equals(rendered),
          reason: 'the existing rendered clip is reused',
        );
        expect(state.proofManifestJson, contains('urn:c2pa:new'));
        expect(state.isProcessing, isFalse);
      });

      test(
        're-signs rendered stop-motion output without requiring a source mp4',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);
          container
              .read(clipManagerProvider.notifier)
              .addStopMotionClip(
                id: 'frames-only',
                frames: [
                  const StopMotionClipFrame(
                    path: '/docs/frame.jpg',
                    duration: Duration(milliseconds: 83),
                  ),
                ],
                duration: const Duration(milliseconds: 83),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              );
          final rendered = DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          notifier.state = notifier.state.copyWith(
            finalRenderedClip: rendered,
            c2paSigningFailed: true,
          );

          String? proofedPath;
          NativeProofModeService.proofFileOverride =
              (
                file, {
                required enableAdvancedCawgEmbedding,
                creatorBindingAssertion,
                cawgIdentityAssertion,
                verifiedIdentityBundle,
                clips,
                editorStateHistory,
              }) async {
                proofedPath = file.path;
                return const NativeProofData(
                  videoHash: 'h',
                  c2paManifestId: 'urn:c2pa:stop-motion',
                );
              };

          await notifier.retryC2paSigning();

          final state = container.read(videoEditorProvider);
          expect(proofedPath, '/docs/rendered.mp4');
          expect(state.c2paSigningFailed, isFalse);
          expect(state.proofManifestJson, contains('urn:c2pa:stop-motion'));
          expect(state.finalRenderedClip, equals(rendered));
          expect(state.isProcessing, isFalse);
        },
      );

      test(
        're-raises the prompt when the re-sign fails again (#6058)',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);
          final rendered = DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          notifier.state = notifier.state.copyWith(
            finalRenderedClip: rendered,
            c2paSigningFailed: false,
          );

          // Network still down on retry — the re-sign throws.
          NativeProofModeService.proofFileOverride =
              (
                file, {
                required enableAdvancedCawgEmbedding,
                creatorBindingAssertion,
                cawgIdentityAssertion,
                verifiedIdentityBundle,
                clips,
                editorStateHistory,
              }) async => throw Exception('still offline');

          await notifier.retryC2paSigning();

          final state = container.read(videoEditorProvider);
          expect(
            state.c2paSigningFailed,
            isTrue,
            reason:
                'a failed re-sign must re-raise the prompt so the user '
                'learns it did not work',
          );
          expect(state.isProcessing, isFalse);
          expect(
            state.finalRenderedClip,
            equals(rendered),
            reason:
                'the rendered clip is kept — only the credential is missing',
          );
        },
      );
    });

    group('invalidateFinalRenderedClip', () {
      test('is a no-op when finalRenderedClip is null', () {
        final notifier = container.read(videoEditorProvider.notifier);
        final stateBefore = container.read(videoEditorProvider);

        expect(stateBefore.finalRenderedClip, isNull);

        notifier.invalidateFinalRenderedClip();

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
          reason:
              'state should be the exact same instance '
              'when clip is already null',
        );
      });

      test('is a no-op when finalRenderedClip is null even if '
          'isProcessing is true', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setProcessing(true);
        final stateBefore = container.read(videoEditorProvider);

        expect(stateBefore.finalRenderedClip, isNull);
        expect(stateBefore.isProcessing, isTrue);

        notifier.invalidateFinalRenderedClip();

        // isProcessing should still be true — cancelRenderVideo was
        // never called because clip was null.
        expect(
          container.read(videoEditorProvider).isProcessing,
          isTrue,
          reason:
              'isProcessing should remain true because '
              'invalidate is a no-op when clip is null',
        );
      });
    });

    group('updateCover', () {
      test('is a no-op when finalRenderedClip is null', () {
        final notifier = container.read(videoEditorProvider.notifier);
        final stateBefore = container.read(videoEditorProvider);

        expect(stateBefore.finalRenderedClip, isNull);

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
          reason:
              'state should be the exact same instance when '
              'finalRenderedClip is null — no autosave triggered',
        );
      });

      test('updates thumbnailPath and thumbnailTimestamp on the clip', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.state = notifier.state.copyWith(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        final updatedClip = container
            .read(videoEditorProvider)
            .finalRenderedClip;
        expect(updatedClip, isNotNull);
        expect(updatedClip!.thumbnailPath, '/docs/cover.jpg');
        expect(updatedClip.thumbnailTimestamp, const Duration(seconds: 2));
      });

      test('persists the cover position on state so it survives a '
          're-render', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.state = notifier.state.copyWith(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        final state = container.read(videoEditorProvider);
        expect(
          state.thumbnailTimestamp,
          const Duration(seconds: 2),
          reason:
              'updateCover must record the cover position on state, not '
              'only on finalRenderedClip, so it survives invalidation',
        );
        expect(
          state.customThumbnailPath,
          '/docs/cover.jpg',
          reason:
              'updateCover must record the cover image path durably so cover '
              'displays survive finalRenderedClip being cleared',
        );
      });
    });

    group('video_generation trace', () {
      // Telemetry-only: a regression here mislabels a Firebase sample, not a
      // user-facing bug — a touch belt-and-suspenders, kept so the per-render
      // trace scoping and outcome mapping can't silently rot.
      tearDown(() {
        VideoEditorRenderService.renderVideoToClipOverride = null;
      });

      void addOneClip() {
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/docs/clip.mp4'),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
      }

      test(
        'overlapping renders each own a trace, stopped once, with their own '
        'attributes',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);
          addOneClip();

          final slowCompleter = Completer<(DivineVideoClip, String?)>();
          final fastCompleter = Completer<(DivineVideoClip, String?)>();
          var callCount = 0;
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                parameters,
                taskId,
              }) {
                callCount++;
                return callCount == 1
                    ? slowCompleter.future
                    : fastCompleter.future;
              };

          final freshClip = DivineVideoClip(
            id: 'fresh',
            video: EditorVideo.file('/docs/fresh.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          // render1 = generation 1 (slow, superseded); render2 = generation 2
          // (fast, winner). Each captures its own operation-scoped trace.
          final render1 = notifier.startRenderVideo();
          final render2 = notifier.startRenderVideo();
          expect(callCount, equals(2));
          expect(
            performanceMonitor.traces.length,
            2,
            reason: 'each render must start its own trace, not share one',
          );

          fastCompleter.complete((freshClip, null));
          await render2;
          slowCompleter.complete((freshClip, null));
          await render1;

          final trace1 = performanceMonitor.traces[0];
          final trace2 = performanceMonitor.traces[1];

          // Each trace is stopped exactly once — neither render stops the
          // other's trace.
          expect(trace1.stopCount, 1);
          expect(trace2.stopCount, 1);

          // Each trace keeps its own outcome: the winner is success, the
          // superseded render is incomplete (not overwritten onto the winner).
          expect(trace2.attributes['outcome'], 'success');
          expect(trace1.attributes['outcome'], 'incomplete');
          expect(trace1.attributes['clip_count'], '1');
          expect(trace2.attributes['clip_count'], '1');
        },
      );

      void failRenderWith(VideoRenderFailedException failure) {
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => throw failure;
      }

      test('tags outcome=failed with the reason behind a render that produced '
          'no video (#7125)', () async {
        final notifier = container.read(videoEditorProvider.notifier);
        addOneClip();
        failRenderWith(
          const VideoRenderFailedException(
            VideoRenderFailureReason.stopMotionAssembly,
          ),
        );

        await notifier.startRenderVideo();
        final trace = performanceMonitor.traces.single;
        expect(trace.attributes['outcome'], 'failed');
        expect(trace.attributes['failure_reason'], 'stop_motion_assembly');
      });

      test('carries the native cause type in the reason, not its message '
          '(#7125)', () async {
        final notifier = container.read(videoEditorProvider.notifier);
        addOneClip();
        failRenderWith(
          VideoRenderFailedException(
            VideoRenderFailureReason.nativeRender,
            cause: PlatformException(
              code: 'RENDER_ERROR',
              message: '/var/mobile/Containers/Data/Application/x/clip.mp4',
            ),
          ),
        );

        await notifier.startRenderVideo();
        final reason =
            performanceMonitor.traces.single.attributes['failure_reason'];
        expect(reason, 'native_render:PlatformException');
        expect(
          reason,
          isNot(contains('/var/mobile')),
          reason: 'device paths must not ride into a trace attribute',
        );
      });

      test('tags a cancelled render incomplete, not failed (#7125)', () async {
        final notifier = container.read(videoEditorProvider.notifier);
        addOneClip();
        failRenderWith(
          const VideoRenderFailedException(VideoRenderFailureReason.canceled),
        );

        await notifier.startRenderVideo();
        final trace = performanceMonitor.traces.single;
        expect(
          trace.attributes['outcome'],
          'incomplete',
          reason:
              'teardown cancelling in-flight native tasks is not a render that '
              'could not produce a video',
        );
        expect(trace.attributes['failure_reason'], 'canceled');
      });

      test('tags outcome=error with the type when the render throws', () async {
        final notifier = container.read(videoEditorProvider.notifier);
        addOneClip();
        VideoEditorRenderService.renderVideoToClipOverride =
            ({
              required clips,
              required editorStateHistory,
              parameters,
              taskId,
            }) async => throw StateError('render boom');

        await notifier.startRenderVideo();
        final trace = performanceMonitor.traces.single;
        expect(trace.attributes['outcome'], 'error');
        expect(trace.attributes['failure_reason'], 'StateError');
      });
    });

    group('cancelRenderVideo', () {
      tearDown(() {
        VideoEditorRenderService.renderVideoToClipOverride = null;
      });

      test(
        'resets isProcessing to false when clips are already empty',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                video: EditorVideo.file('/docs/original.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
                limitClipDuration: false,
              );

          notifier.setProcessing(true);
          container.read(clipManagerProvider.notifier).clearClips();

          await notifier.cancelRenderVideo();

          expect(container.read(videoEditorProvider).isProcessing, isFalse);
        },
      );

      test('resets isProcessing to false without clips', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setProcessing(true);
        expect(container.read(videoEditorProvider).isProcessing, isTrue);

        await notifier.cancelRenderVideo();

        expect(
          container.read(videoEditorProvider).isProcessing,
          isFalse,
          reason:
              'isProcessing should always reset to false '
              'after cancel, regardless of clip state',
        );
      });

      test('uses draftId as taskId for cancel', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setDraftId('custom-draft-id');
        notifier.setProcessing(true);

        // cancelRenderVideo should not throw — it uses
        // draftId internally as the task identifier
        await notifier.cancelRenderVideo();

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
        expect(notifier.draftId, equals('custom-draft-id'));
      });

      test('uses default autoSaveId when no draftId is set', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setProcessing(true);

        // Without setting a custom draftId, it should fall back
        // to VideoEditorConstants.autoSaveId
        expect(notifier.draftId, equals(VideoEditorConstants.autoSaveId));

        await notifier.cancelRenderVideo();

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
      });

      test(
        'waits for active render future to unwind before completing cancel',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                video: EditorVideo.file('/docs/original.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
                limitClipDuration: false,
              );

          final renderCompleter = Completer<(DivineVideoClip, String?)>();
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                parameters,
                taskId,
              }) => renderCompleter.future;

          final render = notifier.startRenderVideo();

          var cancelCompleted = false;
          final cancel = notifier.cancelRenderVideo().then(
            (_) => cancelCompleted = true,
          );

          await Future<void>.delayed(Duration.zero);
          expect(
            cancelCompleted,
            isFalse,
            reason:
                'cancel must not let the editor rebuild its preview decoder '
                'until the active render future has released native resources',
          );

          renderCompleter.completeError(
            const VideoRenderFailedException(
              VideoRenderFailureReason.canceled,
            ),
          );
          await cancel;
          await render;

          expect(cancelCompleted, isTrue);
          expect(container.read(videoEditorProvider).isProcessing, isFalse);
        },
      );
    });
  });

  group('getActiveDraft', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should use _clips when finalRenderedClip is null', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      container.read(videoEditorProvider.notifier).setDraftId('test-draft');

      // finalRenderedClip is null by default, so getActiveDraft should
      // use _clips for both autosave and non-autosave
      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.clips, hasLength(1));
      expect(draft.id, equals('test-draft'));
    });

    test('autosave should always use _clips even if '
        'finalRenderedClip were set', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      // Autosave should use _clips
      final autosaveDraft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft(isAutosave: true);

      expect(autosaveDraft.clips, hasLength(1));
      expect(autosaveDraft.id, equals(VideoEditorConstants.autoSaveId));
    });
  });

  group('initFromPublishedVideo', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    VideoEvent buildVideo({
      List<List<String>> nostrEventTags = const [],
      Map<String, String> rawTags = const {},
      String content = 'A published clip',
    }) {
      return VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: content,
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Published clip',
        videoUrl: 'https://media.divine.video/published.mp4',
        nostrEventTags: nostrEventTags,
        rawTags: rawTags,
      );
    }

    test('seeds allowAudioReuse from live nostrEventTags', () {
      // rawTags is intentionally left empty so this isolates the live-tag
      // source: if the live-path scan regressed, there is no fallback to
      // mask it and the toggle would seed false.
      container
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(
            buildVideo(
              nostrEventTags: const [
                ['allow_audio_reuse', 'true'],
              ],
            ),
          );

      expect(container.read(videoEditorProvider).allowAudioReuse, isTrue);
    });

    test('seeds allowAudioReuse from rawTags when the event was '
        'rehydrated from cache (nostrEventTags dropped)', () {
      container
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(
            buildVideo(rawTags: const {'allow_audio_reuse': 'true'}),
          );

      // Regression (#6045): before the fix this seeded false because the
      // cache path drops nostrEventTags, so a save would strip the marker.
      expect(container.read(videoEditorProvider).allowAudioReuse, isTrue);
    });

    test('leaves allowAudioReuse off when the marker is absent', () {
      container
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(buildVideo());

      expect(container.read(videoEditorProvider).allowAudioReuse, isFalse);
    });

    test('strips a trailing inspired-by line from the description', () {
      container
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(
            buildVideo(
              content: 'A caption\n\nInspired by nostr:npub1someattribution',
            ),
          );

      expect(
        container.read(videoEditorProvider).description,
        equals('A caption'),
      );
    });

    test('strips a whole-content inspired-by line (empty caption publish)', () {
      // Empty-caption publishes trim the leading newlines, so the
      // attribution line is the entire content. Before the fix the strip
      // required a '\n\n' prefix, seeding the edit form with the raw line
      // and duplicating it on every republish.
      container
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(
            buildVideo(content: 'Inspired by nostr:npub1someattribution'),
          );

      expect(container.read(videoEditorProvider).description, isEmpty);
    });
  });

  group('VideoEditorProviderState', () {
    group('isValidToPost', () {
      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.finalRenderedClip, isNull);
        expect(state.isValidToPost, isFalse);
      });

      test('returns true when finalRenderedClip is set and not processing', () {
        final state = VideoEditorProviderState(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isTrue);
      });

      test('returns false when metadataLimitReached even with clip', () {
        final state = VideoEditorProviderState(
          metadataLimitReached: true,
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when isProcessing even with clip', () {
        final state = VideoEditorProviderState(
          isProcessing: true,
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });
    });
  });

  group('getActiveDraft', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should use _clips when finalRenderedClip is null', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      container.read(videoEditorProvider.notifier).setDraftId('test-draft');

      // finalRenderedClip is null by default, so getActiveDraft should
      // use _clips for both autosave and non-autosave
      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.clips, hasLength(1));
      expect(draft.id, equals('test-draft'));
    });

    test('autosave should always use _clips even if '
        'finalRenderedClip were set', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      // Autosave should use _clips
      final autosaveDraft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft(isAutosave: true);

      expect(autosaveDraft.clips, hasLength(1));
      expect(autosaveDraft.id, equals(VideoEditorConstants.autoSaveId));
    });
  });

  group('VideoEditorProviderState', () {
    test('copyWith should preserve unchanged values', () {
      final original = VideoEditorProviderState(
        isProcessing: true,
        isSavingDraft: true,
        allowAudioReuse: true,
        title: 'Test',
        description: 'Desc',
        tags: const {'tag1'},
        metadataLimitReached: true,
      );

      final copied = original.copyWith();

      expect(copied.isProcessing, true);
      expect(copied.isSavingDraft, true);
      expect(copied.allowAudioReuse, true);
      expect(copied.title, 'Test');
      expect(copied.description, 'Desc');
      expect(copied.tags, equals({'tag1'}));
      expect(copied.metadataLimitReached, true);
    });

    test('copyWith should update only specified values', () {
      final original = VideoEditorProviderState(
        isProcessing: true,
        title: 'Original',
      );

      final copied = original.copyWith(isProcessing: false, title: 'Updated');

      expect(copied.isProcessing, false);
      expect(copied.title, 'Updated');
    });

    group('isValidToPost', () {
      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.finalRenderedClip, isNull);
        expect(state.isValidToPost, isFalse);
      });

      test('returns true when finalRenderedClip is set and not processing', () {
        final state = VideoEditorProviderState(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isTrue);
      });

      test('returns false when metadataLimitReached even with clip', () {
        final state = VideoEditorProviderState(
          metadataLimitReached: true,
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when isProcessing even with clip', () {
        final state = VideoEditorProviderState(
          isProcessing: true,
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });
    });

    group('restoreDraft', () {
      late _MockDraftStorageService mockDraftStorage;
      late ProviderContainer container;
      late Directory tempDir;
      late String clipVideoPath;
      late String clipThumbnailPath;
      late MockAuthService mockAuthService;

      setUpAll(() {
        registerFallbackValue(
          DivineVideoDraft.create(
            id: 'fallback',
            clips: const [],
            title: '',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
          ),
        );
      });

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        mockDraftStorage = _MockDraftStorageService();
        mockAuthService = createMockAuthService();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
        );
        // A restorable clip must point at media that actually exists on disk;
        // restoreDraft drops clips whose source file is gone.
        tempDir = await Directory.systemTemp.createTemp('restore_draft_test');
        clipVideoPath = '${tempDir.path}/clip.mp4';
        clipThumbnailPath = '${tempDir.path}/clip_thumb.jpg';
        await File(clipVideoPath).writeAsBytes(const [0]);
        await File(clipThumbnailPath).writeAsBytes(const [0]);
      });

      tearDown(() async {
        container.dispose();
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      test('returns false when draft is not found', () async {
        when(
          () => mockDraftStorage.getDraftById(any()),
        ).thenAnswer((_) async => null);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft();

        expect(result, isFalse);
        verify(
          () => mockDraftStorage.getDraftById(VideoEditorConstants.autoSaveId),
        ).called(1);
      });

      test('returns false when draft is not found for custom id', () async {
        when(
          () => mockDraftStorage.getDraftById('custom-draft-id'),
        ).thenAnswer((_) async => null);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('custom-draft-id');

        expect(result, isFalse);
        verify(
          () => mockDraftStorage.getDraftById('custom-draft-id'),
        ).called(1);
      });

      test('uses autoSaveId when no draftId is provided', () async {
        when(
          () => mockDraftStorage.getDraftById(any()),
        ).thenAnswer((_) async => null);

        await container.read(videoEditorProvider.notifier).restoreDraft();

        verify(
          () => mockDraftStorage.getDraftById(VideoEditorConstants.autoSaveId),
        ).called(1);
      });

      test(
        'removes the signed-in creator from restored collaborator state',
        () async {
          const creatorPubkey =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          const collaboratorPubkey =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(creatorPubkey);
          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'present',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            collaboratorPubkeys: {
              creatorPubkey.toUpperCase(),
              NostrKeyUtils.encodePubKey(creatorPubkey),
              collaboratorPubkey,
            },
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(result, isTrue);
          expect(
            container.read(videoEditorProvider).collaboratorPubkeys,
            {collaboratorPubkey},
          );
        },
      );

      test(
        'drops clips whose source video file is missing on restore',
        () async {
          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'present',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
              // This clip's media was deleted by FileCleanupService after it
              // was removed mid-session; the draft's undo history still carries
              // it. Restoring it would freeze the editor (COMPOSITION_ERROR).
              DivineVideoClip(
                id: 'orphan',
                video: EditorVideo.file('${tempDir.path}/deleted.mp4'),
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(result, isTrue);
          final clips = container.read(clipManagerProvider).clips;
          expect(
            clips.map((c) => c.id),
            ['present'],
            reason:
                'the clip with a missing source file must be dropped, '
                'leaving only the clip whose media still exists',
          );
        },
      );

      test(
        'repairs a frames-only stop-motion clip thumbnail from its first still',
        () async {
          // A frames-only stop-motion draft with no rendered video and a
          // missing thumbnail must repair from its first still, not reach for
          // requireVideo (which throws on a video-less clip) and abort restore.
          final framePath = '${tempDir.path}/frame_a.jpg';
          await File(framePath).writeAsBytes(const [0]);
          final draft = DivineVideoDraft.create(
            id: 'sm-draft',
            clips: [
              DivineVideoClip(
                id: 'sm',
                stopMotionFrames: [
                  StopMotionClipFrame(
                    path: framePath,
                    duration: const Duration(milliseconds: 83),
                  ),
                ],
                duration: const Duration(milliseconds: 83),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
          );
          when(
            () => mockDraftStorage.getDraftById('sm-draft'),
          ).thenAnswer((_) async => draft);

          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('sm-draft');

          expect(result, isTrue);
          final clips = container.read(clipManagerProvider).clips;
          expect(clips, hasLength(1));
          expect(clips.single.thumbnailPath, framePath);
        },
      );

      test('returns false when every clip has a missing source file', () async {
        final draft = DivineVideoDraft.create(
          id: 'draft-1',
          clips: [
            DivineVideoClip(
              id: 'orphan',
              video: EditorVideo.file('${tempDir.path}/deleted.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        );
        when(
          () => mockDraftStorage.getDraftById('draft-1'),
        ).thenAnswer((_) async => draft);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('draft-1');

        expect(result, isFalse);
        expect(container.read(clipManagerProvider).clips, isEmpty);
      });

      test(
        'drops clip-source credits when the reused clip is deleted',
        () async {
          const sourceCreator =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'reused',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                sourceAuthorPubkey: sourceCreator,
                sourceAddressableId: '34236:$sourceCreator:reused-source',
                sourceRelayHint: 'wss://source.relay',
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            clipSourceCredits: const [
              ClipSourceCredit(
                authorPubkey: sourceCreator,
                addressableId: '34236:$sourceCreator:reused-source',
                relayUrl: 'wss://source.relay',
              ),
            ],
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');
          container.read(clipManagerProvider.notifier).replaceClips([
            DivineVideoClip(
              id: 'local',
              video: EditorVideo.file(clipVideoPath),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ], autosave: false);

          expect(
            container
                .read(videoEditorProvider.notifier)
                .getActiveDraft()
                .clipSourceCredits,
            isEmpty,
            reason:
                'a clip-source credit is a factual claim about footage in the '
                'video; deleting the reused clip must not leave the credit '
                'behind to be published and notify its creator',
          );
        },
      );

      test(
        'drops clip-source credits of a clip whose media went missing',
        () async {
          const sourceCreator =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'present',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
              DivineVideoClip(
                id: 'orphan',
                video: EditorVideo.file('${tempDir.path}/deleted.mp4'),
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                sourceAuthorPubkey: sourceCreator,
                sourceAddressableId: '34236:$sourceCreator:reused-source',
                sourceRelayHint: 'wss://source.relay',
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            clipSourceCredits: const [
              ClipSourceCredit(
                authorPubkey: sourceCreator,
                addressableId: '34236:$sourceCreator:reused-source',
                relayUrl: 'wss://source.relay',
              ),
            ],
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(
            container
                .read(videoEditorProvider.notifier)
                .getActiveDraft()
                .clipSourceCredits,
            isEmpty,
            reason:
                'restore drops the orphaned clip, so its footage is no longer '
                'in the video and its credit must go with it',
          );
        },
      );

      test('restores the saved cover position onto state', () async {
        final draft = DivineVideoDraft.create(
          id: 'draft-1',
          clips: [
            DivineVideoClip(
              id: 'c1',
              video: EditorVideo.file(clipVideoPath),
              thumbnailPath: clipThumbnailPath,
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
          thumbnailTimestamp: const Duration(milliseconds: 900),
        );
        when(
          () => mockDraftStorage.getDraftById('draft-1'),
        ).thenAnswer((_) async => draft);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('draft-1');

        expect(result, isTrue);
        expect(
          container.read(videoEditorProvider).thumbnailTimestamp,
          const Duration(milliseconds: 900),
          reason: 'reopening a draft must restore the selected cover position',
        );
      });

      test('restores the durable custom cover path onto state', () async {
        final draft = DivineVideoDraft.create(
          id: 'draft-1',
          clips: [
            DivineVideoClip(
              id: 'c1',
              video: EditorVideo.file(clipVideoPath),
              thumbnailPath: clipThumbnailPath,
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
          thumbnailTimestamp: const Duration(milliseconds: 900),
          customThumbnailPath: '/docs/cover.jpg',
        );
        when(
          () => mockDraftStorage.getDraftById('draft-1'),
        ).thenAnswer((_) async => draft);

        await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('draft-1');

        expect(
          container.read(videoEditorProvider).customThumbnailPath,
          '/docs/cover.jpg',
          reason:
              'the selected cover image path must survive reopening a draft, '
              'independently of finalRenderedClip (#5181)',
        );
      });

      test(
        'restores a draft whose editorEditingParameters contain a sticker '
        'widget layer without crashing on the widgetLoader assertion',
        () async {
          const sticker = StickerData.network(
            'https://stickers.example.com/heart.png',
            description: LocalizedText({'en': 'Red heart'}),
            tags: ['heart'],
            packData: StickerPackData(
              packId: 'reactions',
              packName: 'Reactions',
            ),
          );
          final stickerLayer = WidgetLayer(
            width: 120,
            widget: const VideoEditorSticker(
              sticker: sticker,
              enableLimitCacheSize: false,
            ),
            meta: sticker.toJson(),
            exportConfigs: WidgetLayerExportConfigs(
              id: 'sticker-${sticker.description.fallback}',
              meta: sticker.toJson(),
            ),
          );
          final params = CompleteParameters(
            blur: 0,
            originalImageSize: const Size(1080, 1920),
            temporaryDecodedImageSize: const Size(1080, 1920),
            bodySize: const Size(400, 800),
            editorSize: const Size(400, 800),
            matrixFilterList: const [],
            matrixTuneAdjustmentsList: const [],
            startTime: null,
            endTime: null,
            cropWidth: null,
            cropHeight: null,
            rotateTurns: 0,
            cropX: null,
            cropY: null,
            flipX: false,
            flipY: false,
            image: Uint8List(0),
            isTransformed: false,
            layers: [stickerLayer],
          );

          // Mirror how a draft persists editorEditingParameters: the in-memory
          // CompleteParameters is serialized via toMap() and round-tripped
          // through JSON into storage.
          final persistedParameters =
              json.decode(json.encode(params.toMap())) as Map<String, dynamic>;

          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'c1',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            editorEditingParameters: persistedParameters,
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          // restoreDraft rehydrates editorEditingParameters via
          // completeParametersFromDraftMap, which threads
          // videoEditorStickerWidgetLoader so the exported-by-id sticker layer
          // rebuilds into a VideoEditorSticker. Reverting that call site to a
          // bare CompleteParameters.fromMap would throw the widgetLoader
          // assertion here, surfacing as a thrown restore rather than a green
          // test (#5474).
          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(result, isTrue);
        },
      );

      test(
        'viewing a draft is read-only: restore keeps the finalRenderedClip '
        'instead of invalidating it (#5956)',
        () async {
          final renderedPath = '${tempDir.path}/rendered.mp4';
          await File(renderedPath).writeAsBytes(const [0]);

          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'c1',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            finalRenderedClip: DivineVideoClip(
              id: 'rendered',
              video: EditorVideo.file(renderedPath),
              thumbnailPath: clipThumbnailPath,
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(result, isTrue);
          expect(
            container.read(videoEditorProvider).finalRenderedClip?.id,
            'rendered',
            reason:
                'restoring a draft to view it must not autosave: an autosave '
                'invalidates (and deletes) the restored finalRenderedClip and '
                'bumps lastModified, making the draft look freshly saved',
          );
        },
      );

      test(
        'viewing a draft is read-only: no re-save fires once the autosave '
        'debounce elapses (#5956)',
        () {
          final renderedPath = '${tempDir.path}/rendered.mp4';
          File(renderedPath).writeAsBytesSync(const [0]);

          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'c1',
                video: EditorVideo.file(clipVideoPath),
                thumbnailPath: clipThumbnailPath,
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            finalRenderedClip: DivineVideoClip(
              id: 'rendered',
              video: EditorVideo.file(renderedPath),
              thumbnailPath: clipThumbnailPath,
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          fakeAsync((async) {
            bool? result;
            container
                .read(videoEditorProvider.notifier)
                .restoreDraft('draft-1')
                .then((value) => result = value);
            async.flushMicrotasks();
            expect(result, isTrue);

            // Elapse well past the autosave debounce; a restore that
            // re-triggers autosave would re-save the draft here, bumping
            // lastModified and reordering it to the top of the drafts list.
            async.elapse(const Duration(seconds: 10));

            verifyNever(
              () => mockDraftStorage.saveDraft(
                any(),
                deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
              ),
            );
          });
        },
      );
    });
  });

  group('VideoEditorProviderState reusesExternalAudio', () {
    final sourceVideoId = 'b' * 64;

    CompleteParameters paramsWithTrack(AudioEvent track) =>
        CompleteParameters.fromMap(<String, dynamic>{}).copyWith(
          meta: {
            VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
          },
        );

    AudioEvent sound({String? anchorClipId}) => AudioEvent(
      id: 'video_$sourceVideoId',
      pubkey: 'c' * 64,
      createdAt: 1700000000,
      anchorClipId: anchorClipId,
    );

    test('is false with no selected sound and no editor tracks', () {
      expect(VideoEditorProviderState().reusesExternalAudio, isFalse);
    });

    test("is true when another creator's reused sound is selected", () {
      final state = VideoEditorProviderState(selectedSound: sound());
      expect(state.reusesExternalAudio, isTrue);
    });

    test(
      "is true when the editor timeline has another creator's reused track",
      () {
        final state = VideoEditorProviderState(
          editorEditingParameters: paramsWithTrack(sound()),
        );
        expect(state.reusesExternalAudio, isTrue);
      },
    );

    test(
      "is false when the only track is the video's own clip-anchored sound",
      () {
        final state = VideoEditorProviderState(
          editorEditingParameters: paramsWithTrack(sound(anchorClipId: 'c1')),
        );
        expect(state.reusesExternalAudio, isFalse);
      },
    );

    test('is false when a bundled divine sound is selected', () {
      final state = VideoEditorProviderState(
        selectedSound: AudioEvent.fromBundledSound(
          VineSound(
            id: 'boom',
            title: 'Vine Boom',
            assetPath: 'assets/sounds/vine-boom.mp3',
            duration: const Duration(seconds: 1),
          ),
        ),
      );
      expect(state.reusesExternalAudio, isFalse);
    });

    test('is false when the added track is self-imported audio', () {
      final state = VideoEditorProviderState(
        editorEditingParameters: paramsWithTrack(
          AudioEvent.fromLocalImport(
            id: 'local_import_1700000000000',
            filePath: '/tmp/beat.mp3',
            createdAt: 1700000000,
            title: 'beat',
            mimeType: 'audio/mpeg',
          ),
        ),
      );
      expect(state.reusesExternalAudio, isFalse);
    });

    test('is false when the added track is a voice-over take', () {
      final state = VideoEditorProviderState(
        editorEditingParameters: paramsWithTrack(
          AudioEvent.fromLocalImport(
            id: 'local_import_voice_over_1700000000000',
            filePath: '/tmp/voice.m4a',
            createdAt: 1700000000,
            title: 'Take 1',
            mimeType: 'audio/mp4',
          ),
        ),
      );
      expect(state.reusesExternalAudio, isFalse);
    });
  });

  group('getActiveDraft audio attribution', () {
    late ProviderContainer container;

    // A reused original sound added through the editor's "add music" flow —
    // credited to the source creator, not the reusing user (#6057).
    final sourceVideoId = 'b' * 64;
    final sourceCreator = 'c' * 64;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );
    });

    tearDown(() {
      container.dispose();
    });

    AudioEvent reusedOriginalSound({String? anchorClipId}) => AudioEvent(
      id: 'video_$sourceVideoId',
      pubkey: sourceCreator,
      createdAt: 1700000000,
      url: 'https://media.divine.video/abc',
      duration: 6,
      sourceVideoReference: '34236:$sourceCreator:vine-xyz',
      anchorClipId: anchorClipId,
    );

    void seedEditorAudioTrack(AudioEvent track) {
      final params = CompleteParameters.fromMap(<String, dynamic>{}).copyWith(
        meta: {
          VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
        },
      );
      container
          .read(videoEditorProvider.notifier)
          .updateEditorEditingParameters(params);
    }

    DivineVideoClip timelineClip({
      String id = 'clip-1',
      String? sourceAuthorPubkey,
      String? sourceEventId,
      String? sourceAddressableId,
      String? sourceRelayHint,
    }) {
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file('/docs/$id.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        sourceAuthorPubkey: sourceAuthorPubkey,
        sourceEventId: sourceEventId,
        sourceAddressableId: sourceAddressableId,
        sourceRelayHint: sourceRelayHint,
      );
    }

    test('credits a reused editor timeline sound in the publish draft', () {
      seedEditorAudioTrack(reusedOriginalSound());

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.selectedSound?.id, equals('video_$sourceVideoId'));
      expect(draft.selectedSound?.pubkey, equals(sourceCreator));
      expect(
        draft.inspiredByVideo?.addressableId,
        equals('34236:$sourceCreator:vine-xyz'),
      );
    });

    test('does not derive editor-track attribution for autosave', () {
      seedEditorAudioTrack(reusedOriginalSound());

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft(isAutosave: true);

      expect(draft.selectedSound, isNull);
    });

    test("skips the video's own clip-anchored original sound", () {
      seedEditorAudioTrack(reusedOriginalSound(anchorClipId: 'clip-1'));

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.selectedSound, isNull);
    });

    test('credits a single reused clip source in the publish draft', () {
      container.read(clipManagerProvider.notifier).replaceClips([
        timelineClip(
          sourceAddressableId: '34236:$sourceCreator:clip-source',
          sourceRelayHint: 'wss://source.relay',
        ),
      ], autosave: false);

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(
        draft.inspiredByVideo?.addressableId,
        equals('34236:$sourceCreator:clip-source'),
      );
      expect(draft.inspiredByVideo?.relayUrl, equals('wss://source.relay'));
    });

    test('keeps sound attribution ahead of reused clip attribution', () {
      container.read(clipManagerProvider.notifier).replaceClips([
        timelineClip(
          sourceAddressableId: '34236:${'d' * 64}:clip-source',
          sourceRelayHint: 'wss://clip.relay',
        ),
      ], autosave: false);
      container
          .read(videoEditorProvider.notifier)
          .selectSound(reusedOriginalSound());

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(
        draft.inspiredByVideo?.addressableId,
        equals('34236:$sourceCreator:vine-xyz'),
      );
      expect(draft.inspiredByVideo?.relayUrl, isNull);
    });

    test('credits one reused clip source mixed with local clips', () {
      container.read(clipManagerProvider.notifier).replaceClips([
        timelineClip(id: 'local-clip'),
        timelineClip(
          id: 'reused-clip',
          sourceAddressableId: '34236:$sourceCreator:clip-source',
          sourceRelayHint: 'wss://source.relay',
        ),
      ], autosave: false);

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(
        draft.inspiredByVideo?.addressableId,
        equals('34236:$sourceCreator:clip-source'),
      );
    });

    test('keeps all clip-source credits when reused sources disagree', () {
      container.read(clipManagerProvider.notifier).replaceClips([
        timelineClip(
          id: 'source-a',
          sourceAuthorPubkey: 'd' * 64,
          sourceAddressableId: '34236:${'d' * 64}:source-a',
          sourceRelayHint: 'wss://source-a.relay',
        ),
        timelineClip(
          id: 'source-b',
          sourceAuthorPubkey: 'e' * 64,
          sourceAddressableId: '34236:${'e' * 64}:source-b',
          sourceRelayHint: 'wss://source-b.relay',
        ),
      ], autosave: false);

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.inspiredByVideo, isNull);
      expect(
        draft.clipSourceCredits.map((credit) => credit.addressableId),
        equals([
          '34236:${'d' * 64}:source-a',
          '34236:${'e' * 64}:source-b',
        ]),
      );
    });

    test('credits author-only reused clip provenance', () {
      container.read(clipManagerProvider.notifier).replaceClips([
        timelineClip(
          id: 'author-only',
          sourceAuthorPubkey: sourceCreator,
          sourceEventId: sourceVideoId,
          sourceRelayHint: 'wss://source.relay',
        ),
      ], autosave: false);

      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.inspiredByVideo, isNull);
      expect(draft.clipSourceCredits, hasLength(1));
      expect(draft.clipSourceCredits.single.authorPubkey, sourceCreator);
      expect(draft.clipSourceCredits.single.eventId, sourceVideoId);
      expect(draft.clipSourceCredits.single.relayUrl, 'wss://source.relay');
    });
  });

  group('updateEditorEditingParameters audio-only changes', () {
    late ProviderContainer container;
    final sourceVideoId = 'b' * 64;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    CompleteParameters paramsWithTracks(List<AudioEvent> tracks) =>
        CompleteParameters.fromMap(<String, dynamic>{}).copyWith(
          meta: {
            VideoEditorConstants.audioStateHistoryKey: tracks
                .map((t) => t.toJson())
                .toList(),
          },
        );

    AudioEvent reusedSound() => AudioEvent(
      id: 'video_$sourceVideoId',
      pubkey: 'c' * 64,
      createdAt: 1700000000,
    );

    test(
      'refreshes the snapshot when only the audio meta changes so the reuse '
      "toggle tracks add/remove of another creator's sound",
      () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateEditorEditingParameters(
          paramsWithTracks([reusedSound()]),
        );
        expect(
          container.read(videoEditorProvider).reusesExternalAudio,
          isTrue,
          reason: 'adding a reused sound must update the snapshot',
        );

        // Remove the sound. The only change is the audio meta — every render
        // field CompleteParameters.diff compares (empty audioTracks field
        // included) is identical, so without the audio-meta check the update
        // is skipped and the snapshot stays stale.
        notifier.updateEditorEditingParameters(paramsWithTracks(const []));
        expect(
          container.read(videoEditorProvider).reusesExternalAudio,
          isFalse,
          reason:
              'removing the reused sound must refresh the snapshot even though '
              'diff() sees no change in the render-time audioTracks field',
        );
      },
    );
  });

  group('cover thumbnail persistence', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('getActiveDraft sources thumbnailTimestamp from the persisted '
        'cover position when finalRenderedClip is absent', () {
      final notifier = container.read(videoEditorProvider.notifier);

      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      // The cover lives only on state, mirroring the window after invalidation
      // clears finalRenderedClip but before a re-render.
      notifier.state = notifier.state.copyWith(
        thumbnailTimestamp: const Duration(milliseconds: 1200),
        customThumbnailPath: '/docs/cover.jpg',
      );

      final draft = notifier.getActiveDraft();

      expect(
        draft.thumbnailTimestamp,
        const Duration(milliseconds: 1200),
        reason:
            'the published cover is derived from draft.thumbnailTimestamp, so '
            'it must reflect the selected position even without a rendered clip',
      );
      expect(
        draft.customThumbnailPath,
        '/docs/cover.jpg',
        reason:
            'the durable cover path must persist so the drafts list keeps '
            'showing the selected cover after finalRenderedClip is cleared',
      );
    });
  });

  group('saveAsDraft', () {
    late _MockDraftStorageService mockDraftStorage;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(
        DivineVideoDraft.create(
          id: 'fallback',
          clips: const [],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockDraftStorage = _MockDraftStorageService();
      when(
        () => mockDraftStorage.draftExists(any()),
      ).thenAnswer((_) async => false);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('returns saved and clears isSavingDraft on success', () async {
      when(() => mockDraftStorage.saveDraft(any())).thenAnswer((_) async {});
      when(() => mockDraftStorage.deleteDraft(any())).thenAnswer((_) async {});

      final result = await container
          .read(videoEditorProvider.notifier)
          .saveAsDraft(enforceCreateNewDraft: true);

      expect(result, equals(DraftSaveOutcome.saved));
      expect(
        container.read(videoEditorProvider).isSavingDraft,
        isFalse,
        reason: 'a successful save must re-enable the save button',
      );
    });

    test('clears isSavingDraft and returns timedOut when the write hangs', () {
      // Reproduces the dead "Save for later" button: a draft write that never
      // resolves must not leave isSavingDraft stuck true for the session.
      when(
        () => mockDraftStorage.saveDraft(any()),
      ).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        final notifier = container.read(videoEditorProvider.notifier);
        DraftSaveOutcome? result;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => result = value);

        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isTrue,
          reason: 'the button is disabled while a save is in flight',
        );

        async.elapse(
          VideoEditorConstants.draftSaveTimeout + const Duration(seconds: 1),
        );

        expect(
          result,
          equals(DraftSaveOutcome.timedOut),
          reason: 'a timed-out save reports failure',
        );
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isFalse,
          reason: 'a timed-out save must re-enable the save button',
        );
      });
    });

    test('returns failed and clears isSavingDraft when the write throws', () {
      // The cause of an unexpected write failure must surface (logged +
      // reported) instead of hiding behind a generic snackbar. Use a
      // SqliteException — the shape a real DB-lock / disk-full write actually
      // throws up from the Drift DAO — so the test exercises the production
      // failure mode rather than a StateError the cause will rarely be.
      when(() => mockDraftStorage.saveDraft(any())).thenThrow(
        SqliteException(extendedResultCode: 5, message: 'database is locked'),
      );

      fakeAsync((async) {
        final notifier = container.read(videoEditorProvider.notifier);
        DraftSaveOutcome? result;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => result = value);
        async.flushMicrotasks();

        expect(result, equals(DraftSaveOutcome.failed));
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isFalse,
          reason: 'a failed save must re-enable the save button',
        );
      });
    });

    test(
      'returns alreadyInProgress while a previous save is still in flight',
      () {
        when(
          () => mockDraftStorage.saveDraft(any()),
        ).thenAnswer((_) => Completer<void>().future);

        fakeAsync((async) {
          final notifier = container.read(videoEditorProvider.notifier);
          unawaited(notifier.saveAsDraft(enforceCreateNewDraft: true));
          async.flushMicrotasks();

          DraftSaveOutcome? secondResult;
          notifier
              .saveAsDraft(enforceCreateNewDraft: true)
              .then((value) => secondResult = value);
          async.flushMicrotasks();

          expect(
            secondResult,
            equals(DraftSaveOutcome.alreadyInProgress),
            reason: 'concurrent saves are rejected by the in-flight guard',
          );
        });
      },
    );

    test('does not abandon autosave cleanup after a successful draft save', () {
      // The autosave delete must run to completion: an abandoned delete could
      // later wipe a new session's recovery point. So a stalled cleanup keeps
      // isSavingDraft true and the save unresolved rather than being dropped.
      when(() => mockDraftStorage.saveDraft(any())).thenAnswer((_) async {});
      when(
        () => mockDraftStorage.draftExists(VideoEditorConstants.autoSaveId),
      ).thenAnswer((_) async => true);

      fakeAsync((async) {
        // Create the completer inside the fake zone so completing it later is
        // driven by `async.flushMicrotasks()` rather than the root zone.
        final cleanup = Completer<void>();
        when(
          () => mockDraftStorage.deleteDraft(any()),
        ).thenAnswer((_) => cleanup.future);

        final notifier = container.read(videoEditorProvider.notifier);
        DraftSaveOutcome? result;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => result = value);

        // Let the write resolve so we are parked on the pending cleanup.
        async.flushMicrotasks();
        // Time passing must not abandon the cleanup.
        async.elapse(
          VideoEditorConstants.draftSaveTimeout + const Duration(seconds: 5),
        );

        expect(
          result,
          isNull,
          reason: 'the save stays in flight while the cleanup is pending',
        );
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isTrue,
          reason: 'the autosave cleanup is not abandoned on a timeout',
        );

        cleanup.complete();
        async.flushMicrotasks();

        expect(result, equals(DraftSaveOutcome.saved));
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isFalse,
          reason: 'the save resolves once the cleanup lands',
        );
      });
    });
  });

  group('flushPendingAutosave', () {
    late _MockDraftStorageService mockDraftStorage;
    late AppDatabase database;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(
        DivineVideoDraft.create(
          id: 'fallback',
          clips: const [],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockDraftStorage = _MockDraftStorageService();
      database = AppDatabase.test(NativeDatabase.memory());
      when(
        () => mockDraftStorage.draftExists(any()),
      ).thenAnswer((_) async => false);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
          databaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    void stubSuccessfulAutosave() {
      when(
        () => mockDraftStorage.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      ).thenAnswer((_) async {});
    }

    test('returns false without writing when no autosave is pending', () async {
      final result = await container
          .read(videoEditorProvider.notifier)
          .flushPendingAutosave();

      expect(result, isFalse);
      verifyNever(
        () => mockDraftStorage.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      );
    });

    test('persists pending autosave and prevents timer re-fire', () {
      stubSuccessfulAutosave();

      fakeAsync((async) {
        final notifier = container.read(videoEditorProvider.notifier);
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              limitClipDuration: false,
              video: EditorVideo.file('/path/to/video.mp4'),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 6),
            );
        notifier.updateMetadata(title: 'Almost lost');

        bool? result;
        notifier.flushPendingAutosave().then((value) => result = value);
        async.flushMicrotasks();

        expect(result, isTrue);
        final captured =
            verify(
                  () => mockDraftStorage.saveDraft(
                    captureAny(),
                    deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
                  ),
                ).captured.single
                as DivineVideoDraft;
        expect(captured.title, 'Almost lost');

        async.elapse(const Duration(milliseconds: 801));
        async.flushMicrotasks();

        verifyNoMoreInteractions(mockDraftStorage);
      });
    });

    test('deletes autosave instead of persisting a zero-clip draft', () async {
      when(
        () => mockDraftStorage.draftExists(VideoEditorConstants.autoSaveId),
      ).thenAnswer((_) async => true);
      when(
        () => mockDraftStorage.deleteDraft(VideoEditorConstants.autoSaveId),
      ).thenAnswer((_) async {});

      final result = await container
          .read(videoEditorProvider.notifier)
          .autosaveChanges();

      expect(result, isFalse);
      verify(
        () => mockDraftStorage.deleteDraft(VideoEditorConstants.autoSaveId),
      ).called(1);
      verifyNever(
        () => mockDraftStorage.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      );
    });

    test(
      'removeAutosavedDraft is a no-op when autosave is already gone',
      () async {
        await container
            .read(videoEditorProvider.notifier)
            .removeAutosavedDraft();

        verify(
          () => mockDraftStorage.draftExists(VideoEditorConstants.autoSaveId),
        ).called(1);
        verifyNever(() => mockDraftStorage.deleteDraft(any()));
      },
    );
  });

  group('VideoEditorProvider deferred file cleanup', () {
    late _MockDraftStorageService mockDraftStorage;
    late AppDatabase database;
    late ProviderContainer container;
    late Directory tempDir;
    var containerDisposed = false;

    void disposeContainer() {
      if (containerDisposed) return;
      containerDisposed = true;
      container.dispose();
    }

    setUpAll(() {
      registerFallbackValue(
        DivineVideoDraft.create(
          id: 'fallback',
          clips: const [],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockDraftStorage = _MockDraftStorageService();
      database = AppDatabase.test(NativeDatabase.memory());
      tempDir = Directory.systemTemp.createTempSync('editor_defer_test');
      containerDisposed = false;
      when(
        () => mockDraftStorage.draftExists(any()),
      ).thenAnswer((_) async => false);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
          databaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() async {
      if (!containerDisposed) {
        final notifier = container.read(videoEditorProvider.notifier);
        disposeContainer();
        await notifier.pendingDeferredCleanupForTest;
      }
      await database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // Stubs the next autosave to hand [orphan] to the deferral sink instead of
    // deleting it — the editor's undo history may still need it — and returns
    // the file it created on disk.
    File stubDeferringAutosave() {
      final orphan = File(p.join(tempDir.path, 'orphan.mp4'))
        ..writeAsBytesSync(const [0, 1, 2, 3]);
      when(
        () => mockDraftStorage.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      ).thenAnswer((invocation) async {
        final defer =
            invocation.namedArguments[#deferOrphanCleanup]
                as void Function(List<String?>)?;
        defer?.call([orphan.path]);
      });
      return orphan;
    }

    void addTimelineClip() {
      final source = File(p.join(tempDir.path, 'source.mp4'))
        ..writeAsBytesSync(const [0, 1, 2, 3]);
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file(source.path),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 6),
          );
    }

    test('an autosave keeps its orphaned files alive', () async {
      final orphan = stubDeferringAutosave();
      addTimelineClip();
      final notifier = container.read(videoEditorProvider.notifier);

      expect(await notifier.autosaveChanges(), isTrue);

      expect(
        orphan.existsSync(),
        isTrue,
        reason:
            'a deferred orphan must survive the autosave so undo/redo can '
            'still resolve the clip it backs',
      );
      expect(notifier.deferredFileCleanupForTest, contains(orphan.path));
    });

    test('reset reaps deferred files at editor-session end', () async {
      final orphan = stubDeferringAutosave();
      addTimelineClip();
      final notifier = container.read(videoEditorProvider.notifier);
      expect(await notifier.autosaveChanges(), isTrue);
      expect(notifier.deferredFileCleanupForTest, contains(orphan.path));

      await notifier.reset(keepAutosavedDraft: true);
      await notifier.pendingDeferredCleanupForTest;

      expect(
        orphan.existsSync(),
        isFalse,
        reason: 'session end reaps a deferred file once nothing references it',
      );
      expect(notifier.deferredFileCleanupForTest, isEmpty);
    });

    test('reset cleanup remains awaitable during container teardown', () async {
      final orphan = stubDeferringAutosave();
      addTimelineClip();
      final notifier = container.read(videoEditorProvider.notifier);
      expect(await notifier.autosaveChanges(), isTrue);
      expect(notifier.deferredFileCleanupForTest, contains(orphan.path));

      await notifier.reset(keepAutosavedDraft: true);
      disposeContainer();
      await notifier.pendingDeferredCleanupForTest;

      expect(
        orphan.existsSync(),
        isFalse,
        reason: 'onDispose must not hide cleanup that reset already started',
      );
    });

    test('container teardown reaps deferred files as a safety net', () async {
      final orphan = stubDeferringAutosave();
      addTimelineClip();
      final notifier = container.read(videoEditorProvider.notifier);
      expect(await notifier.autosaveChanges(), isTrue);
      expect(notifier.deferredFileCleanupForTest, contains(orphan.path));
      expect(orphan.existsSync(), isTrue);

      disposeContainer();
      await notifier.pendingDeferredCleanupForTest;

      expect(
        orphan.existsSync(),
        isFalse,
        reason: 'onDispose reaps deferred files left when reset never ran',
      );
    });

    test('container teardown reaps a replaced final rendered file', () async {
      // Point the documents dir at this group's unique per-test temp dir
      // instead of the shared global `/tmp/documents`: the draft_storage suite
      // recursively wipes that path, and races these files away when
      // `flutter test` runs the suites concurrently.
      final documentsDir = tempDir;
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documentsDir.path);
      addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

      final source = File(p.join(documentsDir.path, 'source.mp4'))
        ..writeAsBytesSync(const [1, 2, 3]);
      final oldRendered = File(
        p.join(documentsDir.path, 'old-rendered.mp4'),
      )..writeAsBytesSync(const [4, 5, 6]);
      final newRendered = File(
        p.join(documentsDir.path, 'new-rendered.mp4'),
      )..writeAsBytesSync(const [7, 8, 9]);
      final realDraftStorage = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );

      DivineVideoClip timelineClip() => DivineVideoClip(
        id: 'timeline',
        video: EditorVideo.file(source.path),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2025),
        targetAspectRatio: AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      DivineVideoClip renderedClip(String id, File file) => DivineVideoClip(
        id: id,
        video: EditorVideo.file(file.path),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2025),
        targetAspectRatio: AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      await realDraftStorage.saveDraft(
        DivineVideoDraft.create(
          id: VideoEditorConstants.autoSaveId,
          clips: [timelineClip()],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
          finalRenderedClip: renderedClip('old-rendered', oldRendered),
        ),
      );

      when(
        () => mockDraftStorage.saveDraft(
          any(),
          deferOrphanCleanup: any(named: 'deferOrphanCleanup'),
        ),
      ).thenAnswer((invocation) async {
        await realDraftStorage.saveDraft(
          invocation.positionalArguments.first as DivineVideoDraft,
          deferOrphanCleanup:
              invocation.namedArguments[#deferOrphanCleanup]
                  as void Function(List<String?>)?,
        );
      });

      final notifier = container.read(videoEditorProvider.notifier);
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file(source.path),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 6),
          );
      notifier.state = notifier.state.copyWith(
        finalRenderedClip: renderedClip('new-rendered', newRendered),
      );

      expect(await notifier.autosaveChanges(), isTrue);
      expect(oldRendered.existsSync(), isTrue);
      expect(notifier.deferredFileCleanupForTest, contains(oldRendered.path));

      disposeContainer();
      await notifier.pendingDeferredCleanupForTest;

      expect(
        oldRendered.existsSync(),
        isFalse,
        reason:
            'onDispose must reap a replaced rendered export once the new '
            'draft row no longer references it',
      );
      expect(newRendered.existsSync(), isTrue);
    });
  });
}
