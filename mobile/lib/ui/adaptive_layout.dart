// ABOUTME: Window-size layout classes for tablets and foldables, gated on the
// ABOUTME: Large Screen Layout flag, and the orientation policy that goes with them

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/large_screen_orientation_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Window widths at which the large-screen layouts take over.
///
/// Every layout decision reads the width of the window the app is drawn in,
/// never the device type or its orientation: the iPhone Duo is an iPhone that
/// draws on a tablet-sized inner display, and an iPad can run in a window as
/// narrow as a phone.
abstract final class AdaptiveBreakpoints {
  /// From this width a window is large: the iPhone Duo's inner display and
  /// every iPad in portrait.
  static const double large = 600;

  /// From this width a window that is wider than tall gets side navigation
  /// and the comments panel: the iPhone Duo open in landscape, and iPads in
  /// landscape.
  static const double wide = 840;

  /// From this width grids get their last extra column.
  static const double extraWide = 1200;

  /// The narrowest side inset that is a status bar column rather than the
  /// rounded corner of a display (see [AdaptiveLayout.statusBarColumn]).
  static const double minStatusBarColumn = 60;
}

/// A status bar column along a side of the window: its [width], and whether
/// it runs down the right edge or the left one.
typedef StatusBarColumn = ({double width, bool onRight});

/// The layout class of the current window.
///
/// Everything is off unless [enabled], which follows
/// [FeatureFlag.largeScreenLayout] (see [AdaptiveLayoutScope] for the one
/// exception): with the flag off every window lays out as it did before the
/// flag existed.
@immutable
class AdaptiveLayout {
  const AdaptiveLayout({required this.enabled, required this.size});

  /// Whether the large-screen layouts may be used at all: the flag is on, or
  /// the app runs on a large display whose platform ignores its portrait
  /// lock.
  final bool enabled;

  /// The size of the window the app is drawn in.
  final Size size;

  /// Whether the window is wide enough for the tablet layouts.
  bool get isLargeScreen => enabled && size.width >= AdaptiveBreakpoints.large;

  /// Whether the window is a wide landscape one, which moves the navigation to
  /// the side and opens comments in a panel beside the video.
  bool get isWideLandscape =>
      enabled &&
      size.width >= AdaptiveBreakpoints.wide &&
      size.width > size.height;

  /// The column the system keeps along a side of the window for its status
  /// bar, read from the window's [viewPadding]: the iPhone Duo runs its
  /// status bar and camera down a side edge, on the outer display and on the
  /// inner one in landscape, and insets the whole height of that edge.
  ///
  /// Null when there is none (any other phone or tablet, whose status bar
  /// runs along the top) or the large-screen layouts are off.
  StatusBarColumn? statusBarColumn(EdgeInsets viewPadding) {
    if (!enabled || viewPadding.top > 0) return null;
    final onRight = viewPadding.right >= viewPadding.left;
    final width = onRight ? viewPadding.right : viewPadding.left;
    if (width < AdaptiveBreakpoints.minStatusBarColumn) return null;
    return (width: width, onRight: onRight);
  }

  /// The column count for a grid [width] wide that shows [compact] columns
  /// on a phone.
  ///
  /// [width] is the grid's own width, which the side navigation, the comments
  /// panel or the grid's padding make narrower than the window. Adds one
  /// column at each breakpoint the grid crosses, so tiles stay about as wide
  /// as they are on a phone.
  ///
  /// Without the large-screen layouts a grid keeps the rule it had before
  /// them, which read the window rather than the grid: [compact] columns, or
  /// [largeColumnsWithoutFlag] in a window at least
  /// [AdaptiveBreakpoints.large] wide where given.
  int gridColumns({
    required int compact,
    required double width,
    int? largeColumnsWithoutFlag,
  }) {
    if (!enabled) {
      return size.width >= AdaptiveBreakpoints.large
          ? largeColumnsWithoutFlag ?? compact
          : compact;
    }
    if (width < AdaptiveBreakpoints.large) return compact;
    if (width < AdaptiveBreakpoints.wide) return compact + 1;
    if (width < AdaptiveBreakpoints.extraWide) return compact + 2;
    return compact + 3;
  }

  @override
  bool operator ==(Object other) =>
      other is AdaptiveLayout && other.enabled == enabled && other.size == size;

