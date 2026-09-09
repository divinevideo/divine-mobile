// ABOUTME: Bottom-sheet picker for a layer's enter/leave animation (fade,
// ABOUTME: slide, scale) — twin of the clip-transition sheet, shared controls.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/layer_slide_direction.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationCurve,
        AnimationPhase,
        LayerAnimation,
        LayerAnimationType,
        SlideDirection;

/// Inclusive bounds (and snap step) for the duration slider, in milliseconds.
const _minDurationMs = 10;
const _maxDurationMs = 2000;
const _durationStepMs = 10;

/// Default duration applied when a type is first picked for a phase.
const _defaultDuration = Duration(milliseconds: 400);

/// Preview loop length; the animation occupies the middle slice (see
/// [_holdProgress]).
const _loopMs = 2400;

const _previewWidth = 56.0;
const _previewHeight = 72.0;

/// Directions offered for a slide animation, laid out as a 3x3 pad: the eight
/// compass directions around an empty centre. `null` is that empty cell.
///
/// A pad rather than a row of chips because eight of them no longer fit one
/// line, and because the arrangement itself tells you which chip is which —
/// the arrow glyph and the cell position agree.
const _slideDirectionPad = <List<LayerSlideDirection?>>[
  [
    LayerSlideDirection.upLeft,
    LayerSlideDirection.up,
    LayerSlideDirection.upRight,
  ],
  [LayerSlideDirection.left, null, LayerSlideDirection.right],
  [
    LayerSlideDirection.downLeft,
    LayerSlideDirection.down,
    LayerSlideDirection.downRight,
  ],
];

/// Icon side inside a direction chip, and the horizontal padding
/// [AnimationPickerChip] adds around it. Together they size the pad's empty
/// centre cell so the columns stay aligned at every text scale.
const _directionIconSize = 18.0;
const _directionChipPadding = 28.0;
const _directionChipMinSide = 48.0;

/// Opens the enter/leave animation picker for [layer] and applies the choice to
/// that layer through the editor history.
///
/// A layer carries one enter and one leave *motion*; each is stored on
/// [Layer.animations] as the effects it composes — a fade, a slide and a scale
/// can run together, and a diagonal slide contributes one animation per axis
/// (see [LayerSlideDirection]). pro_image_editor drives the in-editor timeline
/// preview from that list, and the export maps it to pro_video_editor.
///
/// [totalDuration] is the true total video duration — independent of the
/// layer's own [Layer.endTime]. It both anchors the leave animation and lets
/// [resolveLayerEndTime] tell a genuine trim from a stale full-length anchor.
/// It must NOT be the layer's clamped timeline end (which equals its
/// [Layer.endTime]), or every trim reads as full-length and gets dropped.
Future<void> editLayerAnimation(
  BuildContext context,
  Layer layer, {
  required Duration totalDuration,
}) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;

  final result = await VineBottomSheet.show<_LayerAnimationResult>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    title: Text(
      context.l10n.videoEditorLayerAnimationLabel,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    body: LayerAnimationPickerView(
      initialEnter: layer.divineEnterAnimations,
      initialLeave: layer.divineLeaveAnimations,
    ),
  );

  if (result == null || !context.mounted) return;

  final layers = List<Layer>.from(editor.activeLayers);
  final index = layers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;

  // Carry through any animations the picker doesn't model — phases other than
  // enter/leave (e.g. animateInOut) — so editing one phase can't silently drop
  // them.
  final preserved = [
    for (final animation in layer.divineAnimations)
      if (animation.phase != AnimationPhase.animateIn &&
          animation.phase != AnimationPhase.animateOut)
        animation,
  ];
  final animations = <LayerAnimation>[
    ...result.enter,
    ...result.leave,
    ...preserved,
  ];

  final endTime = resolveLayerEndTime(
    currentEndTime: layer.endTime,
    startTime: layer.startTime ?? Duration.zero,
    totalDuration: totalDuration,
    hasLeaveAnimation: result.leave.isNotEmpty,
  );

  // Drive the layer entirely from the typed animations; clear the legacy fade
  // fields / custom builder so [Layer.effectiveAnimations] can't fall back to a
  // stale fade when the animations list is empty.
  //
  // endTime is set via the mutable field rather than copyWith: Layer.copyWith
  // resolves it as `endTime ?? this.endTime`, so it can't clear a stale end
  // back to null — which resolveLayerEndTime returns to un-anchor a layer.
  layers[index] = layer.copyWith(animations: animations.toLayerAnimations())
    ..endTime = endTime
    ..enterDuration = null
    ..exitDuration = null
    ..enterCurve = null
    ..exitCurve = null
    ..transitionBuilder = null;

  editor.addHistory(layers: layers);
}

