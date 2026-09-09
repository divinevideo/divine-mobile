// ABOUTME: Tests for VideoEditorMergeService - flattening selected clips into
// ABOUTME: a single rendered clip via the concat render pipeline.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio, ClipSourceCredit;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_merge_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createClip({
  required String id,
  Duration duration = const Duration(seconds: 2),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  );
}

void main() {
  group(VideoEditorMergeService, () {
    tearDown(() {
      VideoEditorRenderService.renderVideoOverride = null;
    });

    test('returns null when fewer than two clips are supplied', () async {
      var called = false;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            called = true;
            return '/out.mp4';
          };

      final result = await VideoEditorMergeService.mergeClips(
        clips: [_createClip(id: 'a')],
        renderId: 'merge-1',
      );

      expect(result, isNull);
      expect(called, isFalse, reason: 'render should not run for one clip');
    });

    test(
      'forwards clips + taskId and returns merged clip on success',
      () async {
        List<DivineVideoClip>? forwardedClips;
        String? forwardedTaskId;
        bool? forwardedPersistent;
        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
              maxOutputDuration,
            }) async {
              forwardedClips = clips;
              forwardedTaskId = taskId;
              forwardedPersistent = usePersistentStorage;
              return '/documents/merged.mp4';
            };

        final clips = [
          _createClip(id: 'a'),
          _createClip(id: 'b', duration: const Duration(seconds: 3)),
        ];

        final result = await VideoEditorMergeService.mergeClips(
          clips: clips,
          renderId: 'merge-1',
        );

        expect(forwardedClips, same(clips));
        expect(forwardedTaskId, equals('merge-1'));
        expect(forwardedPersistent, isTrue);
        expect(result, isNotNull);
        expect(
          result!.requireVideo.file?.path,
          equals('/documents/merged.mp4'),
        );
        expect(result.duration, equals(const Duration(seconds: 5)));
        expect(result.trimStart, equals(Duration.zero));
        expect(result.trimEnd, equals(Duration.zero));
        expect(result.targetAspectRatio, equals(model.AspectRatio.vertical));
      },
    );

    test('keeps the full merged duration uncapped (no export limit)', () async {
      var capWasSet = true;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            capWasSet = maxOutputDuration != null;
            return '/documents/merged.mp4';
          };

      // 5s + 5s = 10s, well beyond the ~6.3s final-export cap, which must not
      // truncate an intermediate merged clip.
      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(id: 'a', duration: const Duration(seconds: 5)),
          _createClip(id: 'b', duration: const Duration(seconds: 5)),
        ],
        renderId: 'merge-1',
      );

      expect(result!.duration, equals(const Duration(seconds: 10)));
      expect(
        capWasSet,
        isFalse,
        reason:
            'the render must be uncapped, or the file is truncated at '
            'the export limit even though the clip claims the full duration',
      );
    });

    test('accounts for playback speed when summing duration', () async {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => '/documents/merged.mp4';

      // 4s at 2x = 2s playback; 2s at 1x = 2s → 4s total.
      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(
            id: 'a',
            duration: const Duration(seconds: 4),
            playbackSpeed: 2,
          ),
          _createClip(id: 'b'),
        ],
        renderId: 'merge-1',
      );

      expect(result!.duration, equals(const Duration(seconds: 4)));
    });

    test('returns null when the render fails or is cancelled', () async {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => null;

      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(id: 'a'),
          _createClip(id: 'b'),
        ],
        renderId: 'merge-1',
      );

      expect(result, isNull);
    });

    test(
      'preserves provenance when every clip shares the same source',
      () async {
        VideoEditorRenderService.renderVideoOverride = ({
          required clips,
          required usePersistentStorage,
          aspectRatio,
          parameters,
          taskId,
          maxOutputDuration,
        }) async => '/documents/merged.mp4';

        DivineVideoClip sameSourceClip(String id) =>
            _createClip(id: id).copyWith(
              sourceCredits: const [
                model.ClipSourceCredit(
                  authorPubkey: 'source-author-pubkey',
                  eventId: 'source-event-id',
                  addressableId: '34236:source-author-pubkey:source-d-tag',
                  relayUrl: 'wss://relay.divine.video',
                ),
              ],
            );

        final result = await VideoEditorMergeService.mergeClips(
          clips: [sameSourceClip('a'), sameSourceClip('b')],
          renderId: 'merge-1',
        );

        expect(result!.sourceAuthorPubkey, equals('source-author-pubkey'));
        expect(result.sourceEventId, equals('source-event-id'));
        expect(
          result.sourceAddressableId,
          equals('34236:source-author-pubkey:source-d-tag'),
        );
        expect(result.sourceRelayHint, equals('wss://relay.divine.video'));
      },
    );

    test(
      'preserves provenance union when clips come from different sources',
      () async {
        VideoEditorRenderService.renderVideoOverride = ({
          required clips,
          required usePersistentStorage,
          aspectRatio,
          parameters,
          taskId,
          maxOutputDuration,
        }) async => '/documents/merged.mp4';

        final result = await VideoEditorMergeService.mergeClips(
          clips: [
            _createClip(id: 'a').copyWith(
              sourceCredits: const [
                model.ClipSourceCredit(
                  authorPubkey: 'author-a',
                  eventId: 'event-a',
                  relayUrl: 'wss://relay-a',
                ),
              ],
            ),
            _createClip(id: 'b').copyWith(
              sourceCredits: const [
                model.ClipSourceCredit(
                  authorPubkey: 'author-b',
                  eventId: 'event-b',
                  relayUrl: 'wss://relay-b',
                ),
              ],
            ),
          ],
          renderId: 'merge-1',
        );

        expect(result!.sourceCredits, hasLength(2));
        expect(result.sourceCredits[0].authorPubkey, 'author-a');
        expect(result.sourceCredits[0].eventId, 'event-a');
        expect(result.sourceCredits[0].relayUrl, 'wss://relay-a');
        expect(result.sourceCredits[1].authorPubkey, 'author-b');
        expect(result.sourceCredits[1].eventId, 'event-b');
        expect(result.sourceCredits[1].relayUrl, 'wss://relay-b');
        expect(result.sourceAuthorPubkey, 'author-a');
        expect(result.sourceEventId, 'event-a');
      },
    );
  });
}
