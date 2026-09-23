// ABOUTME: The app's ErrorWidget.builder: the branded "got a bit tangled"
// ABOUTME: surface shown in place of any widget that throws during build

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:unified_logger/unified_logger.dart';

/// The illustration above the copy: the Divine mascot caught in a vine, so the
/// picture says what the copy says — it was us that got tangled, not the user.
@visibleForTesting
const globalErrorMascotAsset = 'assets/illustrations/error_mascot_tangled.png';

/// The family the explanation and the hint are set in.
///
/// Like [VineTheme.fontFamilyBricolage] it is declared under `fonts:` in
/// `pubspec.yaml`, so the engine registers it at startup and naming it costs no
/// asynchronous load.
const _bodyFontFamily = 'Inter';

/// Builds the surface the framework shows in place of a widget whose build
/// failed. The startup sequence installs it as [ErrorWidget.builder].
///
/// It has to render anywhere in the tree, including before [MaterialApp]
/// exists, so it brings its own [Directionality] and reads colours through
/// `context.vineColors`, which follows the ambient appearance inside the app
/// shell and falls back to the dark palette when no theme exists yet.
///
/// The copy sets raw text styles that name a bundled family and
/// `TextDecoration.none`, because what it would inherit depends on where it
/// lands: outside a `Material` that is `MaterialApp`'s red, underlined,
/// monospace fallback. Those families are registered at startup, so the copy
/// paints on the first frame. The two actions are the real design-system
/// buttons: Reload's label variant, Bricolage Grotesque ExtraBold, ships in
/// `assets/fonts/`, so resolving it is a local asset read and never a network
/// fetch.
///
/// Reporting is not this widget's job. Every framework call site reports
/// [details] through [FlutterError.onError] before it asks the builder for a
/// replacement, and that handler already owns classification and Crashlytics.
/// A second report from here would count every build failure twice and file
/// as fatal the ones the handler deliberately downgraded.
Widget buildGlobalErrorWidget(FlutterErrorDetails details) {
  // On web, log error details for debugging
  if (kIsWeb) {
    Log.error(
      'ErrorWidget: ${details.exception}\n${details.stack}',
      name: 'ErrorWidget',
      category: LogCategory.system,
    );
  }
  return _GlobalErrorWidget(details: details);
}

/// Re-runs the build that failed.
///
/// The framework mounts this surface as the direct child of the element whose
/// build threw, so marking that parent dirty makes it build again, and a build
/// that succeeds replaces this surface with the real subtree.
void _retryFailedBuild(BuildContext context) {
  if (!context.mounted) return;
  context.visitAncestorElements((failedElement) {
    failedElement.markNeedsBuild();
    return false;
  });
}

/// The pop this surface can offer, or null when there is nothing to pop.
///
/// Null before [MaterialApp] exists, where there is no navigator at all, and
/// on a route that is the only entry of its stack.
VoidCallback? _backAction(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (!router.canPop()) return null;
    return () {
      // The stack can empty between this build and the tap, and popping an
      // empty go_router stack throws.
      if (router.canPop()) router.pop();
    };
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.canPop()) return null;
  return navigator.maybePop;
}

/// The app's strings, when this surface sits below the app's `Localizations`.
///
/// Null before `MaterialApp` exists and for a failure above it, where the
/// English copy stands in. Not `context.l10n`, whose `!` would make this
/// surface the second thing to fail.
AppLocalizations? _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations);

/// The insets the system reserves on this screen.
///
/// Read from the view, not from `MediaQuery`: a `SafeArea` or a `Scaffold`
/// above this surface has already removed them from the `MediaQuery` it sees.
EdgeInsets _systemInsets(BuildContext context) {
  final view = View.maybeOf(context);
  if (view == null) return EdgeInsets.zero;
  return EdgeInsets.fromViewPadding(view.viewPadding, view.devicePixelRatio);
}

