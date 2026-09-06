// ABOUTME: Bottom-sheet picker for the transition between two adjacent clips.
// ABOUTME: Shows looped previews on the real neighbour frames + duration/curve.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationCurve,
        ClipTransition,
        ClipTransitionDirection,
        ClipTransitionType;

/// Inclusive bounds (and snap step) for the duration slider, in milliseconds.
/// Steps in 0.01s (10ms) for fine control. The applied transition is
/// additionally clamped to the clip length at render time, so the upper bound
/// here is only the UI ceiling.
const _minDurationMs = 10;
const _maxDurationMs = 2000;
const _durationStepMs = 10;

/// Directions offered for direction-aware transitions (slide/push/wipe).
const _directionOptions = <ClipTransitionDirection>[
  ClipTransitionDirection.left,
  ClipTransitionDirection.right,
  ClipTransitionDirection.up,
  ClipTransitionDirection.down,
];

/// Transition types whose effect depends on [ClipTransitionDirection].
const _directionalTypes = <ClipTransitionType>{
  ClipTransitionType.slide,
  ClipTransitionType.push,
  ClipTransitionType.wipe,
};

const _previewWidth = 64.0;
const _previewHeight = 84.0;

/// Total preview loop length, in milliseconds. The transition itself occupies
/// the middle `_duration` slice of every loop (so the preview literally plays
/// over the chosen duration), with the remaining time split into a lead/tail
/// hold on the first/last frame. Kept above the duration ceiling so even the
/// longest transition still shows a hold.
const _loopMs = 2800;

/// Opens the transition picker for the boundary between clip [leftClipIndex]
/// and the following clip, then applies the choice to that clip's
/// [DivineVideoClip.transition] through the editor history.
///
/// A transition describes how a clip flows **into the next** clip, so the
/// boundary is identified by its left clip; the last clip has no internal
/// boundary — see [editLoopTransition] for its loop-restart wrap.
Future<void> editClipTransition(BuildContext context, int leftClipIndex) async {
  final clips = context.read<ClipEditorBloc>().state.clips;
  if (leftClipIndex < 0 || leftClipIndex >= clips.length - 1) return;

  final clip = clips[leftClipIndex];
  final nextClip = clips[leftClipIndex + 1];

  final boundaryShorter = clip.playbackDuration < nextClip.playbackDuration
      ? clip.playbackDuration
      : nextClip.playbackDuration;

  await _showTransitionSheet(
    context,
    // A transition runs at the boundary: clip A's tail into clip B's head.
    fromClip: clip,
    toClip: nextClip,
    editedClip: clip,
    roomPerSide: _roomPerSide(clips, leftClipIndex),
    unconstrainedRoom: boundaryShorter,
    title: context.l10n.videoEditorTransitionSheetTitle,
  );
}

/// Opens the transition picker for the **loop-restart wrap** — the seam where
/// the last clip's tail dissolves into the first clip's head so a looping
/// player restarts seamlessly (`pro_video_editor` ≥ 2.5) — then applies the
/// choice to the last clip's [DivineVideoClip.transition].
///
/// On a single-clip timeline the last and first clip are the same, so the wrap
/// blends that clip's end into its own beginning.
Future<void> editLoopTransition(BuildContext context) async {
  final clips = context.read<ClipEditorBloc>().state.clips;
  if (clips.isEmpty) return;

  final lastClip = clips.last;
  final firstClip = clips.first;
  final roomPerSide = loopTransitionRoomPerSide(clips);

  // The room the neighbours can't constrain: on a single clip the head and
  // tail split it (half each — identical to [roomPerSide], since a lone clip
  // has no internal transitions); otherwise the shorter of the joined clips.
  final unconstrainedRoom = clips.length == 1
      ? roomPerSide
      : (lastClip.playbackDuration < firstClip.playbackDuration
            ? lastClip.playbackDuration
            : firstClip.playbackDuration);

  await _showTransitionSheet(
    context,
    // The wrap seam: the last clip's tail into the first clip's head.
    fromClip: lastClip,
    toClip: firstClip,
    editedClip: lastClip,
    roomPerSide: roomPerSide,
    unconstrainedRoom: unconstrainedRoom,
    title: context.l10n.videoEditorLoopTransitionSheetTitle,
  );
}

