// ABOUTME: Tests for TimelineOverlayBloc.
// ABOUTME: Covers update, move, trim, select, drag, trim, collapse,
// ABOUTME: and state helpers for the current event/state API.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

TimelineOverlayItem _item({
  required String id,
  required TimelineOverlayType type,
  required Duration start,
  required Duration end,
  int row = 0,
  String label = '',
}) {
  return TimelineOverlayItem(
    id: id,
    type: type,
    startTime: start,
    endTime: end,
    row: row,
    label: label,
  );
}

AudioEvent _audioEvent({
  required String id,
  required Duration start,
  required Duration end,
  String title = 'Sound',
  String? anchorClipId,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: 1704067200,
    title: title,
    startTime: start,
    endTime: end,
    anchorClipId: anchorClipId,
  );
}

/// A sound whose own duration never resolved, left-trimmed by two seconds.
final AudioEvent _durationlessTrack = _audioEvent(
  id: 'sound-1',
  start: const Duration(seconds: 1),
  end: const Duration(seconds: 4),
).copyWith(startOffset: const Duration(seconds: 2));

TimelineOverlayItemsUpdate _soundUpdate(AudioEvent track) {
  return TimelineOverlayItemsUpdate(
    layers: const <Layer>[],
    filters: const <FilterState>[],
    audioTracks: [track],
    totalVideoDuration: const Duration(seconds: 12),
  );
}

