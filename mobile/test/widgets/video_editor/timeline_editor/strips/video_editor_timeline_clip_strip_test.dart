// ABOUTME: Widget tests for VideoEditorTimelineClipStrip.
// ABOUTME: Validates clip rendering, layout, reorder gesture, and accessibility.

import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_editor/clip_waveform_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/clip_waveform_overlay.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineClipStrip, () {
    late ScrollController scrollController;
    late VideoEditorMainBloc mainBloc;

    setUp(() {
      scrollController = ScrollController();
      mainBloc = VideoEditorMainBloc();
    });

    tearDown(() {
      scrollController.dispose();
      mainBloc.close();
    });

    Widget buildWidget({
      List<DivineVideoClip>? clips,
      double totalWidth = 500,
      double pixelsPerSecond = TimelineConstants.pixelsPerSecond,
      bool isInteracting = false,
      ValueChanged<List<DivineVideoClip>>? onReorder,
      ValueChanged<bool>? onReorderChanged,
      ClipThumbnailManager? thumbnailManager,
      ClipWaveformManager? waveformManager,
      String? trimmingClipId,
      ClipTrimCallback? onTrimChanged,
      ValueChanged<bool>? onTrimDragChanged,
      bool scrollable = true,
      List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
    }) {
      final testClips =
          clips ??
          [
            _createTestClip(id: 'clip1', seconds: 3),
            _createTestClip(id: 'clip2', seconds: 4),
          ];

      final strip = VideoEditorTimelineClipStrip(
        clips: testClips,
        totalWidth: totalWidth,
        pixelsPerSecond: pixelsPerSecond,
        scrollController: scrollable ? scrollController : null,
        isInteracting: isInteracting,
        onReorder: onReorder,
        onReorderChanged: onReorderChanged,
        trimmingClipId: trimmingClipId,
        onTrimChanged: onTrimChanged,
        onTrimDragChanged: onTrimDragChanged,
        thumbnailManager: thumbnailManager,
        waveformManager: waveformManager,
      );

      return MaterialApp(
        navigatorObservers: navigatorObservers,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<VideoEditorMainBloc>.value(
            value: mainBloc,
            child: scrollable
                ? SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: strip,
                  )
                : Align(alignment: Alignment.centerLeft, child: strip),
          ),
        ),
      );
    }

    final waveformBands = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClipWaveformPainter,
    );

    ClipWaveformManager buildWaveformManager() => ClipWaveformManager(
      extractor: (_) async => WaveformData(
        leftChannel: Float32List.fromList([0.5, 1, 0.5]),
        sampleRate: 44100,
        duration: const Duration(seconds: 3),
        samplesPerSecond: 200,
      ),
    );

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineClipStrip', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
      });

      testWidgets('renders clip tiles for each clip', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
          _createTestClip(id: 'c', seconds: 1),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 600));

        // Each clip gets a ClipRRect for the tile
        expect(find.byType(ClipRRect), findsNWidgets(3));
      });

      testWidgets('renders single clip filling total width', (tester) async {
        final clips = [_createTestClip(id: 'only', seconds: 5)];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(find.byType(ClipRRect), findsOneWidget);
      });

      testWidgets('draws each clip its own waveform band', (tester) async {
        await tester.pumpWidget(
          buildWidget(waveformManager: buildWaveformManager()),
        );
        // Let the queued extraction resolve and publish.
        await tester.pump();

        expect(waveformBands, findsNWidgets(2));
      });

      // The tile forwards the clip's volume and duration into the band. Both
      // are one-liners in _ClipWaveformLayer, and matching on the painter's
      // type alone lets either be dropped or crossed with the waveform's own
      // values without a test noticing.
      testWidgets('flattens the band of a muted clip to its baseline', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            clips: [_createTestClip(id: 'muted', seconds: 3, volume: 0)],
            pixelsPerSecond: 100,
            waveformManager: buildWaveformManager(),
            scrollable: false,
          ),
        );
        await tester.pump();

        const baseline = TimelineConstants.clipWaveformMinBarHeight;
        expect(
          tester.renderObject(waveformBands),
          paints..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(
                0,
                TimelineConstants.thumbnailStripHeight - baseline,
                TimelineConstants.clipWaveformBarWidth,
                baseline,
              ),
              const Radius.circular(TimelineConstants.clipWaveformBarWidth / 2),
            ),
          ),
        );
      });

      testWidgets('spans the band over the clip duration, not the audio one', (
        tester,
      ) async {
        // A 4s clip against the 3s waveform the manager hands back: the bars
        // must cover the audio's own 3s of the tile and leave the rest bare.
        await tester.pumpWidget(
          buildWidget(
            clips: [_createTestClip(id: 'long', seconds: 4)],
            pixelsPerSecond: 100,
            waveformManager: buildWaveformManager(),
            scrollable: false,
          ),
        );
        await tester.pump();

        const barStep =
            TimelineConstants.clipWaveformBarWidth +
            TimelineConstants.clipWaveformBarSpacing;
        expect(
          tester.renderObject(waveformBands),
          paintsExactlyCountTimes(#drawRRect, (3 * 100 / barStep).floor()),
        );
      });

      testWidgets('draws no waveform band before extraction lands', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            waveformManager: ClipWaveformManager(
              extractor: (_) => Completer<WaveformData>().future,
            ),
          ),
        );
        await tester.pump();

        expect(waveformBands, findsNothing);
      });

      testWidgets('hides every waveform band during a reorder drag', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(waveformManager: buildWaveformManager()),
        );
        await tester.pump();
        expect(waveformBands, findsNWidgets(2));

        // Hold the press — a plain longPress releases it, ending the drag
        // before the badges are ever on screen.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoEditorTimelineClipStrip)),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Every tile — not just the picked-up one — shrinks to a 64px badge,
        // whose window of frames a full-clip band no longer lines up with.
        expect(waveformBands, findsNothing);

        await gesture.up();
        await tester.pumpAndSettle();

        expect(waveformBands, findsNWidgets(2));
      });
    });

    group('raster stability', () {
      // Strip thumbnails set cacheHeight, so the FileImage is wrapped
      // in a ResizeImage — unwrap before comparing the file path.
      bool providerHasPath(ImageProvider provider, String path) {
        if (provider is ResizeImage) {
          return providerHasPath(provider.imageProvider, path);
        }
        return provider is FileImage && provider.file.path == path;
      }

      Finder frame(String path) => find.byWidgetPredicate(
        (w) => w is Image && providerHasPath(w.image, path),
      );

      // The band is indexed from clip zero while the thumbnail row starts one
      // raster phase earlier, so the overlay carries a +phase offset inside
      // the tile's shared translate. Get either term wrong — drop the phase,
      // flip its sign, or lift the band out of the translate — and the bars
      // drift against the frames on every trimmed or split clip.
      testWidgets(
        'anchors the waveform band to clip zero: tracking trim-start, but '
        'not the thumbnail raster phase',
        (tester) async {
          final waveforms = ClipWaveformManager(
            extractor: (_) async => WaveformData(
              leftChannel: Float32List.fromList([0.5, 1, 0.5]),
              sampleRate: 44100,
              duration: const Duration(seconds: 3),
              samplesPerSecond: 200,
            ),
          );
          addTearDown(waveforms.dispose);

          // 3 s of content at 100 px/s → 300 px wide. sourceStartOffset 1.3 s
          // puts the recording-anchored slot grid 130 px in, leaving a 34 px
          // phase (130 % 48) that shifts the frames but not the band.
          final clip = _createTestClip(
            id: 'clip1',
            seconds: 3,
            trimStartMs: 500,
          ).copyWith(sourceStartOffset: const Duration(milliseconds: 1300));

          await tester.pumpWidget(
            buildWidget(
              clips: [clip],
              pixelsPerSecond: 100,
              waveformManager: waveforms,
              scrollable: false,
            ),
          );
          await tester.pump();

          final tileLeft = tester.getTopLeft(find.byType(ClipRRect)).dx;
          final bandLeft = tester
              .getTopLeft(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is ClipWaveformPainter,
                ),
              )
              .dx;

          expect(
            bandLeft,
            moreOrLessEquals(tileLeft - 50),
            reason:
                'the band must sit exactly trim-start (0.5 s → 50 px) left '
                'of the tile — no raster phase, which belongs to the frames',
          );
        },
      );

      // Regression for the visible leftward frame shift when a split's end
      // half finishes rendering: the render rebases the clip from source
      // time (trimStart = split point) to file time (trimStart = 0,
      // sourceStartOffset = split point). The thumbnail slot raster is
      // anchored to the original recording via sourceStartOffset, so every
      // frame must keep its exact on-screen position across that swap.
      testWidgets(
        'keeps each frame at the same x-position when the split end half '
        'swaps from source-timed preview to rebased rendered geometry',
        (tester) async {
          final manager = ClipThumbnailManager(
            stripThumbnailStreamFactory: ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              Duration startOffset = Duration.zero,
              List<Duration>? priorityTimestamps,
            }) => const Stream.empty(),
          );
          addTearDown(manager.dispose);

          // Split of a 3 s source at 1.3 s; visible width 1.7 s × 100 px/s.
          const pps = 100.0;
          const totalWidth = 170.0;

          // Preview phase: still source-timed against the source video.
          final previewEnd = _createTestClip(
            id: 'end',
            seconds: 3,
          ).copyWith(trimStart: const Duration(milliseconds: 1300));
          await tester.pumpWidget(
            buildWidget(
              clips: [previewEnd],
              totalWidth: totalWidth,
              pixelsPerSecond: pps,
              thumbnailManager: manager,
              scrollable: false,
            ),
          );
          manager['end'].value = const [
            StripThumbnail(
              path: '/t/f1.jpg',
              timestamp: Duration(milliseconds: 1500),
            ),
            StripThumbnail(
              path: '/t/f2.jpg',
              timestamp: Duration(milliseconds: 2000),
            ),
            StripThumbnail(
              path: '/t/f3.jpg',
              timestamp: Duration(milliseconds: 2500),
            ),
          ];
          await tester.pump();

          final previewX = {
            for (final path in ['/t/f1.jpg', '/t/f2.jpg', '/t/f3.jpg'])
              path: tester.getTopLeft(frame(path)).dx,
          };

          // Rendered phase: the file starts at the split point, timestamps
          // are rebased by -1.3 s and sourceStartOffset records the shift.
          final renderedEnd = _createTestClip(id: 'end', seconds: 3).copyWith(
            duration: const Duration(milliseconds: 1700),
            sourceStartOffset: const Duration(milliseconds: 1300),
          );
          await tester.pumpWidget(
            buildWidget(
              clips: [renderedEnd],
              totalWidth: totalWidth,
              pixelsPerSecond: pps,
              thumbnailManager: manager,
              scrollable: false,
            ),
          );
          manager['end'].value = const [
            StripThumbnail(
              path: '/t/f1.jpg',
              timestamp: Duration(milliseconds: 200),
            ),
            StripThumbnail(
              path: '/t/f2.jpg',
              timestamp: Duration(milliseconds: 700),
            ),
            StripThumbnail(
              path: '/t/f3.jpg',
              timestamp: Duration(milliseconds: 1200),
            ),
          ];
          await tester.pump();

          for (final entry in previewX.entries) {
            expect(
              tester.getTopLeft(frame(entry.key)).dx,
              moreOrLessEquals(entry.value),
              reason:
                  '${entry.key} must stay at its pre-render x-position — '
                  'a shift means the slot raster re-anchored on the '
                  'rendered file instead of the original recording',
            );
          }
        },
      );

      // Reversing keeps sourceStartOffset (it survives copyWith), but the
      // reversed file is physically mirrored — there is no recording
      // continuity to preserve, so the raster must stay file-anchored
      // instead of phase-shifting by the stale offset.
      testWidgets(
        'ignores sourceStartOffset for reversed clips — their slot raster '
        'stays file-anchored',
        (tester) async {
          final manager = ClipThumbnailManager(
            stripThumbnailStreamFactory: ({
              required String videoPath,
              required String clipId,
              required Duration duration,
              required Size outputSize,
              required int thumbsPerSecond,
              Duration startOffset = Duration.zero,
              List<Duration>? priorityTimestamps,
            }) => const Stream.empty(),
          );
          addTearDown(manager.dispose);

          const pps = 100.0;
          const totalWidth = 170.0;
          const frames = [
            StripThumbnail(
              path: '/t/r1.jpg',
              timestamp: Duration(milliseconds: 200),
            ),
            StripThumbnail(
              path: '/t/r2.jpg',
              timestamp: Duration(milliseconds: 700),
            ),
            StripThumbnail(
              path: '/t/r3.jpg',
              timestamp: Duration(milliseconds: 1200),
            ),
          ];

          // File-anchored reference: identical geometry with no offset.
          final plain = _createTestClip(
            id: 'end',
            seconds: 3,
          ).copyWith(duration: const Duration(milliseconds: 1700));
          await tester.pumpWidget(
            buildWidget(
              clips: [plain],
              totalWidth: totalWidth,
              pixelsPerSecond: pps,
              thumbnailManager: manager,
              scrollable: false,
            ),
          );
          manager['end'].value = frames;
          await tester.pump();

          final fileAnchoredX = {
            for (final path in ['/t/r1.jpg', '/t/r2.jpg', '/t/r3.jpg'])
              path: tester.getTopLeft(frame(path)).dx,
          };

          // Same clip reversed, carrying the offset of a rendered split end
          // half — the raster must not move.
          final reversedEnd = _createTestClip(id: 'end', seconds: 3).copyWith(
            duration: const Duration(milliseconds: 1700),
            sourceStartOffset: const Duration(milliseconds: 1300),
            reversed: true,
          );
          await tester.pumpWidget(
            buildWidget(
              clips: [reversedEnd],
              totalWidth: totalWidth,
              pixelsPerSecond: pps,
              thumbnailManager: manager,
              scrollable: false,
            ),
          );
          manager['end'].value = frames;
          await tester.pump();

          for (final entry in fileAnchoredX.entries) {
            expect(
              tester.getTopLeft(frame(entry.key)).dx,
              moreOrLessEquals(entry.value),
              reason:
                  '${entry.key} must sit at its file-anchored position — '
                  'a shift means the reversed clip still applies the '
                  'recording-anchored raster phase',
            );
          }
        },
      );
    });

    group('layout', () {
      testWidgets('uses correct strip height', (tester) async {
        await tester.pumpWidget(buildWidget());

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(
          container.constraints?.maxHeight ?? container.decoration,
          isNotNull,
        );
      });

      testWidgets('uses GestureDetector for long press reorder', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        // 1 root GestureDetector for long-press reorder +
        // 1 per clip tile for tap selection.
        expect(find.byType(GestureDetector), findsAtLeast(1));
      });
    });

    group('single clip', () {
      testWidgets('does not trigger reorder for single clip', (tester) async {
        var reorderTriggered = false;
        final clips = [_createTestClip(id: 'only', seconds: 5)];

        await tester.pumpWidget(
          buildWidget(
            clips: clips,
            totalWidth: 400,
            onReorderChanged: (_) => reorderTriggered = true,
          ),
        );

        // Long press on single clip should not enter reorder mode
        await tester.longPress(find.byType(VideoEditorTimelineClipStrip));
        await tester.pumpAndSettle();

        expect(reorderTriggered, isFalse);
      });
    });

    group('interaction', () {
      testWidgets('does not start reorder when isInteracting is true', (
        tester,
      ) async {
        var reorderTriggered = false;

        await tester.pumpWidget(
          buildWidget(
            isInteracting: true,
            onReorderChanged: (_) => reorderTriggered = true,
          ),
        );

        await tester.longPress(find.byType(VideoEditorTimelineClipStrip));
        await tester.pumpAndSettle();

        expect(reorderTriggered, isFalse);
      });

      testWidgets('pauses thumbnails while another route covers the strip', (
        tester,
      ) async {
        final thumbnailManager = _RecordingClipThumbnailManager();

        await tester.pumpWidget(
          buildWidget(
            thumbnailManager: thumbnailManager,
            navigatorObservers: <NavigatorObserver>[routeObserver],
          ),
        );
        await tester.pump();

        final context = tester.element(
          find.byType(VideoEditorTimelineClipStrip),
        );
        final push = Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(thumbnailManager.pauseCount, equals(1));
        expect(thumbnailManager.resumeCount, isZero);

        Navigator.of(context).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await push;

        expect(thumbnailManager.pauseCount, equals(1));
        expect(thumbnailManager.resumeCount, equals(1));
      });
    });

    group('accessibility', () {
      testWidgets('provides clip semantics with duration', (tester) async {
        final clips = [
          _createTestClip(id: 'a', seconds: 3),
          _createTestClip(id: 'b', seconds: 5),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));

        // Clip 1 of 2, 3.0 seconds
        expect(
          find.bySemanticsLabel(RegExp(r'Clip 1 of 2.*3\.0 seconds')),
          findsOneWidget,
        );
        // Clip 2 of 2, 5.0 seconds
        expect(
          find.bySemanticsLabel(RegExp(r'Clip 2 of 2.*5\.0 seconds')),
          findsOneWidget,
        );
      });

      testWidgets('provides reorder hint for multiple clips', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        final semantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Clip 1 of 2')),
        );
        expect(semantics.hint, contains('Long press to reorder'));
      });
    });

    group('thumbnail fallback', () {
      // Regression: the fallback must be a plain FileImage (not a
      // cacheHeight-keyed ResizeImage) so it hits the warm poster cache entry
      // instead of a cold decode that flashes black on first open.
      testWidgets('poster fallback reuses the plain FileImage key (no resize)', (
        tester,
      ) async {
        final clips = [
          _createTestClip(
            id: 'a',
            thumbnailPath: '/tmp/nonexistent_thumb_a.jpg',
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        // Before strip thumbnails stream in, every slot renders the poster
        // fallback. Each must be a plain FileImage on the thumbnail path.
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, isNotEmpty);
        for (final image in images) {
          expect(
            image.image,
            isA<FileImage>().having(
              (provider) => provider.file.path,
              'file.path',
              '/tmp/nonexistent_thumb_a.jpg',
            ),
            reason:
                'Fallback must use a plain FileImage (not a cacheHeight-keyed '
                'ResizeImage) so it hits the warm poster cache entry and '
                'paints instantly instead of flashing black.',
          );
        }
      });
    });

    group('empty state', () {
      testWidgets('renders with empty clip list', (tester) async {
        await tester.pumpWidget(buildWidget(clips: [], totalWidth: 0));

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
      });
    });

    group('trimmed clips', () {
      testWidgets('renders trimmed clip without error', (tester) async {
        final clips = [
          _createTestClip(
            id: 'trimmed',
            seconds: 5,
            trimStartMs: 1000,
            trimEndMs: 500,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('multi-clip strip with trimmed clips renders both tiles', (
        tester,
      ) async {
        final clips = [
          // trimmedDuration = 5s - 2s - 1s = 2s
          _createTestClip(
            id: 'a',
            seconds: 5,
            trimStartMs: 2000,
            trimEndMs: 1000,
          ),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));

        expect(find.byType(ClipRRect), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('fully trimmed clip does not crash the strip', (
        tester,
      ) async {
        // trimStart + trimEnd == duration → trimmedDuration == zero;
        // the strip should skip this clip gracefully.
        final clips = [
          _createTestClip(id: 'normal', seconds: 3),
          _createTestClip(
            id: 'over_trimmed',
            trimStartMs: 1000,
            trimEndMs: 1000,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(tester.takeException(), isNull);
      });
    });

    group('trim drag accumulation', () {
      // Regression: the trim tile used to compute `newTrim = widget.clip.trim +
      // incrementalDelta`, reading the base back from widget.clip. That value
      // only lands on widget.clip a frame after it round-trips through
      // ClipEditorBloc, so when several drag updates fire before a rebuild
      // (120Hz touch, or a heavy timeline that can't rebuild every frame) every
      // update reused the same stale base and dropped the intermediate deltas —
      // the handle lagged further behind the finger the longer you dragged.
      //
      // Here widget.clip is never fed the reported trim back, so the base stays
      // at zero across the whole drag. With local accumulation the reported
      // trimEnd grows on every update; without it every update reports the same
      // single-delta value.
      testWidgets('right handle accumulates deltas across updates without a '
          'rebuilt clip', (tester) async {
        final clip = _createTestClip(id: 'solo', seconds: 30);
        final reportedTrimEndMs = <int>[];

        await tester.pumpWidget(
          buildWidget(
            clips: [clip],
            trimmingClipId: clip.id,
            scrollable: false,
            onTrimChanged:
                ({
                  required clipId,
                  required isStart,
                  required trimStart,
                  required trimEnd,
                }) {
                  if (!isStart) reportedTrimEndMs.add(trimEnd.inMilliseconds);
                },
          ),
        );

        // Start just inside the right edge: the right handle's grab zone
        // reaches inward from the edge, and staying in-bounds avoids the
        // beyond-edge hit area that only the production HitExpandedBox makes
        // reachable.
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final start = box.localToGlobal(
          Offset(box.size.width - 2, box.size.height / 2),
        );

        final gesture = await tester.startGesture(start);
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(-30, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(reportedTrimEndMs.length, greaterThanOrEqualTo(3));
        for (var i = 1; i < reportedTrimEndMs.length; i++) {
          expect(
            reportedTrimEndMs[i],
            greaterThan(reportedTrimEndMs[i - 1]),
            reason:
                'trimEnd must accumulate across drag updates. A constant value '
                'means each update reused the stale widget.clip base and '
                'dropped the previous deltas.',
          );
        }
      });

      testWidgets('left handle accumulates deltas across updates without a '
          'rebuilt clip', (tester) async {
        final clip = _createTestClip(id: 'solo', seconds: 30);
        final reportedTrimStartMs = <int>[];

        await tester.pumpWidget(
          buildWidget(
            clips: [clip],
            trimmingClipId: clip.id,
            scrollable: false,
            onTrimChanged:
                ({
                  required clipId,
                  required isStart,
                  required trimStart,
                  required trimEnd,
                }) {
                  if (isStart) {
                    reportedTrimStartMs.add(trimStart.inMilliseconds);
                  }
                },
          ),
        );

        // Start just inside the left edge — the left handle's grab zone
        // reaches inward from the edge (mirrors the right-handle test above).
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final start = box.localToGlobal(Offset(2, box.size.height / 2));

        final gesture = await tester.startGesture(start);
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(30, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(reportedTrimStartMs.length, greaterThanOrEqualTo(3));
        for (var i = 1; i < reportedTrimStartMs.length; i++) {
          expect(
            reportedTrimStartMs[i],
            greaterThan(reportedTrimStartMs[i - 1]),
            reason:
                'trimStart must accumulate across drag updates. A constant '
                'value means each update reused the stale widget.clip base '
                'and dropped the previous deltas.',
          );
        }
      });
    });

    group('trim limit haptics', () {
      testWidgets('re-arms the at-limit haptic on each new drag', (
        tester,
      ) async {
        final hapticCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(call);
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final clip = _createTestClip(id: 'solo', seconds: 3);
        await tester.pumpWidget(
          buildWidget(
            clips: [clip],
            trimmingClipId: clip.id,
            scrollable: false,
          ),
        );

        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final start = box.localToGlobal(
          Offset(box.size.width - 2, box.size.height / 2),
        );

        // The first move only triggers gesture acceptance and is consumed by
        // DragStartBehavior.start without producing an update. Each following
        // move must already overshoot the 2.94s max-trim limit on its own
        // (170px / 52pps ≈ 3.27s) so that every delivered update is clamped:
        // an intermediate non-clamped update would clear the at-limit flag
        // itself and hide a stale flag carried over from the previous drag.
        Future<void> dragPastLimit() async {
          final gesture = await tester.startGesture(start);
          await tester.pump();
          for (var i = 0; i < 3; i++) {
            await gesture.moveBy(const Offset(-170, 0));
            await tester.pump();
          }
          await gesture.up();
          await tester.pump();
        }

        // First drag overshoots far past the max-trim limit → one haptic.
        await dragPastLimit();

        expect(hapticCalls, hasLength(1));

        // A second drag hitting the limit again must haptic again — the
        // at-limit flag is re-armed on drag start, not kept from last drag.
        await dragPastLimit();

        expect(hapticCalls, hasLength(2));
      });
    });

    group('playbackSpeed scaling', () {
      // Regression: slow clips (speed < 1) used to render thumbnails over the
      // source-time pixel width, so the inner slot Row only spanned half the
      // visible playback-time tile and the strip stretched a smaller set of
      // wider slots — leaving the trailing region looking empty/black while
      // thumbnails streamed in. The underlying source-time strip
      // (_ClipTile.fullWidth) must be scaled by 1/playbackSpeed so the
      // generated thumbnail-slot count matches the visible tile.
      //
      // With the fix the inner Row renders `ceil(playbackWidth /
      // thumbnailWidth)` slots, each at the natural `thumbnailWidth`.
      // Without the fix `contentWidth < displayWidth`, so the renderer
      // falls back to stretched slots (`displayWidth / count`) wider than
      // `thumbnailWidth`, producing zero slot boxes at the natural width.
      testWidgets('slow clip renders thumbnail slots at the natural width', (
        tester,
      ) async {
        const pps = 50.0;
        // source duration 4s, speed 0.5 → playback duration 8s.
        // Playback-scaled width = 4 / 0.5 * 50 = 400 px.
        // Expected natural-width slot count for the slow clip:
        //   ceil(400 / TimelineConstants.thumbnailWidth (= 48)) = 9.
        final slow = _createTestClip(
          id: 'slow',
          seconds: 4,
        ).copyWith(playbackSpeed: 0.5);
        // Normal clip kept tiny so its slot count is small and stable
        // (ceil(2 * 50 / 48) = 3) — used only to keep the strip on its
        // multi-clip branch (single-clip branch overrides _clipWidth with
        // totalWidth).
        final clips = [slow, _createTestClip(id: 'normal')];

        await tester.pumpWidget(
          buildWidget(clips: clips, pixelsPerSecond: pps, totalWidth: 1000),
        );

        final naturalSlotCount = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .where(
              (s) =>
                  s.height == TimelineConstants.thumbnailStripHeight &&
                  s.width == TimelineConstants.thumbnailWidth,
            )
            .length;

        // 9 (slow clip) + 3 (normal clip) = 12. Without the 1/speed
        // scaling the slow clip falls back to stretched slots wider than
        // thumbnailWidth and contributes 0, leaving only the 3 from the
        // normal clip.
        expect(
          naturalSlotCount,
          equals(12),
          reason:
              'Slow clip must render ceil(playbackWidth / thumbnailWidth) '
              'natural-width slots. Without the 1/playbackSpeed scaling '
              'of _ClipTile.fullWidth the slow clip falls back to '
              'stretched slots (width > thumbnailWidth), producing 3 '
              'instead of 12 natural-width slots.',
        );
      });
    });

    group('split seeding', () {
      late _MockClipEditorBloc clipBloc;
      late ClipThumbnailManager manager;

      setUp(() {
        clipBloc = _MockClipEditorBloc();
        manager = ClipThumbnailManager(
          stripThumbnailStreamFactory: ({
            required String videoPath,
            required String clipId,
            required Duration duration,
            required Size outputSize,
            required int thumbsPerSecond,
            Duration startOffset = Duration.zero,
            List<Duration>? priorityTimestamps,
          }) => const Stream<List<StripThumbnail>>.empty(),
        );
      });

      tearDown(() {
        manager.dispose();
      });

      Widget buildStrip(List<DivineVideoClip> clips) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              ],
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                child: VideoEditorTimelineClipStrip(
                  clips: clips,
                  totalWidth: 500,
                  pixelsPerSecond: TimelineConstants.pixelsPerSecond,
                  scrollController: scrollController,
                  thumbnailManager: manager,
                ),
              ),
            ),
          ),
        );
      }

      testWidgets(
        'seeds the split halves even when the first build bails before the '
        'halves exist (transient bail must not consume the split)',
        (tester) async {
          final split = ClipSplitEvent(
            sourceClipId: 'src',
            startClipId: 'start',
            endClipId: 'end',
            absoluteSplitPosition: const Duration(seconds: 3),
            sourceDuration: const Duration(seconds: 10),
          );
          when(
            () => clipBloc.state,
          ).thenReturn(ClipEditorState(lastSplit: split));

          // Seed the source clip's thumbnails so each split half (the
          // start range [0, 3s) and the end range [3s, 10s)) has a warm
          // frame to borrow.
          final sourceClip = _createTestClip(id: 'src', seconds: 10);
          manager.sync(clips: [sourceClip], devicePixelRatio: 1);
          manager['src'].value = [
            const StripThumbnail(
              path: '/tmp/frame_start.jpg',
              timestamp: Duration(seconds: 1),
            ),
            const StripThumbnail(
              path: '/tmp/frame_end.jpg',
              timestamp: Duration(seconds: 5),
            ),
          ];

          // First build still only contains the source clip — the split
          // halves don't exist yet, so seeding must bail without marking
          // the split consumed. No 'start' notifier is created by the bail.
          await tester.pumpWidget(buildStrip([sourceClip]));
          expect(() => manager['start'], throwsA(anything));

          // The halves arrive on the next build. If the transient bail had
          // permanently consumed the split, seeding would be skipped here
          // and the black flash would return.
          final startClip = _createTestClip(id: 'start', seconds: 3);
          final endClip = _createTestClip(id: 'end', seconds: 7);
          await tester.pumpWidget(buildStrip([startClip, endClip]));

          expect(manager['start'].value, isNotEmpty);
          expect(manager['end'].value, isNotEmpty);
        },
      );
    });
  });
}

class _RecordingClipThumbnailManager extends ClipThumbnailManager {
  int pauseCount = 0;
  int resumeCount = 0;

  @override
  void pauseAll() {
    pauseCount++;
    super.pauseAll();
  }

  @override
  void resumeAll() {
    resumeCount++;
    super.resumeAll();
  }
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
  int trimStartMs = 0,
  int trimEndMs = 0,
  String? thumbnailPath,
  double volume = 1,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
    trimStart: Duration(milliseconds: trimStartMs),
    trimEnd: Duration(milliseconds: trimEndMs),
    thumbnailPath: thumbnailPath,
    volume: volume,
  );
}
