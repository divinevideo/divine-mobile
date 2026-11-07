// ABOUTME: What an eyedropper can pick a color from: video views register
// ABOUTME: themselves, and a color sheet anywhere finds the one on screen.

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/eyedropper/color_eyedropper.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';

/// Something on screen whose colors can be picked.
abstract interface class EyedropperSource {
  /// Whether it is on screen right now, so a pick would show what it shows.
  bool get isVisible;

  /// Lets the user pick a color off it, resolving with the color or with
  /// `null` when they close the eyedropper instead.
  Future<Color?> pick(BuildContext context);
}

/// The [EyedropperSource]s that are mounted, newest last.
class EyedropperSourceRegistry {
  final _sources = <EyedropperSource>[];

  /// The newest source that is on screen, or `null` when none is.
  ///
  /// Newest first because a screen opened over another registers after it:
  /// the color mask screen's preview beats the editor canvas below it.
  EyedropperSource? get visible =>
      _sources.reversed.where((source) => source.isVisible).firstOrNull;

  /// Adds [source] as the newest.
  void register(EyedropperSource source) => _sources.add(source);

  /// Removes [source].
  void unregister(EyedropperSource source) => _sources.remove(source);
}

/// Holds the app's [EyedropperSourceRegistry].
///
/// Sits above the navigator, so color sheets and screens pushed over a video
/// view still find it.
class EyedropperSources extends StatefulWidget {
  /// Creates the registry for everything below [child].
  const EyedropperSources({
    required this.child,
    @visibleForTesting this.registry,
    super.key,
  });

  final Widget child;

  /// The registry to provide. Tests pass one to register sources of their
  /// own; the app lets the widget create it.
  final EyedropperSourceRegistry? registry;

  /// The registry above [context], or `null` when there is none.
  static EyedropperSourceRegistry? registryOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_EyedropperSourcesScope>()
      ?.registry;

  /// The source a color sheet opened from [context] can pick from, or `null`
  /// when nothing pickable is on screen.
  static EyedropperSource? visibleOf(BuildContext context) =>
      registryOf(context)?.visible;

  @override
  State<EyedropperSources> createState() => _EyedropperSourcesState();
}

class _EyedropperSourcesState extends State<EyedropperSources> {
  late final EyedropperSourceRegistry _registry =
      widget.registry ?? EyedropperSourceRegistry();

  @override
  Widget build(BuildContext context) =>
      _EyedropperSourcesScope(registry: _registry, child: widget.child);
}

class _EyedropperSourcesScope extends InheritedWidget {
  const _EyedropperSourcesScope({required this.registry, required super.child});

  final EyedropperSourceRegistry registry;

  // The registry is read when a sheet opens, never during a build.
  @override
  bool updateShouldNotify(_EyedropperSourcesScope oldWidget) => false;
}

/// Makes [child] something an eyedropper can pick from, for as long as it is
/// mounted.
///
/// Gives [child] its own layer, so a pick reads what [child] paints — not
/// whatever is drawn over it, and not a filter applied above it.
class EyedropperSourceRegion extends StatefulWidget {
  /// Registers [child] with the [EyedropperSources] above it.
  const EyedropperSourceRegion({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    @visibleForTesting this.capture = captureEyedropperSnapshot,
    super.key,
  });

  final Widget child;

  /// Captures the region for the eyedropper. Tests replace it to supply
  /// known pixels.
  final EyedropperCapture capture;

  /// The rounding [child] is shown with, so the still frame the eyedropper
  /// draws in its place has the same corners.
  final BorderRadius borderRadius;

  @override
  State<EyedropperSourceRegion> createState() => _EyedropperSourceRegionState();
}

class _EyedropperSourceRegionState extends State<EyedropperSourceRegion>
    implements EyedropperSource {
  final GlobalKey _boundaryKey = GlobalKey(
    debugLabel: 'EyedropperSourceRegion',
  );
  EyedropperSourceRegistry? _registry;

  @override
  bool get isVisible {
    final boundaryContext = _boundaryKey.currentContext;
    if (!mounted || boundaryContext == null) return false;
    final boundary = boundaryContext.findRenderObject();
    // A route under an opaque one stays mounted but is not painted; its
    // tickers are switched off, which is how that shows here.
    return boundary is RenderRepaintBoundary &&
        boundary.attached &&
        boundary.hasSize &&
        TickerMode.valuesOf(boundaryContext).enabled;
  }

  /// Opens the eyedropper over this region on top of everything, sheets
  /// included.
  ///
  /// A screen of its own, so the system back gesture closes just the
  /// eyedropper and returns to whatever opened it.
  @override
  Future<Color?> pick(BuildContext context) {
    final region = widget;
    return Navigator.of(context, rootNavigator: true).push<Color>(
      PageRouteBuilder<Color>(
        settings: const RouteSettings(name: 'color_eyedropper'),
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        // Transparent Material: a screen of its own has no Scaffold to give
        // the instruction its text style.
        pageBuilder: (routeContext, _, _) => Material(
          type: MaterialType.transparency,
          child: ColorEyedropper(
            sourceKey: _boundaryKey,
            sourceBorderRadius: region.borderRadius,
            capture: region.capture,
            onColorPicked: (color) => Navigator.of(routeContext).pop(color),
            onCancel: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = EyedropperSources.registryOf(context);
    if (identical(registry, _registry)) return;
    _registry?.unregister(this);
    _registry = registry?..register(this);
  }

  @override
  void dispose() {
    _registry?.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundaryKey, child: widget.child);
}
