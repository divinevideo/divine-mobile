// ABOUTME: Tests for the split-screen layout cubit: filling cells, switching
// ABOUTME: layouts, framing a cell, and the render that turns it into a clip

import 'dart:async';
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/services/video_editor/split_screen_layout_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _red = Color(0xFFFF0000);

DivineVideoClip _clip(String id, {int seconds = 2}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: Duration(seconds: seconds),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

/// A take recorded in chroma key mode whose key is not baked in yet.
DivineVideoClip _recordedWithKey(String id) =>
    _clip(id).copyWith(captureChromaKey: const ClipChromaKey(key: ChromaKey()));

/// Stands in for the renderer, recording what it was asked to render.
class _FakeRender {
  final List<({List<SplitScreenRenderCell> cells, Color background})> calls =
      [];
  final List<String?> cleanedUp = [];
  bool fail = false;

  SplitScreenLayoutCubit cubit({SplitScreenBakeChromaKeyFn? bake}) =>
      SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: _red,
        bakeCapturedChromaKey: bake,
        renderLayout:
            ({
              required cells,
              required aspectRatio,
              required backgroundColor,
              required taskId,
            }) async {
              calls.add((cells: cells, background: backgroundColor));
              return fail ? null : _clip('layout', seconds: 3);
            },
        deferFileCleanup: cleanedUp.addAll,
      );
}