  @override
  int get hashCode => Object.hash(enabled, size);
}

/// Reads the [AdaptiveLayout] of the window this context is drawn in.
extension AdaptiveLayoutContext on BuildContext {
  /// The layout class of this context's window.
  ///
  /// Disabled when no [AdaptiveLayoutScope] is above this context, as in
  /// tests that pump a widget on its own.
  AdaptiveLayout get adaptiveLayout => AdaptiveLayout(
    enabled: AdaptiveLayoutScope.isEnabledOf(this),
    size: MediaQuery.sizeOf(this),
  );
}

/// Publishes whether the large-screen layouts are on, and keeps the allowed
/// device orientations in step with them.
///
/// Mounted once, above every route. With [FeatureFlag.largeScreenLayout] on
/// and a window whose shorter side is at least
/// [AdaptiveBreakpoints.large], the app may rotate; everywhere else, and while
/// a [PortraitOrientationLock] is mounted, it stays in portrait as before.
///
/// The layouts are also on, whatever the flag, on a display at least
/// [AdaptiveBreakpoints.large] across whose platform ignores the portrait
/// lock ([ignoresOrientationLockOnLargeScreensProvider]): Android 16 tablets
/// and unfolded foldables rotate the app regardless, and the phone layout
/// in a landscape window crops a vertical video to a strip and shows a
/// landscape camera preview for a portrait recording.
class AdaptiveLayoutScope extends ConsumerStatefulWidget {
  const AdaptiveLayoutScope({required this.child, super.key});

  final Widget child;

  /// Whether the large-screen layouts are on above [context].
  static bool isEnabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AdaptiveLayoutInherited>()
          ?.enabled ??
      false;

  @override
  ConsumerState<AdaptiveLayoutScope> createState() =>
      _AdaptiveLayoutScopeState();
}

class _AdaptiveLayoutScopeState extends ConsumerState<AdaptiveLayoutScope> {
  int _portraitLocks = 0;
  bool _rotationWanted = false;
  bool? _rotationApplied;

  /// The flag as last reported to the iOS app delegate, which starts out
  /// believing it off.
  bool _reportedToSystem = false;

  /// Tells the iOS app delegate whether the flag is on as the app resolves
  /// it, override or build default: its orientation mask allows rotation on
  /// large screens only then, and it cannot read the build default itself.
  void _reportToSystem(bool enabled) {
    if (!_systemKeepsSmallScreensPortrait || enabled == _reportedToSystem) {
      return;
    }
    _reportedToSystem = enabled;
    runDetached(
      largeScreenLayoutChannel.invokeMethod<void>('setEnabled', enabled),
      'report the large-screen layouts to the app delegate',
      logName: 'AdaptiveLayoutScope',
      category: LogCategory.ui,
    );
  }

  void _acquirePortraitLock() {
    _portraitLocks++;
    _applyOrientations();
  }

  void _releasePortraitLock() {
    _portraitLocks--;
    _applyOrientations();
  }

  void _applyOrientations() {
    if (!_controlsOrientation) return;
    final allowRotation = _rotationWanted && _portraitLocks == 0;
    if (allowRotation == _rotationApplied) return;
    // Portrait is what startup already applied: nothing to ask for until
    // rotation was allowed once, so a camera opened with the flag off (or on
    // an Android phone) makes no orientation call, exactly as before the
    // flag.
    if (_rotationApplied == null && !allowRotation) return;
    _rotationApplied = allowRotation;
    runDetached(
      SystemChrome.setPreferredOrientations(
        allowRotation ? DeviceOrientation.values : _portraitOnly,
      ),
      'apply large-screen orientation policy',
      logName: 'AdaptiveLayoutScope',
      category: LogCategory.ui,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flagEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.largeScreenLayout),
    );
    final enabled =
        flagEnabled ||
        (ref.watch(ignoresOrientationLockOnLargeScreensProvider) &&
            _isOnLargeDisplay(context));
    // Before any orientation request, so the delegate's mask already allows
    // what Dart asks for.
    _reportToSystem(flagEnabled);
    // The display fallback only changes layout. The system can still honor
    // portrait lock when its aspect-ratio settings override the default.
    _rotationWanted =
        flagEnabled &&
        (_systemKeepsSmallScreensPortrait ||
            MediaQuery.sizeOf(context).shortestSide >=
                AdaptiveBreakpoints.large);
    _applyOrientations();
    return _AdaptiveLayoutInherited(
      enabled: enabled,
      acquirePortraitLock: _acquirePortraitLock,
      releasePortraitLock: _releasePortraitLock,
      child: widget.child,
    );
  }
}