/// The surface itself: the message, with the Back control laid over it.
class _GlobalErrorWidget extends StatelessWidget {
  const _GlobalErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final onBack = _backAction(context);
    // The navigator this surface sits in: its box is the area a route fills.
    final navigator = Navigator.maybeOf(context);
    final offersBack = onBack != null && navigator != null;
    // The insets this surface still has to stay clear of: the notch and the
    // home indicator when it replaced a whole route, nothing when it replaced
    // a piece of a page, which already sits inside them.
    final unconsumedInsets = MediaQuery.maybePaddingOf(context);
    final clearOfInsets = math.max(
      unconsumedInsets?.top ?? 0.0,
      unconsumedInsets?.bottom ?? 0.0,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: context.vineColors.background,
        child: Stack(
          children: [
            _ErrorMessage(
              details: details,
              // The same on both sides, so the message stays centred.
              verticalPadding: 24 + clearOfInsets,
              // This context, not a descendant's: its parent is the element
              // whose build failed.
              onReload: () => _retryFailedBuild(context),
            ),
            if (offersBack)
              Positioned.fill(
                child: _ShownWhenTheRouteIsGone(
                  navigator: navigator,
                  systemInsets: _systemInsets(context),
                  child: _BackButton(onPressed: onBack),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The illustration, the copy and the Reload action, centred and scrollable.
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.details,
    required this.verticalPadding,
    required this.onReload,
  });

  final FlutterErrorDetails details;
  final double verticalPadding;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                globalErrorMascotAsset,
                width: 220,
                excludeFromSemantics: true,
                // A missing illustration must not turn the crash surface into
                // a second failure.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 28),

              // Headline
              Text(
                'got a bit tangled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Friendly explanation
              Text(
                "something tripped up here.\nit's not you, it's us.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.onSurfaceVariant,
                  fontFamily: _bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),

              // Gentle nudge
              Text(
                'try navigating away and coming back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.onSurfaceMuted,
                  fontFamily: _bodyFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),

              DivineButton(
                label: _l10n(context)?.commonReload ?? 'Reload',
                type: DivineButtonType.secondary,
                onPressed: onReload,
              ),

              // Debug info for developers; on web the exception text is shown
              // in every build mode.
              if (kDebugMode || kIsWeb) ...[
                const SizedBox(height: 24),
                _ErrorDetailsBlock(details: details),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The top-left Back control, sized and styled like the app bar's own.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Not a SafeArea: that asserts a MediaQuery ancestor, which a bare
    // Navigator does not provide.
    final safeArea = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: safeArea.left + 12,
          top: safeArea.top + 8,
        ),
        child: DivineIconButton(
          icon: DivineIconName.caretLeft,
          type: DivineIconButtonType.secondary,
          size: DivineIconButtonSize.small,
          semanticLabel: _l10n(context)?.commonBack ?? 'Back',
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// What failed, for developers.
class _ErrorDetailsBlock extends StatelessWidget {
  const _ErrorDetailsBlock({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.disabled),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'debug info',
            style: TextStyle(
              color: context.vineColors.accentPositive,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details.exceptionAsString(),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VineTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              fontFamily: 'monospace',
              decoration: TextDecoration.none,
              height: 1.4,
            ),
          ),
          if (details.context != null) ...[
            const SizedBox(height: 6),
            Text(
              details.context!.toDescription(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.vineColors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (details.library != null) ...[
            const SizedBox(height: 6),
            Text(
              'library: ${details.library}',
              style: TextStyle(
                color: context.vineColors.onSurfaceMuted,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows its child only when the surface it fills replaced a whole route;
/// otherwise the child is laid out but neither painted, hit-tested nor exposed
/// to assistive technology.
///
/// A whole route is as large as its navigator, or as that area inside the
/// system insets when the page sat under a `SafeArea`. Anything else is a
/// piece of a page that is still alive around it: a list item, a tile, a body
/// under a working app bar, the content of a sheet. There a Back control
/// would cover the piece and pop a route the user never associated with it,
/// and the page still has its own way out.
///
/// A render object rather than a `LayoutBuilder`: a `LayoutBuilder` throws when
/// an ancestor probes intrinsic dimensions, and this surface can replace a
/// widget anywhere, including inside an `IntrinsicHeight` or a dialog.
class _ShownWhenTheRouteIsGone extends SingleChildRenderObjectWidget {
  const _ShownWhenTheRouteIsGone({
    required this.navigator,
    required this.systemInsets,
    required Widget super.child,
  });

  final NavigatorState navigator;
  final EdgeInsets systemInsets;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShownWhenTheRouteIsGone(
        navigator: navigator,
        systemInsets: systemInsets,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShownWhenTheRouteIsGone renderObject,
  ) {
    renderObject
      ..navigator = navigator
      ..systemInsets = systemInsets;
  }
}

class _RenderShownWhenTheRouteIsGone extends RenderProxyBox {
  _RenderShownWhenTheRouteIsGone({
    required NavigatorState navigator,
    required EdgeInsets systemInsets,
  }) : _navigator = navigator,
       _systemInsets = systemInsets;

  NavigatorState get navigator => _navigator;
  NavigatorState _navigator;
  set navigator(NavigatorState value) {
    if (identical(value, _navigator)) return;
    _navigator = value;
    markNeedsLayout();
  }

  EdgeInsets get systemInsets => _systemInsets;
  EdgeInsets _systemInsets;
  set systemInsets(EdgeInsets value) {
    if (value == _systemInsets) return;
    _systemInsets = value;
    markNeedsLayout();
  }

  bool _isShown = false;

  @override
  void performLayout() {
    super.performLayout();
    final isShown = _fillsTheRoute();
    if (isShown == _isShown) return;
    _isShown = isShown;
    markNeedsSemanticsUpdate();
  }

  bool _fillsTheRoute() {
    // Resolved here and not during build, where `findRenderObject` is not
    // valid: it returns null for a navigator inflated in the same frame.
    final routeArea = _navigator.mounted
        ? _navigator.context.findRenderObject()
        : null;
    if (routeArea is! RenderBox || !routeArea.attached) return false;
    // Its constraints rather than its size: the framework does not let one
    // box read another's size during layout, and a navigator fills what it
    // is given.
    final route = routeArea.constraints.biggest;
    return _fills(size.width, route.width, _systemInsets.horizontalPair) &&
        _fills(size.height, route.height, _systemInsets.verticalPair);
  }

  /// Whether [extent] is [whole], or [whole] less either or both [insets].
  static bool _fills(double extent, double whole, (double, double) insets) {
    final (leading, trailing) = insets;
    return [
      whole,
      whole - leading,
      whole - trailing,
      whole - leading - trailing,
    ].any((expected) => (extent - expected).abs() < 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_isShown) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _isShown && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_isShown) super.visitChildrenForSemantics(visitor);
  }
}

extension on EdgeInsets {
  (double, double) get horizontalPair => (left, right);
  (double, double) get verticalPair => (top, bottom);
}