/// Shared picker: previews [fromClip]'s tail flowing into [toClip]'s head, then
/// applies the chosen transition to [editedClip] through the editor history.
///
/// [roomPerSide] is the per-side playback room the transition may consume after
/// the adjacent clips' own transitions; [unconstrainedRoom] is that room before
/// any neighbour reduced it, so the picker can hint when it was limited.
Future<void> _showTransitionSheet(
  BuildContext context, {
  required DivineVideoClip fromClip,
  required DivineVideoClip toClip,
  required DivineVideoClip editedClip,
  required Duration roomPerSide,
  required Duration unconstrainedRoom,
  required String title,
}) async {
  final bloc = context.read<ClipEditorBloc>();
  final editor = VideoEditorScope.of(context).requireEditor;

  final result = await VineBottomSheet.show<({ClipTransition? transition})>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    title: Text(
      title,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    body: BlocProvider<TransitionBoundaryCubit>(
      // The cubit shows the outgoing clip's ghost frame and the incoming clip's
      // thumbnail immediately, then swaps in the exact boundary frames (the
      // outgoing clip at trimEnd, the incoming at trimStart) as they extract.
      create: (_) => TransitionBoundaryCubit(
        fromClip: fromClip,
        toClip: toClip,
        fromPlaceholder: fromClip.ghostFramePath ?? fromClip.thumbnailPath,
        toPlaceholder: toClip.thumbnailPath,
      ),
      child: TransitionPickerView(
        // Overlaps blend both clips at once (so cap at half the room); dips fade
        // out then in (so up to twice it). The room already excludes what the
        // adjacent clips' own transitions consume, so two transitions never
        // over-consume a shared clip — which the native compositor can't render.
        overlapMaxMs: _snapDurationMs(
          transitionDurationForConsumed(
            roomPerSide,
            ClipTransitionType.dissolve,
          ).inMilliseconds,
        ),
        dipMaxMs: _snapDurationMs(
          transitionDurationForConsumed(
            roomPerSide,
            ClipTransitionType.fadeToBlack,
          ).inMilliseconds,
        ),
        limitedByNeighbor: roomPerSide < unconstrainedRoom,
        initial: editedClip.transition,
      ),
    ),
  );

  if (result == null || !context.mounted) return;

  final newTransition = result.transition;
  // Re-selecting the current transition is a no-op — avoid a redundant history
  // entry.
  if (newTransition == editedClip.transition) return;

  final updated = editedClip.copyWith(
    transition: newTransition,
    clearTransition: newTransition == null,
  );
  final newClips = bloc.state.clips
      .map((c) => c.id == editedClip.id ? updated : c)
      .toList();

  bloc.add(ClipEditorClipUpdated(clipId: editedClip.id, clip: updated));
  editor.setClipState(newClips);
}