/// Resolves the [Layer.endTime] needed for a leave (animateOut) animation to
/// have a window to play in.
///
/// The leave phase renders only when the layer has a non-null `endTime` — both
/// the in-editor preview ([Layer.animations] timeline visibility) and the
/// native export skip the animateOut branch when `endTime` is null.
///
/// Only a *real trim* — an end strictly inside the video — is treated as user
/// intent worth preserving. An end at or after [totalDuration] is not a trim:
/// it's either a stale anchor a previously-set (now-removed) leave animation
/// left behind, or a no-op full-length end. Treating it as `null` keeps an
/// untrimmed layer untrimmed, so it follows later duration changes (e.g. the
/// video being extended) instead of staying pinned to a stale end.
///
/// [totalDuration] must be the true total video duration, independent of the
/// layer's own [Layer.endTime]. Passing the layer's clamped timeline end (which
/// equals its [Layer.endTime]) would make `currentEndTime < totalDuration` false
/// for every trim, so genuine trims would read as full-length and be dropped.
///
/// [startTime] is the layer's own start. The returned end is never at or before
/// it: a stale or transient-zero [totalDuration] (e.g. read before the player
/// has reported its length) must not anchor the leave window at `<= startTime`,
/// which would collapse the layer to a zero-length window and drop it from the
/// timeline entirely. In that degenerate case the layer's existing end is kept
/// (when still valid) or the end is left un-anchored — the layer stays visible
/// either way.
///
/// With [hasLeaveAnimation] true the end is anchored to that trim, or to
/// [totalDuration] when there is no real trim — never beyond the video, never
/// at or before [startTime]. Without a leave animation a real trim is preserved
/// and everything else collapses to `null`.
@visibleForTesting
Duration? resolveLayerEndTime({
  required Duration? currentEndTime,
  required Duration startTime,
  required Duration totalDuration,
  required bool hasLeaveAnimation,
}) {
  final trim = currentEndTime != null && currentEndTime < totalDuration
      ? currentEndTime
      : null;
  if (!hasLeaveAnimation) return trim;

  final anchor = trim ?? totalDuration;
  if (anchor > startTime) return anchor;
  if (currentEndTime != null && currentEndTime > startTime) {
    return currentEndTime;
  }
  return null;
}

/// The picker's result: the chosen enter and leave animations. A phase can
/// carry several composed effects (e.g. fade + slide); an empty list means no
/// animation for that phase.
typedef _LayerAnimationResult = ({
  List<LayerAnimation> enter,
  List<LayerAnimation> leave,
});

/// Stateful picker body. Edits the enter and leave animations independently via
/// an Enter|Leave toggle; pops a [_LayerAnimationResult] on confirm.
@visibleForTesting
class LayerAnimationPickerView extends StatefulWidget {
  const LayerAnimationPickerView({
    required this.initialEnter,
    required this.initialLeave,
    this.maxDurationMs = _maxDurationMs,
    super.key,
  });

  final List<LayerAnimation> initialEnter;
  final List<LayerAnimation> initialLeave;
  final int maxDurationMs;

  @override
  State<LayerAnimationPickerView> createState() =>
      _LayerAnimationPickerViewState();
}

