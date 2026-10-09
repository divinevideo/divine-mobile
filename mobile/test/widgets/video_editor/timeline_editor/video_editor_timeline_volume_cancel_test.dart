import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/live_volume.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/cancel_live_volume_preview.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_volume.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VideoEditorTimelineVolume cancellation', () {
    late ClipEditorBloc clips;
    late TimelineOverlayBloc overlays;
    late VideoEditorMainBloc main;
    late _Probe probe;
    late GlobalKey<_LiveOwnerState> ownerKey;
    void initializeFixture() {
      clips = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
      );
      overlays = TimelineOverlayBloc();
      main = VideoEditorMainBloc();
      probe = _Probe();
      ownerKey = GlobalKey<_LiveOwnerState>();
      clips.add(
        ClipEditorInitialized([
          DivineVideoClip(
            id: 'clip-a',
            video: EditorVideo.file('/test/clip-a.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime(2025),
            originalAspectRatio: 9 / 16,
            targetAspectRatio: .vertical,
          ),
        ]),
      );
      overlays.add(
        TimelineOverlayItemsUpdate(
          layers: const <Layer>[],
          filters: const <FilterState>[],
          audioTracks: [
            AudioEvent(
              id: 'track-a',
              pubkey: '1111111111111111111111111111111111111111111111111111111111111111',
              createdAt: 1704067200,
              title: 'Beat',
              endTime: const Duration(seconds: 3),
            ),
          ],
          totalVideoDuration: const Duration(seconds: 3),
        ),
      );
      main.add(const VideoEditorVolumeEditModeToggled());
    }

    void testVolume(
      String description,
      Future<void> Function(WidgetTester) body,
    ) {
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }

    setUp(initializeFixture);
    tearDown(() async {
      await clips.close();
      await overlays.close();
      await main.close();
    });

    Future<void> deliverBlocStates(WidgetTester tester) async {
      // These real bloc streams are owned by setUp's real-async zone.
      // Drain that queue explicitly before asking Flutter to settle frames.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    }

    Future<void> mount(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ClipEditorBloc>.value(value: clips),
                BlocProvider<TimelineOverlayBloc>.value(value: overlays),
                BlocProvider<VideoEditorMainBloc>.value(value: main),
              ],
              child: _LiveOwner(
                key: ownerKey,
                clips: clips,
                overlays: overlays,
                probe: probe,
              ),
            ),
          ),
        ),
      );
      await deliverBlocStates(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<TestGesture> drag(
      WidgetTester tester, {
      String label = 'Clip 1',
      bool boost = true,
    }) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel(label)),
      );
      await gesture.moveBy(const Offset(0, -30));
      if (boost) await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(probe.live.value, isNotNull);
      expect(probe.live.value!.session, isNotNull);
      expect(probe.live.value!.volume, boost ? greaterThan(1) : equals(1));
      expect(probe.header.value, probe.live.value!.volume);
      expect(clips.state.clips.first.volume, 1);
      expect(clips.state.clipsVolumeRevision, 0);
      expect(overlays.state.audioTracks.first.volume, 1);
      expect(overlays.state.audioTracksRevision, 0);
      return gesture;
    }

    Future<void> settlePlayer(WidgetTester tester) async {
      await tester.pump();
      expect(probe.player.isIdle, isTrue);
    }

    void restored(double gain) {
      expect(probe.live.value, isNull);
      expect(probe.values.length, greaterThanOrEqualTo(2));
      expect(probe.values[probe.values.length - 2]?.volume, gain);
      expect(probe.values.last, isNull);
      expect(probe.player.sent.last.volume, gain);
      expect(probe.player.lastAppliedGain, gain);
      expect(probe.accepted, 1);
    }

    for (final label in ['Clip 1', 'Beat']) {
      testVolume('$label unmount cancels after the exit animation', (
        tester,
      ) async {
        await mount(tester);
        final gesture = await drag(tester, label: label);
        main.add(const VideoEditorVolumeEditModeToggled());
        await deliverBlocStates(tester);
        await tester.pumpAndSettle();
        expect(main.state.isVolumeEditMode, isFalse);
        expect(find.bySemanticsLabel(label), findsNothing);
        await settlePlayer(tester);
        restored(1);
        expect(probe.header.value, isNull);
        expect(clips.state.clipsVolumeRevision, 0);
        expect(overlays.state.audioTracksRevision, 0);
        await gesture.up();
        await deliverBlocStates(tester);
        expect(clips.state.clips.first.volume, 1);
        expect(overlays.state.audioTracks.first.volume, 1);
        expect(clips.state.clipsVolumeRevision, 0);
        expect(overlays.state.audioTracksRevision, 0);
        expect(probe.accepted, 1);
        expect(tester.takeException(), isNull);
      });

      for (final secondPointer in [false, true]) {
        testVolume(
          '$label OS cancel still commits (second finger: $secondPointer)',
          (
            tester,
          ) async {
            await mount(tester);
            final first = await drag(tester, label: label);
            var active = first;
            if (secondPointer) {
              // No fixed pointer id: the counter flutter_test assigns ids from
              // is shared by every test in the isolate, so a fixed id can
              // equal the one the still-held first finger was given.
              active = await tester.startGesture(
                tester.getCenter(find.bySemanticsLabel(label)),
              );
              await first.up();
              await active.moveBy(const Offset(0, -10));
            }
            final gain = probe.live.value!.volume;
            expect(gain, isNot(1));
            await active.cancel();
            await deliverBlocStates(tester);
            expect(probe.live.value, isNull);
            expect(probe.header.value, isNull);
            expect(
              clips.state.clips.first.volume,
              label == 'Clip 1' ? gain : 1,
            );
            expect(
              overlays.state.audioTracks.first.volume,
              label == 'Beat' ? gain : 1,
            );
            expect(clips.state.clipsVolumeRevision, label == 'Clip 1' ? 1 : 0);
            expect(overlays.state.audioTracksRevision, label == 'Beat' ? 1 : 0);
            expect(probe.accepted, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }

      testVolume('$label release during panel exit still commits once', (
        tester,
      ) async {
        await mount(tester);
        final gesture = await drag(tester, label: label);
        final gain = probe.live.value!.volume;
        main.add(const VideoEditorVolumeEditModeToggled());
        await deliverBlocStates(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.bySemanticsLabel(label), findsOneWidget);
        await gesture.up();
        await deliverBlocStates(tester);
        await tester.pumpAndSettle();
        expect(probe.live.value, isNull);
        expect(probe.header.value, isNull);
        expect(clips.state.clips.first.volume, label == 'Clip 1' ? gain : 1);
        expect(
          overlays.state.audioTracks.first.volume,
          label == 'Beat' ? gain : 1,
        );
        expect(clips.state.clipsVolumeRevision, label == 'Clip 1' ? 1 : 0);
        expect(overlays.state.audioTracksRevision, label == 'Beat' ? 1 : 0);
        expect(probe.accepted, 0);
        expect(tester.takeException(), isNull);
      });

      testVolume('$label disposal restores current committed gain', (
        tester,
      ) async {
        await mount(tester);
        final gesture = await drag(tester, label: label);
        if (label == 'Clip 1') {
          clips.add(
            const ClipEditorClipVolumeChanged(clipId: 'clip-a', volume: 0.4),
          );
        } else {
          overlays.add(
            const TimelineOverlayAudioVolumeChanged(
              trackId: 'track-a',
              volume: 0.4,
            ),
          );
        }
        await deliverBlocStates(tester);
        expect(
          label == 'Clip 1'
              ? clips.state.clips.first.volume
              : overlays.state.audioTracks.first.volume,
          0.4,
        );
        main.add(const VideoEditorVolumeEditModeToggled());
        await deliverBlocStates(tester);
        await tester.pumpAndSettle();
        await settlePlayer(tester);
        restored(0.4);
        await gesture.up();
        expect(clips.state.clipsVolumeRevision, label == 'Clip 1' ? 1 : 0);
        expect(overlays.state.audioTracksRevision, label == 'Beat' ? 1 : 0);
        expect(probe.header.value, isNull);
        expect(tester.takeException(), isNull);
      });
    }

    testVolume('stale disposal cannot clear an equal-gain newer preview', (
      tester,
    ) async {
      await mount(tester);
      final expected = LiveVolume.clip('clip-a', 1.6, session: UniqueKey());
      final newer = LiveVolume.clip('clip-a', 1.6, session: UniqueKey());
      probe.live.value = expected;
      probe.live.value = newer;
      expect(identical(probe.live.value, newer), isTrue);
      expect(
        cancelLiveVolumePreview(
          expected: expected,
          notifier: probe.live,
          clipState: clips.state,
          overlayState: overlays.state,
        ),
        isFalse,
      );
      expect(identical(probe.live.value, newer), isTrue);
      expect(clips.state.clipsVolumeRevision, 0);
    });

    for (final isClip in [true, false]) {
      testVolume(
        '${isClip ? 'clip' : 'track'} drag survives preceding removal',
        (
          tester,
        ) async {
          await tester.runAsync(pumpEventQueue);
          final originalClip = clips.state.clips.single;
          final originalTrack = overlays.state.audioTracks.single;
          if (isClip) {
            clips.add(
              ClipEditorInitialized([
                originalClip.copyWith(id: 'preceding-clip'),
                originalClip,
              ]),
            );
          } else {
            overlays.add(
              TimelineOverlayItemsUpdate(
                layers: const <Layer>[],
                filters: const <FilterState>[],
                audioTracks: [
                  originalTrack.copyWith(id: 'preceding-track', title: 'Other'),
                  originalTrack,
                ],
                totalVideoDuration: const Duration(seconds: 3),
              ),
            );
          }
          await mount(tester);
          final gesture = await drag(tester, label: isClip ? 'Clip 2' : 'Beat');
          final live = probe.live.value!;
          if (isClip) {
            clips.add(const ClipEditorClipRemoved('preceding-clip'));
          } else {
            overlays.add(
              TimelineOverlayItemsUpdate(
                layers: const <Layer>[],
                filters: const <FilterState>[],
                audioTracks: [originalTrack],
                totalVideoDuration: const Duration(seconds: 3),
              ),
            );
          }
          await deliverBlocStates(tester);
          await tester.pump();
          expect(identical(probe.live.value, live), isTrue);
          expect(probe.accepted, 0);
          await gesture.up();
          await deliverBlocStates(tester);
          expect(
            isClip
                ? clips.state.clips.single.volume
                : overlays.state.audioTracks.single.volume,
            live.volume,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testVolume('removed target clears without restoring an invented gain', (
      tester,
    ) async {
      await mount(tester);
      final gesture = await drag(tester);
      await settlePlayer(tester);
      final calls = probe.player.sent.length;
      expect(calls, greaterThan(0));
      clips.add(const ClipEditorClipRemoved('clip-a'));
      await deliverBlocStates(tester);
      await tester.pumpAndSettle();
      expect(clips.state.clips, isEmpty);
      expect(find.bySemanticsLabel('Clip 1'), findsNothing);
      expect(probe.live.value, isNull);
      expect(probe.header.value, isNull);
      expect(probe.player.sent, hasLength(calls));
      expect(probe.accepted, 1);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testVolume('header disposal restores a surviving live owner', (
      tester,
    ) async {
      await mount(tester);
      final gesture = await drag(tester);
      ownerKey.currentState!.showHeader.value = false;
      await tester.pump();
      await tester.pump();
      await settlePlayer(tester);
      expect(probe.headerDisposed, isTrue);
      expect(probe.liveDisposed, isFalse);
      restored(1);
      expect(probe.headerWrites, 0);
      expect(clips.state.clipsVolumeRevision, 0);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testVolume('whole-owner disposal never writes disposed notifiers', (
      tester,
    ) async {
      await mount(tester);
      final gesture = await drag(tester);
      final writes = probe.values.length;
      expect(writes, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(probe.liveDisposed, isTrue);
      expect(probe.headerDisposed, isTrue);
      expect(probe.ignoredAfterUnmount, 1);
      expect(probe.values, hasLength(writes));
      expect(probe.accepted, 0);
      expect(probe.headerWrites, 0);
      await gesture.up();
      await tester.pump();
      expect(clips.state.clipsVolumeRevision, 0);
      expect(tester.takeException(), isNull);
    });

    testVolume('disposal restoration follows an already in-flight boost', (
      tester,
    ) async {
      await mount(tester);
      final gesture = await drag(tester, boost: false);
      await settlePlayer(tester);
      final barrier = Completer<void>();
      try {
        probe.player.blockNext = barrier;
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(probe.player.sent.last.volume, greaterThan(1));
        main.add(const VideoEditorVolumeEditModeToggled());
        await deliverBlocStates(tester);
        await tester.pumpAndSettle();
        expect(probe.live.value, isNull);
        expect(probe.values[probe.values.length - 2]?.volume, 1);
        expect(probe.values.last, isNull);
        barrier.complete();
        await settlePlayer(tester);
        restored(1);
        await gesture.up();
        expect(clips.state.clipsVolumeRevision, 0);
        expect(tester.takeException(), isNull);
      } finally {
        if (!barrier.isCompleted) barrier.complete();
        await settlePlayer(tester);
      }
    });
  });
}

// Mirrors the independently owned screen/live and timeline/header lifetimes.
class _LiveOwner extends StatefulWidget {
  const _LiveOwner({
    required this.clips,
    required this.overlays,
    required this.probe,
    super.key,
  });
  final ClipEditorBloc clips;
  final TimelineOverlayBloc overlays;
  final _Probe probe;
  @override
  State<_LiveOwner> createState() => _LiveOwnerState();
}

class _LiveOwnerState extends State<_LiveOwner> {
  final live = ValueNotifier<LiveVolume?>(null);
  final ValueNotifier<bool> showHeader = ValueNotifier(true);
  final ValueNotifier<Size> bodySize = ValueNotifier(Size.zero);
  final ValueNotifier<Matrix4> zoom = ValueNotifier(Matrix4.identity());
  final ValueNotifier<Duration> playTime = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> advancing = ValueNotifier(false);
  @override
  void initState() {
    super.initState();
    widget.probe.live = live;
    live.addListener(_record);
  }

  void _record() {
    widget.probe.values.add(live.value);
    if (live.value case final value?) widget.probe.player.offer(value);
  }

  bool _cancel(LiveVolume expected) {
    if (!mounted) {
      widget.probe.ignoredAfterUnmount++;
      return false;
    }
    final cancelled = cancelLiveVolumePreview(
      expected: expected,
      notifier: live,
      clipState: widget.clips.state,
      overlayState: widget.overlays.state,
    );
    if (cancelled) widget.probe.accepted++;
    return cancelled;
  }

  @override
  void dispose() {
    widget.probe.liveDisposed = true;
    live.dispose();
    showHeader.dispose();
    bodySize.dispose();
    zoom.dispose();
    playTime.dispose();
    advancing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VideoEditorScope(
    editorKey: GlobalKey<ProImageEditorState>(),
    removeAreaKey: GlobalKey(),
    onAddStickers: () {},
    onOpenCamera: () {},
    onOpenClipsEditor: () {},
    onAddEditTextLayer: ([_]) async => null,
    onOpenMusicLibrary: () {},
    onOpenVoiceOver: () {},
    onOpenCaptions: () {},
    onOpenEffects: () {},
    originalClipAspectRatio: 9 / 16,
    bodySizeNotifier: bodySize,
    zoomMatrixNotifier: zoom,
    playTimeNotifier: playTime,
    playheadAdvancingNotifier: advancing,
    fromLibrary: false,
    liveVolumeNotifier: live,
    cancelLiveVolumePreview: _cancel,
    child: ValueListenableBuilder<bool>(
      valueListenable: showHeader,
      builder: (context, show, _) =>
          show ? _HeaderOwner(probe: widget.probe) : const SizedBox.shrink(),
    ),
  );
}

class _HeaderOwner extends StatefulWidget {
  const _HeaderOwner({required this.probe});
  final _Probe probe;
  @override
  State<_HeaderOwner> createState() => _HeaderOwnerState();
}

class _HeaderOwnerState extends State<_HeaderOwner> {
  final header = ValueNotifier<double?>(null);
  bool Function(LiveVolume)? _cancelLive;
  @override
  void initState() {
    super.initState();
    widget.probe.header = header;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cancelLive = VideoEditorScope.of(context).cancelLiveVolumePreview;
  }

  void _cancel(LiveVolume expected) {
    if (!(_cancelLive?.call(expected) ?? false)) return;
    if (mounted) {
      widget.probe.headerWrites++;
      header.value = null;
    }
  }

  @override
  void dispose() {
    widget.probe.headerDisposed = true;
    header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ValueListenableBuilder<double?>(
        valueListenable: header,
        builder: (context, value, _) => Text('$value'),
      ),
      Expanded(
        child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
          builder: (context, state) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: state.isVolumeEditMode
                ? VideoEditorTimelineVolume(
                    key: const ValueKey('volume'),
                    volumePreviewNotifier: header,
                    liveVolumeNotifier: VideoEditorScope.of(context)
                        .liveVolumeNotifier,
                    onPreviewCancelled: _cancel,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
    ],
  );
}

class _Probe {
  late ValueNotifier<LiveVolume?> live;
  late ValueNotifier<double?> header;
  final values = <LiveVolume?>[];
  final player = _RecordingPlayer();
  int accepted = 0;
  int ignoredAfterUnmount = 0;
  int headerWrites = 0;
  bool liveDisposed = false;
  bool headerDisposed = false;
}

// Models the canvas's non-null serialized queue. This tests callback ordering,
// not execution of the real canvas or native DSP.
class _RecordingPlayer {
  final sent = <LiveVolume>[];
  double? lastAppliedGain;
  Completer<void>? blockNext;
  LiveVolume? _queued;
  bool _applying = false;
  bool get isIdle => !_applying && _queued == null;
  void offer(LiveVolume value) {
    _queued = value;
    if (!_applying) unawaited(_drain());
  }

  Future<void> _drain() async {
    _applying = true;
    try {
      while (_queued != null) {
        final value = _queued!;
        _queued = null;
        sent.add(value);
        final barrier = blockNext;
        blockNext = null;
        if (barrier != null) await barrier.future;
        lastAppliedGain = value.volume;
      }
    } finally {
      _applying = false;
    }
  }
}