void main() {
  group(TimelineOverlayBloc, () {
    test('initial state is empty', () {
      final bloc = TimelineOverlayBloc();
      addTearDown(bloc.close);

      expect(bloc.state, equals(const TimelineOverlayState()));
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.selectedItemId, isNull);
      expect(bloc.state.draggingItemId, isNull);
      expect(bloc.state.trimmingItemId, isNull);
      expect(bloc.state.collapsedTypes, isEmpty);
      expect(bloc.state.timelineMarkers, isEmpty);
    });

    group(TimelineOverlayItemsUpdate, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maps audio tracks into sound overlay items',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
                title: 'Beat',
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: const [
              TimelineOverlayItem(
                id: 'sound-1',
                type: TimelineOverlayType.sound,
                startTime: Duration(seconds: 1),
                endTime: Duration(seconds: 4),
                label: 'Beat',
                maxDuration: VideoEditorConstants.maxDuration,
                audioSource: AudioSource.custom,
              ),
            ],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
                title: 'Beat',
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'caps a detached clip at its own length and leaves other layers '
        'running to the end',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: [
              TextLayer(id: 'text-1', text: 'Plain text'),
              WidgetLayer(
                id: 'detached-1',
                widget: const SizedBox.shrink(),
                meta: DetachedClipLayerData(
                  layerId: 'detached-1',
                  clip: DivineVideoClip(
                    id: 'clip-1',
                    video: EditorVideo.file('/docs/clip-1.mp4'),
                    duration: const Duration(seconds: 4),
                    recordedAt: DateTime(2026),
                    targetAspectRatio: model.AspectRatio.vertical,
                    originalAspectRatio: 9 / 16,
                  ),
                ).toMeta(),
              ),
            ],
            filters: const <FilterState>[],
            audioTracks: const [],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        verify: (bloc) {
          final detached = bloc.state.items.firstWhere(
            (i) => i.id == 'detached-1',
          );
          final text = bloc.state.items.firstWhere((i) => i.id == 'text-1');

          // The clip has 4 s of footage; a longer bar would promise frames the
          // file does not have, and the export stops drawing it there anyway.
          expect(detached.maxDuration, const Duration(seconds: 4));
          expect(detached.endTime, const Duration(seconds: 4));

          // A drawing can be held for as long as the user likes, so it still
          // runs to the end of the composition and stays unbounded.
          expect(text.maxDuration, isNull);
          expect(text.endTime, const Duration(seconds: 12));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'drives the captions strip from cues and keeps burned layers off '
        'both strips',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: [
              TextLayer(
                id: 'text-1',
                text: 'Plain text',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
              // A burned-in caption layer is a derived render, not a timeline
              // item: excluded from the layer strip and never a caption item.
              TextLayer(
                id: 'caption-layer-1',
                text: 'Burned cue',
                startTime: const Duration(seconds: 3),
                endTime: const Duration(seconds: 4),
                meta: const {
                  VideoEditorConstants.captionCueMetaKey: true,
                  VideoEditorConstants.captionCueIdMetaKey: 'cue-1',
                },
              ),
            ],
            filters: const <FilterState>[],
            audioTracks: const [],
            totalVideoDuration: const Duration(seconds: 6),
            captionTrack: const CaptionTrack(
              burnIn: true,
              presetId: 'classic',
              languageTag: 'en-US',
              cues: [
                CaptionCue(
                  id: 'cue-1',
                  text: 'The cue',
                  start: Duration(seconds: 3),
                  end: Duration(seconds: 4),
                ),
              ],
            ),
          ),
        ),
        verify: (bloc) {
          final items = bloc.state.items;
          final layerItems = items
              .where((i) => i.type == TimelineOverlayType.layer)
              .toList();
          final captionItems = items
              .where((i) => i.type == TimelineOverlayType.captions)
              .toList();

          // The plain text layer stays a layer item; the burned caption layer
          // appears on neither strip.
          expect(layerItems.map((i) => i.id), equals(['text-1']));
          // Caption items come only from the track cues, addressed by cue id.
          expect(captionItems.map((i) => i.id), equals(['cue-1']));
          expect(captionItems.single.layer, isNull);
          expect(captionItems.single.label, equals('The cue'));
          expect(
            captionItems.single.startTime,
            equals(const Duration(seconds: 3)),
          );
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maps non-neutral tune adjustments into tune overlay items',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            tuneAdjustments: [
              TuneAdjustmentMatrix(
                id: 'brightness',
                value: 0.2,
                matrix: const [],
                startTime: const Duration(seconds: 1),
                endTime: const Duration(seconds: 3),
              ),
            ],
            audioTracks: const <AudioEvent>[],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items,
            'items',
            [
              isA<TimelineOverlayItem>()
                  .having((i) => i.id, 'id', 'brightness')
                  .having((i) => i.type, 'type', TimelineOverlayType.tune)
                  .having(
                    (i) => i.startTime,
                    'startTime',
                    const Duration(seconds: 1),
                  )
                  .having(
                    (i) => i.endTime,
                    'endTime',
                    const Duration(seconds: 3),
                  )
                  .having((i) => i.label, 'label', 'Brightness'),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'skips neutral (value 0) tune adjustments',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            tuneAdjustments: [
              TuneAdjustmentMatrix(
                id: 'brightness',
                value: 0,
                matrix: const [],
              ),
              TuneAdjustmentMatrix(
                id: 'contrast',
                value: -0.3,
                matrix: const [],
              ),
            ],
            audioTracks: const <AudioEvent>[],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.map((i) => i.id).toList(),
            'item ids',
            ['contrast'],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'defaults a tune adjustment without a window to full duration',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            tuneAdjustments: [
              TuneAdjustmentMatrix(
                id: 'saturation',
                value: 0.4,
                matrix: const [],
              ),
            ],
            audioTracks: const <AudioEvent>[],
            totalVideoDuration: const Duration(seconds: 8),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => (s.items.first.startTime, s.items.first.endTime),
            'window',
            (Duration.zero, const Duration(seconds: 8)),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'groups adjustments sharing a set id into one bar with joined labels',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            tuneAdjustments: [
              TuneAdjustmentMatrix(
                id: 'brightness__set-1',
                value: 0.2,
                matrix: const [],
                startTime: const Duration(seconds: 1),
                endTime: const Duration(seconds: 3),
                meta: const {
                  VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                  VideoEditorConstants.tuneKindMetaKey: 'brightness',
                },
              ),
              TuneAdjustmentMatrix(
                id: 'contrast__set-1',
                value: -0.1,
                matrix: const [],
                startTime: const Duration(seconds: 1),
                endTime: const Duration(seconds: 3),
                meta: const {
                  VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                  VideoEditorConstants.tuneKindMetaKey: 'contrast',
                },
              ),
            ],
            audioTracks: const <AudioEvent>[],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having((s) => s.items, 'items', [
            isA<TimelineOverlayItem>()
                .having((i) => i.id, 'id (set id)', 'set-1')
                .having((i) => i.type, 'type', TimelineOverlayType.tune)
                .having(
                  (i) => i.startTime,
                  'startTime',
                  const Duration(seconds: 1),
                )
                .having((i) => i.endTime, 'endTime', const Duration(seconds: 3))
                .having((i) => i.label, 'label', 'Brightness, Contrast'),
          ]),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps separate set ids as separate bars',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            tuneAdjustments: [
              TuneAdjustmentMatrix(
                id: 'brightness__set-1',
                value: 0.2,
                matrix: const [],
                meta: const {
                  VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
                  VideoEditorConstants.tuneKindMetaKey: 'brightness',
                },
              ),
              TuneAdjustmentMatrix(
                id: 'brightness__set-2',
                value: -0.2,
                matrix: const [],
                meta: const {
                  VideoEditorConstants.tuneSetIdMetaKey: 'set-2',
                  VideoEditorConstants.tuneKindMetaKey: 'brightness',
                },
              ),
            ],
            audioTracks: const <AudioEvent>[],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.map((i) => i.id).toList(),
            'set ids',
            ['set-1', 'set-2'],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maxDuration equals track duration when longer than VideoEditorConstants.maxDuration',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ).copyWith(
                duration: 10.0,
              ), // 10s > VideoEditorConstants.maxDuration (6.3s)
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.first.maxDuration,
            'maxDuration',
            const Duration(seconds: 10),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maxDuration subtracts startOffset from track duration',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ).copyWith(
                duration: 8.0,
                startOffset: const Duration(seconds: 2),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.first.maxDuration,
            'maxDuration',
            const Duration(seconds: 6), // 8000ms - 2000ms
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'carries full source duration and start offset onto sound items',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ).copyWith(
                duration: 8.0,
                startOffset: const Duration(seconds: 2),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                const Duration(seconds: 8),
              )
              .having(
                (s) => s.items.first.startOffset,
                'startOffset',
                const Duration(seconds: 2),
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'spans the whole video when a sound carries a zero-length window',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            // A sound added before its duration was known persists
            // startTime=0/endTime=0 — an invisible zero-width bar unless the
            // timeline heals it to play across the whole video.
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: Duration.zero,
                end: Duration.zero,
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.startTime,
                'startTime',
                Duration.zero,
              )
              .having(
                (s) => s.items.first.endTime,
                'endTime',
                const Duration(seconds: 12),
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'falls back to maxDuration when an invalid-window sound has no total',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            // total is transiently zero (clips not yet measured during a draft
            // load); the heal must not collapse the bar back to zero width.
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: Duration.zero,
                end: Duration.zero,
              ),
            ],
            totalVideoDuration: Duration.zero,
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.startTime,
                'startTime',
                Duration.zero,
              )
              .having(
                (s) => s.items.first.endTime,
                'endTime',
                VideoEditorConstants.maxDuration,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps markers within reach when total is transiently zero',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: <AudioEvent>[],
            // The shared maxDuration fallback also guards marker clamping, so a
            // transient zero total can't collapse every marker onto 0.
            timelineMarkers: [Duration(seconds: 3)],
            totalVideoDuration: Duration.zero,
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.timelineMarkers,
            'timelineMarkers',
            const [Duration(seconds: 3)],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'spans the whole video when a sound has no endTime',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              // endTime omitted (null): a probe that never resolved leaves the
              // composition window open.
              AudioEvent(
                id: 'sound-1',
                pubkey: 'pubkey-sound-1',
                createdAt: 1704067200,
                title: 'Beat',
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.startTime,
                'startTime',
                Duration.zero,
              )
              .having(
                (s) => s.items.first.endTime,
                'endTime',
                const Duration(seconds: 12),
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'leaves source duration null when the track has no duration',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                isNull,
              )
              .having(
                (s) => s.items.first.startOffset,
                'startOffset',
                Duration.zero,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'treats a zero duration as unknown so a trim cannot collapse the bar',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            // A persisted-but-zero duration must be normalized to "unknown",
            // otherwise sourceDuration becomes zero and maxDuration <= 0, which
            // a trim gesture would use to collapse the now-visible bar.
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: Duration.zero,
                end: Duration.zero,
              ).copyWith(duration: 0),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                isNull,
              )
              .having(
                (s) => s.items.first.maxDuration,
                'maxDuration',
                VideoEditorConstants.maxDuration,
              ),
        ],
      );

      // The waveform extractor reads the whole source, so the duration it
      // measures is the basis the painter maps samples to time against.
      // Without it a duration-less sound draws the entire file squeezed into
      // its visible bar.
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'adopts the measured source duration when the track has none',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc
          ..add(_soundUpdate(_durationlessTrack))
          ..add(
            TimelineOverlayWaveformLoaded(
              itemId: 'sound-1',
              leftChannel: Float32List(4),
              sourceDuration: const Duration(seconds: 30),
            ),
          ),
        skip: 1,
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                const Duration(seconds: 30),
              )
              .having(
                (s) => s.items.first.maxDuration,
                'maxDuration',
                const Duration(seconds: 28), // 30s source - 2s offset
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps the measured basis when the item is rebuilt',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc
          ..add(_soundUpdate(_durationlessTrack))
          ..add(
            TimelineOverlayWaveformLoaded(
              itemId: 'sound-1',
              leftChannel: Float32List(4),
              sourceDuration: const Duration(seconds: 30),
            ),
          )
          ..add(_soundUpdate(_durationlessTrack)),
        // The rebuild emits nothing precisely because the basis survived it —
        // dropping it would rebuild the item with a null sourceDuration and
        // the maxDuration fallback, which is a different state.
        skip: 2,
        expect: () => <TimelineOverlayState>[],
        verify: (bloc) => expect(
          bloc.state.items.first.sourceDuration,
          const Duration(seconds: 30),
        ),
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps the track duration when the measurement disagrees',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc
          ..add(_soundUpdate(_durationlessTrack.copyWith(duration: 8)))
          ..add(
            TimelineOverlayWaveformLoaded(
              itemId: 'sound-1',
              leftChannel: Float32List(4),
              sourceDuration: const Duration(seconds: 30),
            ),
          ),
        skip: 1,
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                const Duration(seconds: 8),
              )
              .having(
                (s) => s.items.first.maxDuration,
                'maxDuration',
                const Duration(seconds: 6), // 8s source - 2s offset
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'ignores a non-positive measured duration',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc
          ..add(_soundUpdate(_durationlessTrack))
          ..add(
            TimelineOverlayWaveformLoaded(
              itemId: 'sound-1',
              leftChannel: Float32List(4),
              sourceDuration: Duration.zero,
            ),
          ),
        skip: 1,
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.items.first.sourceDuration,
                'sourceDuration',
                isNull,
              )
              .having(
                (s) => s.items.first.maxDuration,
                'maxDuration',
                VideoEditorConstants.maxDuration,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears selection when not trimming',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(selectedItemId: 'sound-1'),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
          ),
        ),
        expect: () => [const TimelineOverlayState()],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits no change while trim gesture keeps current selection',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          selectedItemId: 'sound-1',
          trimmingItemId: 'sound-1',
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
          ),
        ),
        expect: () => const [TimelineOverlayState(trimmingItemId: 'sound-1')],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'bumps player revision for undo-restored volume without history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ).copyWith(volume: 0.25),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                1,
              )
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 0)
              .having((s) => s.audioTracks.first.volume, 'volume', 1.0),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits when only an audio anchor is cleared',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: const [
            TimelineOverlayItem(
              id: 'sound-1',
              type: TimelineOverlayType.sound,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 4),
              label: 'Sound',
              maxDuration: VideoEditorConstants.maxDuration,
              audioSource: AudioSource.custom,
            ),
          ],
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
              anchorClipId: 'clip-1',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: const [
              TimelineOverlayItem(
                id: 'sound-1',
                type: TimelineOverlayType.sound,
                startTime: Duration(seconds: 1),
                endTime: Duration(seconds: 4),
                label: 'Sound',
                maxDuration: VideoEditorConstants.maxDuration,
                audioSource: AudioSource.custom,
              ),
            ],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'restores markers without bumping marker history revision',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 1)],
          timelineMarkersRevision: 2,
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
            timelineMarkers: [Duration(seconds: 2)],
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2)],
            timelineMarkersRevision: 2,
          ),
        ],
      );
    });

    group(TimelineOverlayAudioVolumeChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps volume and bumps history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAudioVolumeChanged(
            trackId: 'sound-1',
            volume: -1.0,
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.audioTracks.first.volume, 'volume', 0.0)
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 1)
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op for unknown track id',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAudioVolumeChanged(
            trackId: 'missing',
            volume: 0.5,
          ),
        ),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineOverlayAllAudioVolumeChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps below 0 to 0 on every custom track and bumps history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
            _audioEvent(
              id: 'sound-2',
              start: const Duration(seconds: 5),
              end: const Duration(seconds: 8),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: -1.0),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracks.map((t) => t.volume).toList(),
                'audio volumes',
                [0.0, 0.0],
              )
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 1)
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'preserves clip-anchored original-sound tracks and '
        'only mutes independent tracks',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'video_clip-a',
              start: Duration.zero,
              end: const Duration(seconds: 3),
              anchorClipId: 'clip-a',
            ),
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracks
                    .firstWhere((t) => t.id == 'video_clip-a')
                    .volume,
                'clip-anchored original-sound volume',
                1.0,
              )
              .having(
                (s) =>
                    s.audioTracks.firstWhere((t) => t.id == 'sound-1').volume,
                'custom track volume',
                0.0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'mutes an unanchored original-sound track added from another video',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            // video_-prefixed but not anchored to a clip: a network "Original
            // Sound" the user added, which has its own volume arc.
            _audioEvent(
              id: 'video_other-clip_copy_1',
              start: Duration.zero,
              end: const Duration(seconds: 3),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.audioTracks.single.volume,
            'added original-sound volume',
            0.0,
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when there are no audio tracks',
        build: TimelineOverlayBloc.new,
        seed: TimelineOverlayState.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when only clip-anchored original-sound tracks are present',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'video_clip-a',
              start: Duration.zero,
              end: const Duration(seconds: 3),
              anchorClipId: 'clip-a',
            ),
            _audioEvent(
              id: 'video_clip-b',
              start: const Duration(seconds: 3),
              end: const Duration(seconds: 6),
              anchorClipId: 'clip-b',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when every custom track is already at the clamped '
        'target volume',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
            _audioEvent(
              id: 'sound-2',
              start: const Duration(seconds: 5),
              end: const Duration(seconds: 8),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 2.0),
        ),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineOverlayItemMoved, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'shifts startTime and endTime by same delta',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            startTime: Duration(seconds: 3),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'layer-1',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 3),
                end: const Duration(seconds: 7),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not emit when item id does not exist',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const TimelineOverlayItemMoved(itemId: 'missing')),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineOverlayItemTrimmed, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates start/end and reassigns rows for changed type',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'a',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
            _item(
              id: 'b',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 3),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'a',
            isStart: false,
            startTime: Duration.zero,
            endTime: Duration(seconds: 4),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'a',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 4),
              ),
              _item(
                id: 'b',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 3),
                end: const Duration(seconds: 5),
                row: 1,
              ),
            ],
            trimPosition: const Duration(seconds: 4),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'applies the source offset and remaining-audio max on a left-trim',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'sound-1',
              type: TimelineOverlayType.sound,
              startTime: Duration.zero,
              endTime: Duration(seconds: 8),
              sourceDuration: Duration(seconds: 20),
              maxDuration: Duration(seconds: 20),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'sound-1',
            isStart: true,
            startTime: Duration(seconds: 3),
            endTime: Duration(seconds: 8),
            startOffset: Duration(seconds: 3),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.single,
            'item',
            isA<TimelineOverlayItem>()
                .having(
                  (i) => i.startTime,
                  'startTime',
                  const Duration(seconds: 3),
                )
                .having((i) => i.endTime, 'endTime', const Duration(seconds: 8))
                .having(
                  (i) => i.startOffset,
                  'startOffset',
                  const Duration(seconds: 3),
                )
                // maxDuration tracks the offset: 20s source - 3s consumed head.
                .having(
                  (i) => i.maxDuration,
                  'maxDuration',
                  const Duration(seconds: 17),
                ),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'leaves the source offset untouched on a right-trim',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'sound-1',
              type: TimelineOverlayType.sound,
              startTime: Duration(seconds: 2),
              endTime: Duration(seconds: 8),
              startOffset: Duration(seconds: 2),
              sourceDuration: Duration(seconds: 20),
              maxDuration: Duration(seconds: 18),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'sound-1',
            isStart: false,
            startTime: Duration(seconds: 2),
            endTime: Duration(seconds: 6),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.single,
            'item',
            isA<TimelineOverlayItem>()
                .having((i) => i.endTime, 'endTime', const Duration(seconds: 6))
                .having(
                  (i) => i.startOffset,
                  'startOffset',
                  const Duration(seconds: 2),
                )
                .having(
                  (i) => i.maxDuration,
                  'maxDuration',
                  const Duration(seconds: 18),
                ),
          ),
        ],
      );
    });

    group(TimelineOverlayAnchoredAudioRebased, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'moves matching sound items to follow the rebased tracks, leaving '
        'other items untouched',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
            _item(
              id: 'overlay',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 7),
              end: const Duration(seconds: 17),
            ),
          ]),
        ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'b-audio');
          expect(sound.startTime, const Duration(seconds: 7));
          expect(sound.endTime, const Duration(seconds: 17));
          final layer = bloc.state.items.firstWhere((i) => i.id == 'overlay');
          expect(layer.startTime, const Duration(seconds: 1));
          expect(layer.endTime, const Duration(seconds: 5));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not change source audioTracks (visual-only live update)',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
          audioTracks: [
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 7),
              end: const Duration(seconds: 17),
            ),
          ]),
        ),
        verify: (bloc) {
          // The persisted source track keeps its old position — only the
          // visual item moved. The native player / history reconcile on
          // release, not during the live drag.
          expect(
            bloc.state.audioTracks.single.startTime,
            const Duration(seconds: 10),
          );
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits nothing when the rebased positions already match',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ]),
        ),
        expect: () => const <TimelineOverlayState>[],
      );
    });

    group('selection and gestures', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'select and clear selected item',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayItemSelected('x'))
            ..add(const TimelineOverlayItemSelected(null));
        },
        expect: () => [
          const TimelineOverlayState(selectedItemId: 'x'),
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'start and end drag compacts rows and clears dragging id',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 3),
            ),
            _item(
              id: 'l-2',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 3),
              row: 2,
            ),
          ],
        ),
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayDragStarted('l-2'))
            ..add(const TimelineOverlayDragEnded());
        },
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
              ),
              _item(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
                row: 2,
              ),
            ],
            draggingItemId: 'l-2',
          ),
          TimelineOverlayState(
            items: [
              _item(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
              ),
              _item(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
                row: 1,
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'start and end trim clears trimming id',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayTrimStarted('x'))
            ..add(const TimelineOverlayTrimEnded());
        },
        expect: () => [
          const TimelineOverlayState(trimmingItemId: 'x'),
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragMoved sets dragPosition while dragging',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayDragStarted('x'))
            ..add(
              const TimelineOverlayDragMoved(Duration(milliseconds: 750)),
            );
        },
        expect: () => [
          const TimelineOverlayState(draggingItemId: 'x'),
          const TimelineOverlayState(
            draggingItemId: 'x',
            dragPosition: Duration(milliseconds: 750),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragMoved is ignored when no drag is active',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayDragMoved(Duration(milliseconds: 500)),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragEnded clears dragPosition',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          draggingItemId: 'x',
          dragPosition: Duration(milliseconds: 500),
        ),
        act: (bloc) => bloc.add(const TimelineOverlayDragEnded()),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.draggingItemId, 'draggingItemId', isNull)
              .having((s) => s.dragPosition, 'dragPosition', isNull),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayItemTrimmed exposes trimPosition for the dragged handle',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'a',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'a',
            isStart: false,
            endTime: Duration(seconds: 4),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.trimPosition,
            'trimPosition',
            const Duration(seconds: 4),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayTrimEnded clears trimPosition',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          trimmingItemId: 'x',
          trimPosition: Duration(seconds: 1),
        ),
        act: (bloc) => bloc.add(const TimelineOverlayTrimEnded()),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.trimmingItemId, 'trimmingItemId', isNull)
              .having((s) => s.trimPosition, 'trimPosition', isNull),
        ],
      );
    });

    group(TimelineOverlayCollapseToggled, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'toggles collapsed type on and off',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
            )
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
            );
        },
        expect: () => [
          const TimelineOverlayState(
            collapsedTypes: {TimelineOverlayType.layer},
          ),
          const TimelineOverlayState(),
        ],
      );
    });

    group(TimelineOverlayTotalDurationChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps item end time to the provided total duration',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 2),
              end: const Duration(seconds: 10),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 5)),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'layer-1',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 2),
                end: const Duration(seconds: 5),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps a sound item that ends before the total (L-Cut overhang '
        'survives the shrink)',
        build: TimelineOverlayBloc.new,
        // Anchored audio ending at 20 s stays put after a clip right-trim
        // shrinks the total to 27 s — its tail must keep overhanging into
        // the next clip rather than being clamped away or removed. A trailing
        // layer that does exceed the total forces an emission so the handler
        // definitely runs.
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
            _item(
              id: 'tail-layer',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 25),
              end: const Duration(seconds: 30),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 27)),
        ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'b-audio');
          expect(sound.startTime, const Duration(seconds: 10));
          expect(sound.endTime, const Duration(seconds: 20));
          final layer = bloc.state.items.firstWhere(
            (i) => i.id == 'tail-layer',
          );
          expect(layer.endTime, const Duration(seconds: 27));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'restores a sound bar the redo reconcile clamped against a stale total',
        build: TimelineOverlayBloc.new,
        // Redo of a stop-motion hold change: the history entry carries the
        // grown 4.5s window, but the reconcile reads the total off
        // ClipEditorBloc *before* the restored clips land there, so the bar is
        // built against the pre-redo 3s. The timeline then reports the real
        // total — the bar has to follow it back out, or the sound plays 3s
        // under a 4.5s video (#6401).
        act: (bloc) => bloc
          ..add(
            TimelineOverlayItemsUpdate(
              layers: const <Layer>[],
              filters: const <FilterState>[],
              audioTracks: [
                _audioEvent(
                  id: 'sound-1',
                  start: Duration.zero,
                  end: const Duration(milliseconds: 4500),
                ),
              ],
              totalVideoDuration: const Duration(seconds: 3),
            ),
          )
          ..add(
            const TimelineOverlayTotalDurationChanged(
              Duration(milliseconds: 4500),
            ),
          ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'sound-1');
          expect(sound.endTime, const Duration(milliseconds: 4500));
          // The bar alone is not enough: the preview player builds its window
          // from the item and is only re-synced when this counter moves, so
          // without the bump the sound keeps playing the truncated 3s.
          expect(bloc.state.audioTracksPlayerRevision, 1);
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not re-sync the player mid clip-trim drag',
        build: TimelineOverlayBloc.new,
        // The total changes every frame of the drag, so bumping here would
        // tear down and reschedule native audio per frame. The bar still
        // follows; only the player bump waits.
        act: (bloc) => bloc
          ..add(
            TimelineOverlayItemsUpdate(
              layers: const <Layer>[],
              filters: const <FilterState>[],
              audioTracks: [
                _audioEvent(
                  id: 'sound-1',
                  start: Duration.zero,
                  end: const Duration(seconds: 6),
                ),
              ],
              totalVideoDuration: const Duration(seconds: 6),
            ),
          )
          ..add(
            const TimelineOverlayTotalDurationChanged(
              Duration(seconds: 3),
              isClipTrimDragging: true,
            ),
          ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'sound-1');
          expect(sound.endTime, const Duration(seconds: 3));
          expect(bloc.state.audioTracksPlayerRevision, 0);
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not re-sync the player when no sound window moved',
        build: TimelineOverlayBloc.new,
        // A layer clamp must not churn the native audio tracks.
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 2),
              end: const Duration(seconds: 10),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 5)),
        ),
        verify: (bloc) {
          expect(bloc.state.audioTracksPlayerRevision, 0);
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not stretch a sound past the window the user trimmed it to',
        build: TimelineOverlayBloc.new,
        // Same growth, but this track's own window is 1.5s. Following the
        // total must never invent coverage the AudioEvent does not have.
        act: (bloc) => bloc
          ..add(
            TimelineOverlayItemsUpdate(
              layers: const <Layer>[],
              filters: const <FilterState>[],
              audioTracks: [
                _audioEvent(
                  id: 'sound-1',
                  start: Duration.zero,
                  end: const Duration(milliseconds: 1500),
                ),
              ],
              totalVideoDuration: const Duration(seconds: 3),
            ),
          )
          ..add(
            const TimelineOverlayTotalDurationChanged(
              Duration(milliseconds: 4500),
            ),
          ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'sound-1');
          expect(sound.endTime, const Duration(milliseconds: 1500));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps markers to the provided total duration',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [
            Duration(seconds: 2),
            Duration(seconds: 8),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 5)),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
          ),
        ],
      );
    });

    group(TimelineMarkerAdded, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'adds a marker at the playhead position',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(milliseconds: 1200),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(milliseconds: 1200)],
            timelineMarkersRevision: 1,
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not remove an existing marker near the playhead position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(milliseconds: 1230),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'sorts markers and clamps new marker to total duration',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 2)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(seconds: 8),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
            timelineMarkersRevision: 1,
          ),
        ],
      );
    });

    group(TimelineMarkerRemoved, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'removes an existing marker near the requested position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerRemoved(Duration(milliseconds: 1230)),
        ),
        expect: () => const [TimelineOverlayState(timelineMarkersRevision: 1)],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not emit when no marker is near the requested position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerRemoved(Duration(milliseconds: 1500)),
        ),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineMarkersRebased, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'replaces markers without bumping the history revision',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 1)],
          timelineMarkersRevision: 4,
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkersRebased([
            Duration(seconds: 5),
            Duration(seconds: 2),
            Duration(seconds: 2),
          ]),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
            timelineMarkersRevision: 4,
          ),
        ],
      );
    });
  });

  group(TimelineOverlayState, () {
    test('copyWith clear flags reset selected/dragging/trimming ids', () {
      const state = TimelineOverlayState(
        selectedItemId: 'selected',
        draggingItemId: 'dragging',
        trimmingItemId: 'trimming',
      );

      final cleared = state.copyWith(
        clearSelectedItemId: true,
        clearDraggingItemId: true,
        clearTrimmingItemId: true,
      );

      expect(cleared.selectedItemId, isNull);
      expect(cleared.draggingItemId, isNull);
      expect(cleared.trimmingItemId, isNull);
    });

    test('copyWith clear flags reset dragPosition and trimPosition', () {
      const state = TimelineOverlayState(
        dragPosition: Duration(milliseconds: 500),
        trimPosition: Duration(seconds: 2),
      );

      final cleared = state.copyWith(
        clearDragPosition: true,
        clearTrimPosition: true,
      );

      expect(cleared.dragPosition, isNull);
      expect(cleared.trimPosition, isNull);
    });
  });

  group('layer multi-select', () {
    PaintLayer paintLayer(String id) => PaintLayer(
      id: id,
      rawSize: const Size(10, 10),
      opacity: 1,
      item: PaintedModel(
        mode: PaintMode.freeStyle,
        offsets: const [Offset.zero, Offset(10, 10)],
        erasedOffsets: const [],
        color: const Color(0xFFFF0000),
        strokeWidth: 6,
        opacity: 1,
      ),
    );

    TimelineOverlayItem drawItem(String id) => TimelineOverlayItem(
      id: id,
      type: TimelineOverlayType.layer,
      startTime: Duration.zero,
      endTime: const Duration(seconds: 3),
      layer: paintLayer(id),
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'start seeds the tapped draw layer, enters mode, clears single selection',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [drawItem('a'), drawItem('b')],
        selectedItemId: 'a',
      ),
      act: (bloc) =>
          bloc.add(const TimelineOverlayLayerMultiSelectStarted('a')),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isTrue)
            .having((s) => s.multiSelectedLayerIds, 'selected', {'a'})
            .having((s) => s.selectedItemId, 'single selection', isNull),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'start with a non-mergeable id enters mode with an empty selection',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [
          _item(
            id: 'text',
            type: TimelineOverlayType.layer,
            start: Duration.zero,
            end: const Duration(seconds: 3),
          ),
        ],
      ),
      act: (bloc) =>
          bloc.add(const TimelineOverlayLayerMultiSelectStarted('text')),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isTrue)
            .having((s) => s.multiSelectedLayerIds, 'selected', isEmpty),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'toggle adds then removes a draw layer',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [drawItem('a')],
        isLayerMultiSelectMode: true,
      ),
      act: (bloc) => bloc
        ..add(const TimelineOverlayLayerMultiSelectToggled('a'))
        ..add(const TimelineOverlayLayerMultiSelectToggled('a')),
      expect: () => [
        isA<TimelineOverlayState>().having(
          (s) => s.multiSelectedLayerIds,
          'selected',
          {'a'},
        ),
        isA<TimelineOverlayState>().having(
          (s) => s.multiSelectedLayerIds,
          'selected',
          isEmpty,
        ),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'toggle ignores a non-mergeable layer',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [
          _item(
            id: 'text',
            type: TimelineOverlayType.layer,
            start: Duration.zero,
            end: const Duration(seconds: 3),
          ),
        ],
        isLayerMultiSelectMode: true,
      ),
      act: (bloc) =>
          bloc.add(const TimelineOverlayLayerMultiSelectToggled('text')),
      expect: () => <TimelineOverlayState>[],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'toggle is a no-op when not in multi-select mode',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(items: [drawItem('a')]),
      act: (bloc) =>
          bloc.add(const TimelineOverlayLayerMultiSelectToggled('a')),
      expect: () => <TimelineOverlayState>[],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'cancel exits mode and clears the selection',
      build: TimelineOverlayBloc.new,
      seed: () => const TimelineOverlayState(
        isLayerMultiSelectMode: true,
        multiSelectedLayerIds: {'a', 'b'},
      ),
      act: (bloc) => bloc.add(const TimelineOverlayLayerMultiSelectCancelled()),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isFalse)
            .having((s) => s.multiSelectedLayerIds, 'selected', isEmpty),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'items update prunes vanished selected ids and keeps the survivors',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [drawItem('a'), drawItem('b')],
        isLayerMultiSelectMode: true,
        multiSelectedLayerIds: const {'a', 'b'},
      ),
      act: (bloc) => bloc.add(
        TimelineOverlayItemsUpdate(
          layers: [paintLayer('a')],
          filters: const [],
          audioTracks: const [],
          totalVideoDuration: const Duration(seconds: 3),
        ),
      ),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isTrue)
            .having((s) => s.multiSelectedLayerIds, 'selected', {'a'}),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'items update prunes selected ids that are no longer mergeable',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [drawItem('a'), drawItem('b')],
        isLayerMultiSelectMode: true,
        multiSelectedLayerIds: const {'a', 'b'},
      ),
      act: (bloc) => bloc.add(
        TimelineOverlayItemsUpdate(
          layers: [
            paintLayer('a'),
            // An undo can restore a timeline window on a still-existing
            // layer, which makes it non-mergeable again.
            paintLayer('b').copyWith(
              startTime: Duration.zero,
              endTime: const Duration(seconds: 1),
            ),
          ],
          filters: const [],
          audioTracks: const [],
          totalVideoDuration: const Duration(seconds: 3),
        ),
      ),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isTrue)
            .having((s) => s.multiSelectedLayerIds, 'selected', {'a'}),
      ],
    );

    blocTest<TimelineOverlayBloc, TimelineOverlayState>(
      'items update exits mode once no selected id survives',
      build: TimelineOverlayBloc.new,
      seed: () => TimelineOverlayState(
        items: [drawItem('a')],
        isLayerMultiSelectMode: true,
        multiSelectedLayerIds: const {'a'},
      ),
      act: (bloc) => bloc.add(
        const TimelineOverlayItemsUpdate(
          layers: [],
          filters: [],
          audioTracks: [],
          totalVideoDuration: Duration(seconds: 3),
        ),
      ),
      expect: () => [
        isA<TimelineOverlayState>()
            .having((s) => s.isLayerMultiSelectMode, 'mode', isFalse)
            .having((s) => s.multiSelectedLayerIds, 'selected', isEmpty),
      ],
    );
  });

  group(TimelineOverlayItem, () {
    test('duration getter equals endTime - startTime', () {
      const item = TimelineOverlayItem(
        id: 'x',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 7),
      );

      expect(item.duration, equals(const Duration(seconds: 5)));
      expect(item.durationInSeconds, equals(5));
      expect(item.startTimeInSeconds, equals(2));
    });
  });
}