class _LayerAnimationPickerViewState extends State<LayerAnimationPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  AnimationPhase _phase = AnimationPhase.animateIn;

  late _PhaseConfig _enter;
  late _PhaseConfig _leave;

  /// Tiles shown in the type row. `null` is the "None" tile (clears the phase).
  static const _typeOptions = <LayerAnimationType?>[
    null,
    LayerAnimationType.fade,
    LayerAnimationType.slide,
    LayerAnimationType.scale,
  ];

  /// Stable order in which selected effects are emitted so composition
  /// (fade → slide → scale) is deterministic.
  static const _composableTypes = <LayerAnimationType>[
    LayerAnimationType.fade,
    LayerAnimationType.slide,
    LayerAnimationType.scale,
  ];

  @override
  void initState() {
    super.initState();
    _enter = _PhaseConfig.fromAnimations(widget.initialEnter);
    _leave = _PhaseConfig.fromAnimations(widget.initialLeave);
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
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _PhaseConfig get _active =>
      _phase == AnimationPhase.animateIn ? _enter : _leave;

  void _updateActive(_PhaseConfig Function(_PhaseConfig) update) {
    setState(() {
      if (_phase == AnimationPhase.animateIn) {
        _enter = update(_enter);
      } else {
        _leave = update(_leave);
      }
    });
  }

  int get _maxMs => widget.maxDurationMs;

  List<LayerAnimation> _build(_PhaseConfig config, AnimationPhase phase) => [
    for (final type in _composableTypes)
      if (config.types.contains(type)) ..._buildEffect(config, phase, type),
  ];

  /// The animations one selected effect contributes to [phase].
  ///
  /// A slide contributes one animation per axis of its direction, so a diagonal
  /// yields two — see [LayerSlideDirection]. Every other effect yields one.
  List<LayerAnimation> _buildEffect(
    _PhaseConfig config,
    AnimationPhase phase,
    LayerAnimationType type,
  ) => [
    if (type == LayerAnimationType.slide)
      for (final component in config.direction.components)
        LayerAnimation(
          type: type,
          phase: phase,
          duration: config.duration,
          curve: config.curve,
          slideDirection: component,
        )
    else
      LayerAnimation(
        type: type,
        phase: phase,
        duration: config.duration,
        curve: config.curve,
        scaleFrom: type == LayerAnimationType.scale ? config.scaleFrom : null,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = _active;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          // Controls scroll so the pinned Done button below stays reachable
          // when slide + scale are both selected on a short viewport.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const .symmetric(horizontal: 16),
                    child: _PhaseToggle(
                      phase: _phase,
                      onChanged: (phase) => setState(() => _phase = phase),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: _previewHeight + 40,
                    child: ListView.separated(
                      scrollDirection: .horizontal,
                      padding: const .fromSTEB(16, 4, 16, 4),
                      itemCount: _typeOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final type = _typeOptions[index];
                        return _LayerTypeTile(
                          type: type,
                          label: _typeLabel(l10n, type),
                          selected: type == null
                              ? active.types.isEmpty
                              : active.types.contains(type),
                          controller: _controller,
                          phase: _phase,
                          direction: active.direction,
                          scaleFrom: active.scaleFrom,
                          curve: active.curve,
                          durationMs: active.duration.inMilliseconds,
                          onTap: () => _updateActive((c) => c.toggled(type)),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const .symmetric(horizontal: 16),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: .topCenter,
                      // Duration + curve are shared by all effects in the phase and stay
                      // visible even for None so the values persist while toggling
                      // types; direction/scale-from are type-specific and appear only
                      // when slide/scale is selected.
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              SectionLabel(l10n.videoEditorTransitionDuration),
                              Text(
                                _durationLabel(active.duration),
                                style: VineTheme.labelSmallFont(
                                  color: context.vineColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DivineSlider(
                            value: active.duration.inMilliseconds
                                .clamp(_minDurationMs, _maxMs)
                                .toDouble(),
                            min: _minDurationMs.toDouble(),
                            max: _maxMs.toDouble(),
                            divisions:
                                ((_maxMs - _minDurationMs) ~/ _durationStepMs)
                                    .clamp(1, 1 << 20),
                            onChanged: (value) => _updateActive(
                              (c) => c.copyWith(
                                duration: Duration(milliseconds: value.round()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SectionLabel(l10n.videoEditorTransitionCurve),
                          const SizedBox(height: 8),
                          CurvePickerRow(
                            selected: active.curve,
                            onChanged: (curve) =>
                                _updateActive((c) => c.copyWith(curve: curve)),
                          ),
                          if (active.types.contains(
                            LayerAnimationType.slide,
                          )) ...[
                            const SizedBox(height: 16),
                            SectionLabel(l10n.videoEditorTransitionDirection),
                            const SizedBox(height: 8),
                            _SlideDirectionPad(
                              selected: active.direction,
                              onChanged: (direction) => _updateActive(
                                (c) => c.copyWith(direction: direction),
                              ),
                            ),
                          ],
                          if (active.types.contains(
                            LayerAnimationType.scale,
                          )) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: .spaceBetween,
                              children: [
                                SectionLabel(
                                  l10n.videoEditorLayerAnimationScaleFrom,
                                ),
                                Text(
                                  '${(active.scaleFrom * 100).round()}%',
                                  style: VineTheme.labelSmallFont(
                                    color: context.vineColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DivineSlider(
                              value: (active.scaleFrom * 100).clamp(0, 100),
                              max: 100,
                              divisions: 20,
                              onChanged: (value) => _updateActive(
                                (c) => c.copyWith(scaleFrom: value / 100),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: DivineButton(
              label: l10n.videoEditorDoneLabel,
              onPressed: () => Navigator.of(context).pop((
                enter: _build(_enter, AnimationPhase.animateIn),
                leave: _build(_leave, AnimationPhase.animateOut),
              )),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, LayerAnimationType? type) =>
      switch (type) {
        null => l10n.videoEditorTransitionNone,
        LayerAnimationType.fade => l10n.videoEditorLayerAnimationFade,
        LayerAnimationType.slide => l10n.videoEditorTransitionSlide,
        LayerAnimationType.scale => l10n.videoEditorLayerAnimationScale,
      };
}

/// Per-phase editable animation config.
///
/// [types] is the set of effects active for the phase — a phase can combine
/// several (e.g. fade + slide). [duration] and [curve] are shared by every
/// effect; [direction] and [scaleFrom] apply only when slide / scale is in
/// [types].
class _PhaseConfig {
  const _PhaseConfig({
    required this.types,
    required this.duration,
    required this.curve,
    required this.direction,
    required this.scaleFrom,
  });

  /// Rebuilds the config from a phase's existing animations. [duration] and
  /// [curve] come from the first animation; [scaleFrom] from the first scale
  /// animation. (The picker edits these as shared values, so per-effect
  /// differences set externally collapse on edit.)
  ///
  /// [direction] is recomposed from *every* slide animation in the phase, not
  /// just the first: a diagonal is stored as one horizontal plus one vertical
  /// slide, so reading only the first would reopen it as an edge slide and
  /// silently drop the other axis on the next save.
  factory _PhaseConfig.fromAnimations(List<LayerAnimation> animations) {
    final types = <LayerAnimationType>{};
    final slideComponents = <SlideDirection>[];
    Duration? duration;
    AnimationCurve? curve;
    double? scaleFrom;
    for (final animation in animations) {
      types.add(animation.type);
      duration ??= animation.duration;
      curve ??= animation.curve;
      if (animation.type == LayerAnimationType.slide) {
        final component = animation.slideDirection;
        if (component != null) slideComponents.add(component);
      }
      if (animation.type == LayerAnimationType.scale) {
        scaleFrom ??= animation.scaleFrom;
      }
    }
    return _PhaseConfig(
      types: types,
      duration: duration ?? _defaultDuration,
      curve: curve ?? AnimationCurve.easeOut,
      direction:
          LayerSlideDirection.fromComponents(slideComponents) ??
          LayerSlideDirection.left,
      scaleFrom: scaleFrom ?? 0.0,
    );
  }

  final Set<LayerAnimationType> types;
  final Duration duration;
  final AnimationCurve curve;
  final LayerSlideDirection direction;
  final double scaleFrom;

  /// Adds or removes [type] from [types]; a `null` [type] clears the set (None).
  _PhaseConfig toggled(LayerAnimationType? type) {
    if (type == null) return copyWith(types: const {});
    final next = Set<LayerAnimationType>.from(types);
    if (!next.add(type)) next.remove(type);
    return copyWith(types: next);
  }

  _PhaseConfig copyWith({
    Set<LayerAnimationType>? types,
    Duration? duration,
    AnimationCurve? curve,
    LayerSlideDirection? direction,
    double? scaleFrom,
  }) => _PhaseConfig(
    types: types ?? this.types,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    direction: direction ?? this.direction,
    scaleFrom: scaleFrom ?? this.scaleFrom,
  );
}

/// Enter|Leave segmented toggle.
class _PhaseToggle extends StatelessWidget {
  const _PhaseToggle({required this.phase, required this.onChanged});

  final AnimationPhase phase;
  final ValueChanged<AnimationPhase> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.controlFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.controlOutline),
      ),
      child: Row(
        children: [
          _PhaseSegment(
            label: l10n.videoEditorLayerAnimationEnter,
            selected: phase == AnimationPhase.animateIn,
            onTap: () => onChanged(AnimationPhase.animateIn),
          ),
          _PhaseSegment(
            label: l10n.videoEditorLayerAnimationLeave,
            selected: phase == AnimationPhase.animateOut,
            onTap: () => onChanged(AnimationPhase.animateOut),
          ),
        ],
      ),
    );
  }
}

class _PhaseSegment extends StatelessWidget {
  const _PhaseSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.controlSelectedFill : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.accentBrand : VineTheme.transparent,
              ),
            ),
            child: Text(
              label,
              style: VineTheme.labelMediumFont(
                color: selected ? colors.accentBrand : colors.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One layer-animation option: a looped preview of [type] on a placeholder
/// layer for the active [phase], with a label, highlighted when [selected].
class _LayerTypeTile extends StatelessWidget {
  const _LayerTypeTile({
    required this.type,
    required this.label,
    required this.selected,
    required this.controller,
    required this.phase,
    required this.direction,
    required this.scaleFrom,
    required this.curve,
    required this.durationMs,
    required this.onTap,
  });

  final LayerAnimationType? type;
  final String label;
  final bool selected;
  final AnimationController controller;
  final AnimationPhase phase;
  final LayerSlideDirection direction;
  final double scaleFrom;
  final AnimationCurve curve;
  final int durationMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
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
                    // Same unselected ring as the transition tiles and the
                    // chips in this sheet: muted in light, invisible in dark.
                    color: selected
                        ? colors.accentBrand
                        : colors.controlOutline,
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
                        builder: (context, _) => _LayerEffect(
                          type: type,
                          phase: phase,
                          direction: direction,
                          scaleFrom: scaleFrom,
                          progress: flutterCurveFor(curve).transform(
                            _holdProgress(controller.value, durationMs),
                          ),
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
                    color: selected ? colors.accentBrand : colors.mutedText,
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

/// Renders a placeholder layer with [type] applied at [progress] (0..1) for the
/// active [phase].
class _LayerEffect extends StatelessWidget {
  const _LayerEffect({
    required this.type,
    required this.phase,
    required this.direction,
    required this.scaleFrom,
    required this.progress,
  });

  final LayerAnimationType? type;
  final AnimationPhase phase;
  final LayerSlideDirection direction;
  final double scaleFrom;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Presence: 1 = fully on screen, 0 = gone. Enter ramps up, leave ramps down.
    final presence = phase == AnimationPhase.animateIn
        ? progress
        : 1 - progress;
    const layer = _PlaceholderLayer();
    return DecoratedBox(
      // Tinted backdrop (not a flat surface) so the placeholder layer reads
      // clearly against it during fade/slide/scale.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.vineColors.primaryContainer,
            context.vineColors.surface,
          ],
        ),
      ),
      child: SizedBox(
        width: _previewWidth,
        height: _previewHeight,
        child: switch (type) {
          null => const Center(child: layer),
          LayerAnimationType.fade => Center(
            child: Opacity(opacity: presence.clamp(0.0, 1.0), child: layer),
          ),
          LayerAnimationType.scale => Center(
            child: Transform.scale(
              scale: lerpDouble(scaleFrom, 1, presence) ?? 1,
              child: layer,
            ),
          ),
          LayerAnimationType.slide => Center(
            child: Transform.translate(
              offset: _previewSlideOffset(direction, 1 - presence),
              child: layer,
            ),
          ),
        },
      ),
    );
  }

  /// The placeholder's displacement at [away] (0 = at rest, 1 = fully out).
  ///
  /// Each axis is displaced independently, so a diagonal leaves past the corner
  /// — which is what the renderers do, since they sum the per-axis offsets of a
  /// diagonal's two slide animations.
  Offset _previewSlideOffset(LayerSlideDirection direction, double away) {
    final dx = switch (direction.horizontal) {
      SlideDirection.left => -away * _previewWidth,
      SlideDirection.right => away * _previewWidth,
      _ => 0.0,
    };
    final dy = switch (direction.vertical) {
      SlideDirection.top => -away * _previewHeight,
      SlideDirection.bottom => away * _previewHeight,
      _ => 0.0,
    };
    return Offset(dx, dy);
  }
}

/// The eight slide directions as a 3x3 pad of chips around an empty centre.
class _SlideDirectionPad extends StatelessWidget {
  const _SlideDirectionPad({required this.selected, required this.onChanged});

  final LayerSlideDirection selected;
  final ValueChanged<LayerSlideDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    // The chip sizes itself from its icon plus padding, with a 48dp floor, so
    // the empty centre has to follow the same formula or the pad's third column
    // shifts left once the text scale pushes a chip past that floor.
    final cellWidth = math.max(
      _directionChipMinSide,
      _directionChipPadding + DivineIcon.scaleSize(context, _directionIconSize),
    );
    return Column(
      spacing: 8,
      children: [
        for (final row in _slideDirectionPad)
          Row(
            spacing: 8,
            mainAxisSize: .min,
            children: [
              for (final direction in row)
                if (direction == null)
                  SizedBox(width: cellWidth, height: _directionChipMinSide)
                else
                  AnimationPickerChip(
                    selected: direction == selected,
                    onTap: () => onChanged(direction),
                    semanticLabel: _directionLabel(context.l10n, direction),
                    child: DivineIcon(
                      icon: _directionIcon(direction),
                      size: _directionIconSize,
                      color: direction == selected
                          ? context.vineColors.accentBrand
                          : context.vineColors.secondaryText,
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

class _PlaceholderLayer extends StatelessWidget {
  const _PlaceholderLayer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: DivineIcon(
            icon: .sparkle,
            size: 16,
            color: context.vineColors.background,
          ),
        ),
      ),
    );
  }
}

/// Maps the controller's loop position (0..1) to a held 0..1 ramp so the
/// animation plays over [durationMs] of the loop with a hold on each end.
double _holdProgress(double value, int durationMs) {
  final ratio = durationMs.clamp(0, _loopMs) / _loopMs;
  final start = (1 - ratio) / 2;
  final end = start + ratio;
  if (ratio <= 0 || value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}

String _directionLabel(
  AppLocalizations l10n,
  LayerSlideDirection direction,
) => switch (direction) {
  LayerSlideDirection.left => l10n.videoEditorTransitionDirectionLeft,
  LayerSlideDirection.right => l10n.videoEditorTransitionDirectionRight,
  LayerSlideDirection.up => l10n.videoEditorTransitionDirectionUp,
  LayerSlideDirection.down => l10n.videoEditorTransitionDirectionDown,
  LayerSlideDirection.upLeft => l10n.videoEditorTransitionDirectionUpLeft,
  LayerSlideDirection.upRight => l10n.videoEditorTransitionDirectionUpRight,
  LayerSlideDirection.downLeft => l10n.videoEditorTransitionDirectionDownLeft,
  LayerSlideDirection.downRight => l10n.videoEditorTransitionDirectionDownRight,
};

DivineIconName _directionIcon(LayerSlideDirection direction) =>
    switch (direction) {
      LayerSlideDirection.left => DivineIconName.arrowLeft,
      LayerSlideDirection.right => DivineIconName.arrowRight,
      LayerSlideDirection.up => DivineIconName.arrowUp,
      LayerSlideDirection.down => DivineIconName.arrowDown,
      LayerSlideDirection.upLeft => DivineIconName.arrowUpLeft,
      LayerSlideDirection.upRight => DivineIconName.arrowUpRight,
      LayerSlideDirection.downLeft => DivineIconName.arrowDownLeft,
      LayerSlideDirection.downRight => DivineIconName.arrowDownRight,
    };

String _durationLabel(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