void main() {
  group(SplitScreenLayoutCubit, () {
    late _FakeRender renders;

    setUp(() => renders = _FakeRender());

    group('clipsPicked', () {
      test('fills the selected cell, then the empty ones after it', () {
        final cubit = renders.cubit()
          ..presetSelected(SplitScreenLayoutPreset.grid)
          ..clipsPicked([_clip('first')])
          ..cellSelected(2);

        final leftOver = cubit.clipsPicked([
          _clip('a'),
          _clip('b'),
          _clip('c'),
        ]);

        expect(
          cubit.state.cells.map((cell) => cell?.clip.id),
          ['first', 'c', 'a', 'b'],
        );
        expect(leftOver, 0);
        addTearDown(cubit.close);
      });

      test('keeps what the layout has no cell for for a bigger one', () {
        final cubit = renders.cubit();

        final leftOver = cubit.clipsPicked([
          _clip('a'),
          _clip('b'),
          _clip('c'),
        ]);

        expect(cubit.state.activeCells.map((cell) => cell?.clip.id), [
          'a',
          'b',
        ]);
        expect(leftOver, 0);

        cubit.presetSelected(SplitScreenLayoutPreset.threeColumns);

        expect(cubit.state.activeCells.map((cell) => cell?.clip.id), [
          'a',
          'b',
          'c',
        ]);
        addTearDown(cubit.close);
      });

      test('reports the clips not even the biggest layout has room for', () {
        final cubit = renders.cubit();

        final leftOver = cubit.clipsPicked([
          for (final id in ['a', 'b', 'c', 'd', 'e']) _clip(id),
        ]);

        expect(leftOver, 1);
        addTearDown(cubit.close);
      });

      test('moves the selection on to the next empty cell', () {
        final cubit = renders.cubit()
          ..presetSelected(SplitScreenLayoutPreset.threeStacked);

        cubit.clipsPicked([_clip('a')]);

        expect(cubit.state.selectedCellIndex, 1);
        addTearDown(cubit.close);
      });
    });

    group('presetSelected', () {
      test('keeps clips a smaller layout hides for when it grows again', () {
        final cubit = renders.cubit()
          ..presetSelected(SplitScreenLayoutPreset.grid)
          ..clipsPicked([_clip('a'), _clip('b'), _clip('c'), _clip('d')])
          ..cellSelected(3)
          ..presetSelected(SplitScreenLayoutPreset.sideBySide);

        expect(cubit.state.activeCells, hasLength(2));
        expect(cubit.state.selectedCellIndex, 1);

        cubit.presetSelected(SplitScreenLayoutPreset.grid);

        expect(cubit.state.activeCells.map((cell) => cell?.clip.id), [
          'a',
          'b',
          'c',
          'd',
        ]);
        addTearDown(cubit.close);
      });
    });

    group('pickableClipCount', () {
      test('counts the selected cell and every other empty one', () {
        final cubit = renders.cubit()
          ..presetSelected(SplitScreenLayoutPreset.grid)
          ..clipsPicked([_clip('a')])
          ..cellSelected(0);

        expect(cubit.state.pickableClipCount, 4);

        cubit.cellSelected(2);

        expect(cubit.state.pickableClipCount, 3);
        addTearDown(cubit.close);
      });

      test('counts the cells only a bigger layout shows', () {
        final cubit = renders.cubit();

        expect(cubit.state.pickableClipCount, cubit.state.cells.length);
        addTearDown(cubit.close);
      });

      test('keeps a cell for every cell of the biggest layout', () {
        final cubit = renders.cubit();

        for (final preset in SplitScreenLayoutPreset.values) {
          expect(
            preset.cellCount,
            lessThanOrEqualTo(cubit.state.cells.length),
            reason: preset.name,
          );
        }
        addTearDown(cubit.close);
      });
    });

    group('cellReframed', () {
      test('zooms into the footage of a filled cell', () {
        final cubit = renders.cubit()..clipsPicked([_clip('a')]);

        cubit.cellReframed(
          0,
          focalPoint: const Offset(45, 0),
          delta: Offset.zero,
          zoom: 2,
          cellSize: const Size(90, 320),
        );

        final cell = cubit.state.cells.first!;
        expect(cell.zoom, 2);
        // Pinched at the top edge, so the top of the footage stays put.
        expect(cell.alignment.y, -1);
        addTearDown(cubit.close);
      });

      test('leaves an empty cell alone', () {
        final cubit = renders.cubit();

        cubit.cellReframed(
          1,
          focalPoint: Offset.zero,
          delta: const Offset(10, 10),
          zoom: 2,
          cellSize: const Size(90, 320),
        );

        expect(cubit.state.cells[1], isNull);
        addTearDown(cubit.close);
      });
    });

    group('apply', () {
      test('renders every filled cell, framed, into one clip', () async {
        final cubit = renders.cubit()
          ..clipsPicked([_clip('a', seconds: 3), _clip('b')])
          ..cellReframed(
            0,
            focalPoint: const Offset(45, 160),
            delta: Offset.zero,
            zoom: 2,
            cellSize: const Size(90, 320),
          );

        await cubit.apply();

        final call = renders.calls.single;
        expect(call.background, _red);
        expect(call.cells.map((cell) => cell.clip.id), ['a', 'b']);
        expect(call.cells.map((cell) => cell.rect), cubit.state.cellRects);
        expect(call.cells.map((cell) => cell.zoom), [2, 1]);
        expect(cubit.state.status, SplitScreenLayoutStatus.applied);
        expect(cubit.state.result?.id, 'layout');
        addTearDown(cubit.close);
      });

      test('keeps the layout as it was when the render fails', () async {
        renders.fail = true;
        final cubit = renders.cubit()..clipsPicked([_clip('a')]);

        await cubit.apply();

        expect(cubit.state.status, SplitScreenLayoutStatus.failure);
        expect(cubit.state.result, isNull);
        expect(cubit.state.cells.first?.clip.id, 'a');
        expect(cubit.state.cells.first?.alignment, Alignment.center);
        expect(cubit.state.canApply, isTrue);
        addTearDown(cubit.close);
      });

      test('blocks the layout while a recorded key is being baked', () async {
        final baked = Completer<DivineVideoClip>();
        final cubit = renders.cubit(bake: (_) => baked.future)
          ..clipsPicked([_recordedWithKey('a')]);
        addTearDown(cubit.close);

        final applying = cubit.apply();

        expect(cubit.state.status, SplitScreenLayoutStatus.applying);
        expect(cubit.state.canApply, isFalse);
        cubit.presetSelected(SplitScreenLayoutPreset.grid);
        expect(cubit.state.preset, SplitScreenLayoutPreset.sideBySide);

        baked.complete(_clip('a_keyed'));
        await applying;

        expect(
          renders.calls.single.cells.single.clip.video?.file?.path,
          '/documents/a_keyed.mp4',
        );
        expect(cubit.state.status, SplitScreenLayoutStatus.applied);
      });

      test('reports a failure ahead of the render on every try', () async {
        final cubit = renders.cubit(
          bake: (_) async => throw Exception('backdrop is gone'),
        )..clipsPicked([_recordedWithKey('a')]);
        addTearDown(cubit.close);
        final statuses = <SplitScreenLayoutStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);

        await cubit.apply();
        await cubit.apply();
        await pumpEventQueue();

        expect(statuses, const [
          SplitScreenLayoutStatus.applying,
          SplitScreenLayoutStatus.failure,
          SplitScreenLayoutStatus.applying,
          SplitScreenLayoutStatus.failure,
        ]);
        expect(renders.calls, isEmpty);
      });

      test('bakes and renders nothing once it is closed', () async {
        final baked = <String>[];
        final cubit = renders.cubit(
          bake: (clip) async {
            baked.add(clip.id);
            return clip;
          },
        )..clipsPicked([_recordedWithKey('a')]);
        expect(cubit.state.canApply, isTrue);
        await cubit.close();

        await cubit.apply();

        expect(baked, isEmpty);
        expect(renders.calls, isEmpty);
      });
    });
  });
}