/// The per-side playback room a transition at the boundary after
/// [leftClipIndex] may consume, after the adjacent clips' own transitions have
/// taken their share. The left clip's tail must also leave room for its
/// incoming transition; the right clip's head for its outgoing one — so a clip
/// is never consumed by transitions on both sides at once (which the native
/// compositor can't render). With no neighbouring transitions this is just the
/// shorter of the two clips.
Duration _roomPerSide(List<DivineVideoClip> clips, int leftClipIndex) {
  final clip = clips[leftClipIndex];
  final nextClip = clips[leftClipIndex + 1];
  final prevClip = leftClipIndex > 0 ? clips[leftClipIndex - 1] : null;
  final afterNextClip = leftClipIndex + 2 < clips.length
      ? clips[leftClipIndex + 2]
      : null;

  var clipTailRoom = clip.playbackDuration;
  final prevTransition = prevClip?.transition;
  if (prevClip != null && prevTransition != null) {
    clipTailRoom -= transitionConsumedPerSide(
      prevClip.playbackDuration,
      clip.playbackDuration,
      prevTransition,
    );
  }

  var nextHeadRoom = nextClip.playbackDuration;
  final nextTransition = nextClip.transition;
  if (afterNextClip != null && nextTransition != null) {
    nextHeadRoom -= transitionConsumedPerSide(
      nextClip.playbackDuration,
      afterNextClip.playbackDuration,
      nextTransition,
    );
  }

  final room = clipTailRoom < nextHeadRoom ? clipTailRoom : nextHeadRoom;
  return room.isNegative ? Duration.zero : room;
}

/// Snaps [ms] down to the slider's step grid and into its valid range, so every
/// division lands on a clean 0.01s value (an off-grid max makes the slider
/// interpolate ugly intermediate steps).
int _snapDurationMs(int ms) => ((ms ~/ _durationStepMs) * _durationStepMs)
    .clamp(_minDurationMs, _maxDurationMs);

/// Stateful picker body: a row of looped transition previews plus duration and
/// curve controls. Pops `(transition:)` on confirm.
@visibleForTesting
class TransitionPickerView extends StatefulWidget {
  const TransitionPickerView({
    required this.initial,
    this.overlapMaxMs = _maxDurationMs,
    this.dipMaxMs = _maxDurationMs,
    this.limitedByNeighbor = false,
    super.key,
  });

  /// Duration-slider ceilings for the two transition families. An overlap
  /// (dissolve/slide/push/wipe) blends both clips at once, so it's capped at
  /// half the available per-side room; a dip (fadeToBlack/White) fades out then
  /// in, so it can run up to twice it. The room already excludes what the
  /// adjacent clips' own transitions consume, so two transitions never overlap
  /// on a shared clip. The render path clamps to the same budget. Default to
  /// [_maxDurationMs] in tests.
  final int overlapMaxMs;
  final int dipMaxMs;

  /// Whether the ceilings above were reduced because an adjacent clip already
  /// has a transition that uses part of the shared clip. Drives the hint shown
  /// under the duration slider.
  final bool limitedByNeighbor;

  final ClipTransition? initial;

  @override
  State<TransitionPickerView> createState() => _TransitionPickerViewState();
}