/// The orientation startup locks the app to (see `app_bootstrap.dart`).
const List<DeviceOrientation> _portraitOnly = [DeviceOrientation.portraitUp];

/// Whether this context's display is at least [AdaptiveBreakpoints.large]
/// across its shorter side, which is where Android 16 stops honouring the
/// portrait lock.
///
/// Also reads the window, which rebuilds the scope when folding or resizing
/// changes it, and stands in for a display that reports no size.
bool _isOnLargeDisplay(BuildContext context) {
  final window = MediaQuery.sizeOf(context);
  final display = View.maybeOf(context)?.display;
  final displayShortestSide = display == null || display.devicePixelRatio <= 0
      ? 0.0
      : display.size.shortestSide / display.devicePixelRatio;
  return math.max(displayShortestSide, window.shortestSide) >=
      AdaptiveBreakpoints.large;
}

/// Reports the large-screen layouts to the iOS app delegate
/// (`AppDelegate.swift`), whose orientation mask depends on them, and asks the
/// Android activity (`MainActivity.kt`) whether the system ignores the
/// portrait lock on large displays.
@visibleForTesting
const MethodChannel largeScreenLayoutChannel = MethodChannel(
  'divine/large_screen_layout',
);

/// Whether the platform ignores the app's portrait lock on large displays:
/// Android 16 does for apps that target API 36 (see
/// [ignoresOrientationLockOnLargeScreensProvider]).
///
/// Asked once at startup. False on every other platform, and when the
/// activity cannot answer, so the layouts then follow the flag alone.
Future<bool> resolveIgnoresOrientationLockOnLargeScreens() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await largeScreenLayoutChannel.invokeMethod<bool>(
          'ignoresOrientationLockOnLargeScreens',
        ) ??
        false;
  } on PlatformException catch (error, stackTrace) {
    Log.warning(
      'Could not ask whether the system ignores the portrait lock',
      name: 'AdaptiveLayoutScope',
      category: LogCategory.ui,
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  } on MissingPluginException {
    // An activity without the channel (an older native shell) predates the
    // question and keeps its lock.
    return false;
  }
}

/// Whether the platform itself keeps screens smaller than
/// [AdaptiveBreakpoints.large] in portrait once the flag is on.
///
/// On iOS the app delegate does (`supportedInterfaceOrientationsFor`), and the
/// Dart side must not narrow by size as well: on the iPhone Duo's outer
/// display that left portrait as the app's preference, so opening the Duo
/// sideways turned the app to portrait, and iOS, which refuses programmatic
/// rotation there, kept it in portrait.
bool get _systemKeepsSmallScreensPortrait =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Whether this platform takes orientation preferences at all. Mirrors the
/// startup lock, which skips the web and desktop.
bool get _controlsOrientation =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

class _AdaptiveLayoutInherited extends InheritedWidget {
  const _AdaptiveLayoutInherited({
    required this.enabled,
    required this.acquirePortraitLock,
    required this.releasePortraitLock,
    required super.child,
  });

  final bool enabled;
  final VoidCallback acquirePortraitLock;
  final VoidCallback releasePortraitLock;

  @override
  bool updateShouldNotify(_AdaptiveLayoutInherited oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Keeps the app in portrait while [child]'s route shows, even where the
/// large-screen layouts let it rotate.
///
/// For the camera, which records in portrait. A page pushed over it, such as
/// the editor or Post details, may rotate again, and the lock comes back
/// with the camera; a sheet or dialog over it keeps the lock, since the
/// camera still shows around it. The editor is laid out for both
/// orientations instead.
///
/// It asks the system, which an iPad follows. The iPhone Duo refuses
/// programmatic rotation, so on the open Duo the camera keeps the window's
/// orientation.
class PortraitOrientationLock extends StatefulWidget {
  const PortraitOrientationLock({required this.child, super.key});

  final Widget child;

  @override
  State<PortraitOrientationLock> createState() =>
      _PortraitOrientationLockState();
}

class _PortraitOrientationLockState extends State<PortraitOrientationLock> {
  /// Releases the lock this widget holds, or null while it holds none.
  VoidCallback? _release;

  /// The route's secondary animation, which runs when a page is pushed over
  /// the route and back when it pops. Sheets and dialogs do not drive it: a
  /// page route only transitions to another page route.
  Animation<double>? _cover;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cover = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(cover, _cover)) {
      _cover?.removeStatusListener(_onCoverChanged);
      _cover = cover?..addStatusListener(_onCoverChanged);
    }
    _update();
  }

