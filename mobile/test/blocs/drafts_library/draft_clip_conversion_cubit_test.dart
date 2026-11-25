import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/blocs/drafts_library/draft_clip_conversion_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _draftId = 'saved-draft';

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime.utc(2026),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: AspectRatio.vertical,
);

DivineVideoDraft _draft({List<DivineVideoClip>? clips}) => DivineVideoDraft(
  id: _draftId,
  clips: clips ?? [_clip('source')],
  title: 'Trip',
  description: '',
  hashtags: const {},
  selectedApproach: 'default',
  createdAt: DateTime.utc(2026),
  lastModified: DateTime.utc(2026),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
);

void main() {
  group(DraftClipConversionCubit, () {
    late DivineVideoDraft? stored;
    late Future<DivineVideoClip> Function(DivineVideoDraft) render;
    late Future<void> Function(DivineVideoClip) save;
    late List<DivineVideoClip> saved;
    late List<(DivineVideoClip, DivineVideoDraft)> discarded;
    late DraftClipConversions conversions;
    final rendered = _clip('clip_library_1');

    setUp(() {
      conversions = DraftClipConversions();
      stored = _draft();
      render = (_) async => rendered;
      saved = [];
      save = (clip) async => saved.add(clip);
      discarded = [];
    });

    DraftClipConversionCubit build() => DraftClipConversionCubit(
      conversions: conversions,
      loadDraft: (_) async => stored,
      renderDraft: (draft) => render(draft),
      saveClip: (clip) => save(clip),
      discardClip: (clip, draft) async => discarded.add((clip, draft)),
    );

    group('convert', () {
      blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
        'saves the rendered draft as a library clip',
        build: build,
        act: (cubit) => cubit.convert(_draftId),
        expect: () => const [
          DraftClipConversionStatus.converting,
          DraftClipConversionStatus.converted,
        ],
        verify: (_) {
          expect(saved, [rendered]);
          expect(discarded, isEmpty);
        },
      );

      blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
        'fails without rendering when the draft is gone',
        setUp: () {
          stored = null;
          render = (_) => fail('rendered a draft that no longer exists');
        },
        build: build,
        act: (cubit) => cubit.convert(_draftId),
        expect: () => const [
          DraftClipConversionStatus.converting,
          DraftClipConversionStatus.failed,
        ],
        verify: (_) => expect(saved, isEmpty),
      );

      blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
        'reports overlays that could not be prepared',
        setUp: () =>
            render = (_) async =>
                throw const DraftOverlayRestoreException('no body size'),
        build: build,
        act: (cubit) => cubit.convert(_draftId),
        expect: () => const [
          DraftClipConversionStatus.converting,
          DraftClipConversionStatus.overlaysUnavailable,
        ],
        errors: () => [isA<DraftOverlayRestoreException>()],
        verify: (_) => expect(saved, isEmpty),
      );

      blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
        'reports a device out of storage',
        setUp: () =>
            render = (_) async => throw const VideoRenderFailedException(
              VideoRenderFailureReason.insufficientStorage,
            ),
        build: build,
        act: (cubit) => cubit.convert(_draftId),
        expect: () => const [
          DraftClipConversionStatus.converting,
          DraftClipConversionStatus.lowStorage,
        ],
        errors: () => [isA<VideoRenderFailedException>()],
      );

      blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
        'deletes the rendered clip when the library rejects it',
        setUp: () => save = (_) async => throw Exception('database locked'),
        build: build,
        act: (cubit) => cubit.convert(_draftId),
        expect: () => const [
          DraftClipConversionStatus.converting,
          DraftClipConversionStatus.failed,
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          expect(discarded, hasLength(1));
          expect(discarded.single.$1, rendered);
          expect(discarded.single.$2.id, _draftId);
        },
      );

      group('while one is converting', () {
        late Completer<DivineVideoClip> pending;
        late int renders;

        setUp(() {
          pending = Completer<DivineVideoClip>();
          renders = 0;
          render = (_) {
            renders++;
            return pending.future;
          };
        });

        blocTest<DraftClipConversionCubit, DraftClipConversionStatus>(
          'ignores a second request',
          build: build,
          act: (cubit) async {
            final first = cubit.convert(_draftId);
            await pumpEventQueue();
            await cubit.convert(_draftId);
            pending.complete(rendered);
            await first;
          },
          expect: () => const [
            DraftClipConversionStatus.converting,
            DraftClipConversionStatus.converted,
          ],
          verify: (_) {
            expect(renders, 1);
            expect(saved, [rendered]);
          },
        );

        test(
          'a library reopened mid-render follows the running conversion',
          () async {
            final left = build();
            final started = left.convert(_draftId);
            await pumpEventQueue();
            await left.close();

            final reopened = build();
            addTearDown(reopened.close);
            expect(reopened.state, DraftClipConversionStatus.converting);

            await reopened.convert(_draftId);
            pending.complete(rendered);
            await started;
            await pumpEventQueue();

            expect(reopened.state, DraftClipConversionStatus.converted);
            expect(renders, 1);
            expect(saved, [rendered]);
          },
        );

        test('a library opened afterwards can convert again', () async {
          final first = build();
          addTearDown(first.close);
          final started = first.convert(_draftId);
          await pumpEventQueue();
          pending.complete(rendered);
          await started;

          final later = build();
          addTearDown(later.close);
          expect(later.state, DraftClipConversionStatus.idle);

          render = (_) async {
            renders++;
            return rendered;
          };
          await later.convert(_draftId);

          expect(later.state, DraftClipConversionStatus.converted);
          expect(renders, 2);
        });
      });
    });
  });

  group(DraftClipConversions, () {
    group('run', () {
      test('returns the running outcome instead of starting another', () async {
        final conversions = DraftClipConversions();
        final pending = Completer<DraftClipConversionStatus>();
        var starts = 0;
        Future<DraftClipConversionStatus> conversion() {
          starts++;
          return pending.future;
        }

        final first = conversions.run(conversion);
        final second = conversions.run(conversion);
        expect(conversions.running, isNotNull);
        pending.complete(DraftClipConversionStatus.converted);

        expect(await first, DraftClipConversionStatus.converted);
        expect(await second, DraftClipConversionStatus.converted);
        expect(starts, 1);
        expect(conversions.running, isNull);
      });
    });
  });
}