class _TransitionPickerViewState extends State<TransitionPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ClipTransitionType? _type;
  Duration _duration = const Duration(milliseconds: 500);
  AnimationCurve _curve = AnimationCurve.linear;
  ClipTransitionDirection _direction = ClipTransitionDirection.left;

  static const _options = <ClipTransitionType?>[
    null,
    ClipTransitionType.dissolve,
    ClipTransitionType.fadeToBlack,
    ClipTransitionType.fadeToWhite,
    ClipTransitionType.slide,
    ClipTransitionType.push,
    ClipTransitionType.wipe,
  ];

  /// Dip transitions fade out then in (no simultaneous blend), so they may run
  /// up to twice the shorter clip; overlaps blend both at once and cap at half.
  bool _isDip(ClipTransitionType? type) =>
      type == ClipTransitionType.fadeToBlack ||
      type == ClipTransitionType.fadeToWhite;

  /// The duration-slider ceiling for the currently selected type.
  int get _currentMaxMs =>
      _isDip(_type) ? widget.dipMaxMs : widget.overlapMaxMs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type;
    _duration = Duration(
      milliseconds: (initial?.duration ?? _duration).inMilliseconds.clamp(
        _minDurationMs,
        _currentMaxMs,
      ),
    );
    _curve = initial?.curve ?? _curve;
    _direction = initial?.direction ?? _direction;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _loopMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ClipTransition? _buildTransition() {
    final type = _type;
    if (type == null) return null;
    return ClipTransition(
      type: type,
      duration: _duration,
      curve: _curve,
      direction: _direction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fromPath = context.select(
      (TransitionBoundaryCubit c) => c.state.fromFramePath,
    );
    final toPath = context.select(
      (TransitionBoundaryCubit c) => c.state.toFramePath,
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: _previewHeight + 44,
            child: ListView.separated(
              scrollDirection: .horizontal,
              padding: const .fromSTEB(16, 4, 16, 4),
              itemCount: _options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final type = _options[index];
                return _TransitionTile(
                  type: type,
                  label: _typeLabel(l10n, type),
                  selected: type == _type,
                  controller: _controller,
                  curve: _curve,
                  direction: _direction,
                  durationMs: _duration.inMilliseconds,
                  fromThumbnailPath: fromPath,
                  toThumbnailPath: toPath,
                  onTap: () => setState(() {
                    _type = type;
                    // The ceiling depends on the type (overlap vs dip); re-clamp
                    // so a dip's longer pick doesn't survive a switch to an
                    // overlap.
                    _duration = Duration(
                      milliseconds: _duration.inMilliseconds.clamp(
                        _minDurationMs,
                        _currentMaxMs,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: .topCenter,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      SectionLabel(l10n.videoEditorTransitionDuration),
                      Text(
                        _durationLabel(_duration),
                        style: VineTheme.labelSmallFont(
                          color: context.vineColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  if (_currentMaxMs > _minDurationMs) ...[
                    const SizedBox(height: 8),
                    DivineSlider(
                      value: _duration.inMilliseconds.toDouble(),
                      min: _minDurationMs.toDouble(),
                      max: _currentMaxMs.toDouble(),
                      divisions:
                          ((_currentMaxMs - _minDurationMs) ~/ _durationStepMs)
                              .clamp(1, 1 << 20),
                      onChanged: (value) => setState(
                        () => _duration = Duration(milliseconds: value.round()),
                      ),
                    ),
                  ],
                  if (widget.limitedByNeighbor && _type != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.videoEditorTransitionDurationLimitedHint,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SectionLabel(l10n.videoEditorTransitionCurve),
                  const SizedBox(height: 8),
                  CurvePickerRow(
                    selected: _curve,
                    onChanged: (curve) => setState(() => _curve = curve),
                  ),
                  if (_directionalTypes.contains(_type)) ...[
                    const SizedBox(height: 16),
                    SectionLabel(l10n.videoEditorTransitionDirection),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 8,
                      children: [
                        for (final direction in _directionOptions)
                          AnimationPickerChip(
                            selected: direction == _direction,
                            onTap: () => setState(() => _direction = direction),
                            semanticLabel: _directionLabel(l10n, direction),
                            child: DivineIcon(
                              icon: _directionIcon(direction),
                              size: 18,
                              color: direction == _direction
                                  ? context.vineColors.accentBrand
                                  : context.vineColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: DivineButton(
              label: l10n.videoEditorDoneLabel,
              onPressed: () =>
                  Navigator.of(context).pop((transition: _buildTransition())),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// One transition option: a looped preview over the real neighbour frames with
/// a label, highlighted when [selected].
class _TransitionTile extends StatelessWidget {
  const _TransitionTile({
    required this.type,
    required this.label,
    required this.selected,
    required this.controller,
    required this.curve,
    required this.direction,
    required this.durationMs,
    required this.fromThumbnailPath,
    required this.toThumbnailPath,
    required this.onTap,
  });

  final ClipTransitionType? type;
  final String label;
  final bool selected;
  final AnimationController controller;
  final AnimationCurve curve;
  final ClipTransitionDirection direction;
  final int durationMs;
  final String? fromThumbnailPath;
  final String? toThumbnailPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fromFrame = _PreviewFrame(
      path: fromThumbnailPath,
      fallback: [
        context.vineColors.primaryContainer,
        context.vineColors.surface,
      ],
    );
    final toFrame = _PreviewFrame(
      path: toThumbnailPath,
      fallback: [
        context.vineColors.card,
        context.vineColors.surfaceContainerHigh,
      ],
    );
    // Merge the explicit button node with the GestureDetector's tap action into
    // one node, and exclude the visible Text below from semantics so its label
    // isn't concatenated onto the explicit one — otherwise the screen reader
    // announces "label\nlabel".
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: .opaque,
          child: Column(
            spacing: 6,
            mainAxisSize: .min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? context.vineColors.accentBrand
                        : context.vineColors.controlOutline,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => _TransitionEffect(
                          type: type,
                          direction: direction,
                          progress: flutterCurveFor(curve).transform(
                            _holdProgress(controller.value, durationMs),
                          ),
                          from: fromFrame,
                          to: toFrame,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: VineTheme.labelSmallFont(
                    color: selected
                        ? context.vineColors.accentBrand
                        : context.vineColors.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders [from] transitioning into [to] at [progress] (0..1) for [type].
class _TransitionEffect extends StatelessWidget {
  const _TransitionEffect({
    required this.type,
    required this.direction,
    required this.progress,
    required this.from,
    required this.to,
  });

  final ClipTransitionType? type;
  final ClipTransitionDirection direction;
  final double progress;
  final Widget from;
  final Widget to;

  @override
  Widget build(BuildContext context) {
    // Elastic/bounce curves overshoot outside 0..1: opacity, the dip overlay
    // and the wipe factor must stay in range, while translate offsets keep the
    // raw value so the spring stays visible.
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: _previewWidth,
      height: _previewHeight,
      child: switch (type) {
        // Hard cut: snap from the first to the second frame at the midpoint.
        null => clamped < 0.5 ? from : to,
        ClipTransitionType.dissolve => Stack(
          fit: .expand,
          children: [
            from,
            Opacity(opacity: clamped, child: to),
          ],
        ),
        // These name the rendered effect, not a surface: a "fade to black"
        // has to dip to black and a "fade to white" to white, whatever the
        // appearance mode is.
        ClipTransitionType.fadeToBlack => _dip(
          VineTheme.backgroundColor,
          clamped,
        ),
        ClipTransitionType.fadeToWhite => _dip(VineTheme.whiteText, clamped),
        ClipTransitionType.slide => Stack(
          fit: .expand,
          children: [
            from,
            Transform.translate(offset: _enter, child: to),
          ],
        ),
        ClipTransitionType.push => Stack(
          fit: .expand,
          children: [
            Transform.translate(offset: _exit, child: from),
            Transform.translate(offset: _enter, child: to),
          ],
        ),
        ClipTransitionType.wipe => Stack(
          fit: .expand,
          children: [from, _wipe(clamped)],
        ),
      },
    );
  }

  Widget _dip(Color color, double p) {
    final overlay = p < 0.5 ? p * 2 : (1 - p) * 2;
    return Stack(
      fit: .expand,
      children: [
        if (p < 0.5) from else to,
        Positioned.fill(
          child: ColoredBox(color: color.withValues(alpha: overlay)),
        ),
      ],
    );
  }

  Offset get _enter => switch (direction) {
    ClipTransitionDirection.left => Offset((1 - progress) * _previewWidth, 0),
    ClipTransitionDirection.right => Offset(-(1 - progress) * _previewWidth, 0),
    ClipTransitionDirection.up => Offset(0, (1 - progress) * _previewHeight),
    ClipTransitionDirection.down => Offset(0, -(1 - progress) * _previewHeight),
  };

  Offset get _exit => switch (direction) {
    ClipTransitionDirection.left => Offset(-progress * _previewWidth, 0),
    ClipTransitionDirection.right => Offset(progress * _previewWidth, 0),
    ClipTransitionDirection.up => Offset(0, -progress * _previewHeight),
    ClipTransitionDirection.down => Offset(0, progress * _previewHeight),
  };

  // A widthFactor/heightFactor Align can't drive the reveal here: under the
  // enclosing StackFit.expand the clip is force-sized to fill, so the factor is
  // ignored. Clip an explicit rect that grows with progress instead.
  Widget _wipe(double p) => ClipRect(
    clipper: _WipeClipper(progress: p, direction: direction),
    child: SizedBox(width: _previewWidth, height: _previewHeight, child: to),
  );
}

/// Reveals the incoming frame over a rectangle that grows with [progress],
/// with the wipe edge moving in [direction].
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper({required this.progress, required this.direction});

  final double progress;
  final ClipTransitionDirection direction;

  @override
  Rect getClip(Size size) => switch (direction) {
    ClipTransitionDirection.right => Rect.fromLTWH(
      0,
      0,
      size.width * progress,
      size.height,
    ),
    ClipTransitionDirection.left => Rect.fromLTWH(
      size.width * (1 - progress),
      0,
      size.width * progress,
      size.height,
    ),
    ClipTransitionDirection.down => Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height * progress,
    ),
    ClipTransitionDirection.up => Rect.fromLTWH(
      0,
      size.height * (1 - progress),
      size.width,
      size.height * progress,
    ),
  };

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.direction != direction;
}

/// A single preview frame backed by a clip thumbnail, or a gradient fallback
/// when the thumbnail is missing/unreadable.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.path, required this.fallback});

  final String? path;
  final List<Color> fallback;

  @override
  Widget build(BuildContext context) {
    final fallbackBox = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fallback,
        ),
      ),
      child: const SizedBox.expand(),
    );
    final filePath = path;
    if (filePath == null) return fallbackBox;
    return Image.file(
      File(filePath),
      width: _previewWidth,
      height: _previewHeight,
      fit: .cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallbackBox,
    );
  }
}

/// Maps the controller's loop position (0..1) to a held 0..1 transition ramp.
///
/// The middle `durationMs` slice of the [_loopMs] loop is the transition; the
/// remaining time is split into a lead/tail hold on the first/last frame. This
/// makes the preview play the transition over exactly the chosen duration while
/// still pausing on each clip between loops.
double _holdProgress(double value, int durationMs) {
  final transition = durationMs.clamp(0, _loopMs) / _loopMs;
  final start = (1 - transition) / 2;
  final end = start + transition;
  if (transition <= 0 || value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}

String _directionLabel(
  AppLocalizations l10n,
  ClipTransitionDirection direction,
) => switch (direction) {
  ClipTransitionDirection.left => l10n.videoEditorTransitionDirectionLeft,
  ClipTransitionDirection.right => l10n.videoEditorTransitionDirectionRight,
  ClipTransitionDirection.up => l10n.videoEditorTransitionDirectionUp,
  ClipTransitionDirection.down => l10n.videoEditorTransitionDirectionDown,
};

DivineIconName _directionIcon(ClipTransitionDirection direction) =>
    switch (direction) {
      ClipTransitionDirection.left => DivineIconName.arrowLeft,
      ClipTransitionDirection.right => DivineIconName.arrowRight,
      ClipTransitionDirection.up => DivineIconName.arrowUp,
      ClipTransitionDirection.down => DivineIconName.arrowDown,
    };

String _durationLabel(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';

String _typeLabel(AppLocalizations l10n, ClipTransitionType? type) =>
    switch (type) {
      null => l10n.videoEditorTransitionNone,
      ClipTransitionType.dissolve => l10n.videoEditorTransitionDissolve,
      ClipTransitionType.fadeToBlack => l10n.videoEditorTransitionFadeToBlack,
      ClipTransitionType.fadeToWhite => l10n.videoEditorTransitionFadeToWhite,
      ClipTransitionType.slide => l10n.videoEditorTransitionSlide,
      ClipTransitionType.push => l10n.videoEditorTransitionPush,
      ClipTransitionType.wipe => l10n.videoEditorTransitionWipe,
    };