  void _onCoverChanged(AnimationStatus _) {
    if (mounted) _update();
  }

  /// Holds the lock unless a page covers the route, or is on its way to.
  void _update() {
    final coveredByPage = _cover?.status.isForwardOrCompleted ?? false;
    if (coveredByPage == (_release == null)) return;
    if (coveredByPage) {
      _releaseLock();
      return;
    }
    final scope = context
        .getInheritedWidgetOfExactType<_AdaptiveLayoutInherited>();
    if (scope == null) return;
    scope.acquirePortraitLock();
    _release = scope.releasePortraitLock;
  }

  void _releaseLock() {
    _release?.call();
    _release = null;
  }

  @override
  void dispose() {
    _cover?.removeStatusListener(_onCoverChanged);
    _releaseLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps [child] out of the window's status bar column (see
/// [AdaptiveLayout.statusBarColumn]), as Apple's own apps do on the iPhone
/// Duo: nothing shares the column with the status bar.
///
/// For screens that otherwise run their content to the side edges, such as
/// the video feeds. Where there is no column it insets nothing.
class StatusBarColumnSafeArea extends StatelessWidget {
  const StatusBarColumnSafeArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final column = context.adaptiveLayout.statusBarColumn(
      MediaQuery.viewPaddingOf(context),
    );
    // Always a SafeArea, so folding or rotating the device keeps [child].
    return SafeArea(
      top: false,
      bottom: false,
      left: column != null && !column.onRight,
      right: column != null && column.onRight,
      child: child,
    );
  }
}

/// Lays [child], a screen opened over the tabs, out beside the window's status
/// bar column (see [AdaptiveLayout.statusBarColumn]), and paints the column in
/// the navigation's color, as the tab screens do: there the column holds the
/// tabs, or meets the bottom bar. So on the screens it frames the content
/// ends where the column starts, and the column reads the same.
///
/// [StatusBarColumnPageTransitionsBuilder] puts it around the transition of
/// every page route that takes the theme's transition, so the column stays
/// put while the page slides within its space. Routes with a transition of
/// their own (the fade-upwards pages, developer options, the Post details
/// preview) put it there themselves; the editor's tool screens, pushed as
/// their own routes over the framed editor, have none. Without a column it
/// lays [child] out as it would be.
class StatusBarColumnFrame extends StatelessWidget {
  const StatusBarColumnFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final column = context.adaptiveLayout.statusBarColumn(
      MediaQuery.viewPaddingOf(context),
    );
    final left = column != null && !column.onRight ? column.width : 0.0;
    final right = column != null && column.onRight ? column.width : 0.0;
    final color = context.vineColors.nav;
    // The same children with or without a column, so folding, rotating or
    // turning the layouts on keeps the screen.
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: color,
          child: SizedBox(width: left),
        ),
        Expanded(
          // A page sliding in or out stays off the column.
          child: ClipRect(
            clipBehavior: column == null ? Clip.none : Clip.hardEdge,
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: left > 0,
              removeRight: right > 0,
              child: child,
            ),
          ),
        ),
        ColoredBox(
          color: color,
          child: SizedBox(width: right),
        ),
      ],
    );
  }
}

/// Frames the pages [inner] transitions in a [StatusBarColumnFrame].
///
/// Installed for every platform in the app's themes, so it reaches the
/// screens opened over the tabs that take the theme's transition. The tabs'
/// own route is a custom page that lays out its column itself.
class StatusBarColumnPageTransitionsBuilder extends PageTransitionsBuilder {
  const StatusBarColumnPageTransitionsBuilder(this.inner);

  /// The transition the page would have without the frame.
  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => StatusBarColumnFrame(
    child: inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    ),
  );
}
