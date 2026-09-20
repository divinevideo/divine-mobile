// ABOUTME: The app's ErrorWidget.builder: the branded "got a bit tangled"
// ABOUTME: surface shown in place of any widget that throws during build

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unified_logger/unified_logger.dart';

/// The illustration above the copy: the Divine mascot caught in a vine, so the
/// picture says what the copy says — it was us that got tangled, not the user.
@visibleForTesting
const globalErrorMascotAsset = 'assets/illustrations/error_mascot_tangled.png';

/// The smallest surface treated as a whole screen.
///
/// Below it the failure replaced a fragment of a page — an avatar, a list row —
/// where a Back control would cover the fragment and pop a route the user
/// never associated with it.
const _screenSizedSurface = Size(280, 360);

/// Builds the surface the framework shows in place of a widget whose build
/// failed. The startup sequence installs it as [ErrorWidget.builder].
///
/// It has to render anywhere in the tree, including before [MaterialApp]
/// exists, so it brings its own [Directionality] and reads colours through
/// `context.vineColors`, which follows the ambient appearance inside the app
/// shell and falls back to the dark palette when no theme exists yet. The copy
/// sets raw text styles with an explicit `TextDecoration.none` so it paints on
/// the first frame without waiting on a font. The two actions are the real
/// design-system buttons: Reload's label variant, Bricolage Grotesque
/// ExtraBold, ships in `assets/fonts/`, so resolving it is a local asset read
/// and never a network fetch.
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

/// The surface itself: the message, with the Back control laid over it.
class _GlobalErrorWidget extends StatelessWidget {
  const _GlobalErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final onBack = _backAction(context);
    final topInset = MediaQuery.maybePaddingOf(context)?.top ?? 0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: context.vineColors.background,
        child: Stack(
          children: [
            _ErrorMessage(
              details: details,
              // Keeps the illustration clear of the Back control.
              verticalPadding: onBack == null ? 24 : topInset + 64,
              // This context, not a descendant's: its parent is the element
              // whose build failed.
              onReload: () => _retryFailedBuild(context),
            ),
            if (onBack != null)
              Positioned.fill(
                child: _ShownOnScreenSizedSurface(
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
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),

              DivineButton(
                label: 'Reload',
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
          semanticLabel: 'Back',
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

/// Shows its child only when the surface it fills is at least
/// [_screenSizedSurface]; otherwise the child is laid out but neither painted,
/// hit-tested nor exposed to assistive technology.
///
/// A render object rather than a `LayoutBuilder`: a `LayoutBuilder` throws when
/// an ancestor probes intrinsic dimensions, and this surface can replace a
/// widget anywhere, including inside an `IntrinsicHeight` or a dialog.
class _ShownOnScreenSizedSurface extends SingleChildRenderObjectWidget {
  const _ShownOnScreenSizedSurface({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShownOnScreenSizedSurface();
}

class _RenderShownOnScreenSizedSurface extends RenderProxyBox {
  bool _isShown = false;

  @override
  void performLayout() {
    super.performLayout();
    final isShown =
        size.width >= _screenSizedSurface.width &&
        size.height >= _screenSizedSurface.height;
    if (isShown == _isShown) return;
    _isShown = isShown;
    markNeedsSemanticsUpdate();
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
