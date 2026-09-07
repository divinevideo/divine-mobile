// ABOUTME: BuildContext extensions for showing modals/navigating that pause
// ABOUTME: video playback. Uses owner-held page tokens for full-screen pages
// ABOUTME: and dialogs, and owner-held sheet tokens for retained bottom sheets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';

/// Extension methods for showing modals and navigating that automatically
/// pause video playback.
///
/// These methods wrap [VineBottomSheet.show], [showDialog], and
/// [GoRouter.push] to integrate with [OverlayVisibility], ensuring videos
/// pause when overlays/routes open and resume when they close.
///
/// Example:
/// ```dart
/// // Push a route with video pause:
/// context.pushWithVideoPause('/profile/npub1...');
///
/// // Standard VineBottomSheet with video pause:
/// context.showVideoPausingVineBottomSheet(
///   title: Text('Options'),
///   children: [...],
/// );
/// ```
extension PauseAwareModals on BuildContext {
  /// Pushes a route that automatically pauses video playback.
  ///
  /// Takes an [OverlayVisibility] owner token before pushing and releases that
  /// token when the pushed route is popped.
  /// This releases all video players to free memory.
  ///
  /// The returned future only completes on a **pop**: go_router completes an
  /// `ImperativeRouteMatch` from `_completeRouteMatch`, which runs on the pop
  /// path alone, so a `go()` that rebuilds the match list removes the route and
  /// drops the pending completer. `AppShell` therefore also clears the flag
  /// whenever the shell is uncovered — without that safety net a `go()`-style
  /// back (the Android back handler, a deep link, a refresh redirect) strands
  /// the flag `true` and the home feed never autoplays again (#6239). Do not
  /// make this future the only clear path.
  Future<T?> pushWithVideoPause<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    final owner = Object();

    overlayNotifier.setPageOpenForOwner(owner, isOpen: true);

    return push<T>(location, extra: extra).whenComplete(() {
      if (!overlayNotifier.isMounted) return;
      overlayNotifier.setPageOpenForOwner(owner, isOpen: false);
    });
  }

  /// Shows a dialog that automatically pauses video playback.
  ///
  /// Takes an [OverlayVisibility] owner token before showing and releases that
  /// token after the dialog is dismissed.
  /// This releases all video players (dialogs block full UI).
  Future<T?> showVideoPausingDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    TraversalEdgeBehavior? traversalEdgeBehavior,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    final owner = Object();

    overlayNotifier.setPageOpenForOwner(owner, isOpen: true);

    return showDialog<T>(
      context: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
    ).whenComplete(() {
      if (!overlayNotifier.isMounted) return;
      overlayNotifier.setPageOpenForOwner(owner, isOpen: false);
    });
  }

  /// Shows a [VineBottomSheet] that automatically pauses video playback.
  ///
  /// This is a convenience wrapper around [VineBottomSheet.show] that provides
  /// the [onShow] and [onDismiss] callbacks for video pause integration.
  ///
  /// For standard bottom sheets, use the [VineBottomSheet] parameters like
  /// [children], [body], [title], etc.
  ///
  /// For fully custom bottom sheet widgets that don't fit the [VineBottomSheet]
  /// structure (e.g., custom headers), use the [builder] parameter instead.
  /// When [builder] is provided, a raw [showModalBottomSheet] is used with
  /// video pause integration, bypassing [VineBottomSheet].
  Future<T?> showVideoPausingVineBottomSheet<T>({
    /// Builder for fully custom bottom sheet widgets.
    /// When provided, bypasses [VineBottomSheet] and uses raw modal.
    WidgetBuilder? builder,
    List<Widget>? children,
    bool scrollable = true,
    bool showHeader = true,
    Widget? title,
    String? contentTitle,
    Widget? body,
    Widget Function(ScrollController scrollController)? buildScrollBody,
    Widget? trailing,
    Widget? bottomInput,
    bool expanded = true,
    bool showHeaderDivider = true,
    // Nullable so the handle keeps following VineBottomSheet.show's
    // enableDrag-derived default (#8462); a non-null default here would pin it
    // on for every caller.
    bool? showDragHandle,
    bool? isScrollControlled,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    bool snap = false,
    List<double>? snapSizes,
    // Defaults to true because video-pausing sheets are inherently
    // full-takeover interactions that should cover the tab bar. Callers on
    // screens without a shell/tab bar can opt out with false. Matches the
    // sibling showVideoPausingDialog.
    bool useRootNavigator = true,
    bool tapOutsideToDismiss = true,
    Widget Function(BuildContext context, Widget child)? contentWrapper,
    DraggableScrollableController? draggableController,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    final bottomSheetOwner = Object();

    // Custom builder path: raw modal bottom sheet with video pause integration
    // Uses an owner-backed sheet hold to retain current player for instant
    // resume.
    //
    // The custom-builder path is an escape hatch for sheets that do not fit
    // the VineBottomSheet structure (e.g. Share's custom Material header).
    // New VineBottomSheet-specific parameters are intentionally NOT forwarded
    // here — the caller owns the full sheet layout in this mode.
    if (builder != null) {
      overlayNotifier.setBottomSheetOpenForOwner(
        bottomSheetOwner,
        isOpen: true,
      );
      return showModalBottomSheet<T>(
        context: this,
        builder: builder,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        backgroundColor: VineTheme.transparent,
      ).whenComplete(() {
        if (!overlayNotifier.isMounted) return;
        overlayNotifier.setBottomSheetOpenForOwner(
          bottomSheetOwner,
          isOpen: false,
        );
      });
    }

    // Standard VineBottomSheet path
    // Uses an owner-backed sheet hold to retain current player for instant
    // resume.
    return VineBottomSheet.show<T>(
      context: this,
      children: children,
      scrollable: scrollable,
      showHeader: showHeader,
      title: title,
      contentTitle: contentTitle,
      body: body,
      buildScrollBody: buildScrollBody,
      trailing: trailing,
      bottomInput: bottomInput,
      expanded: expanded,
      showHeaderDivider: showHeaderDivider,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: snap,
      snapSizes: snapSizes,
      useRootNavigator: useRootNavigator,
      tapOutsideToDismiss: tapOutsideToDismiss,
      contentWrapper: contentWrapper,
      draggableController: draggableController,
      onShow: () => overlayNotifier.setBottomSheetOpenForOwner(
        bottomSheetOwner,
        isOpen: true,
      ),
      onDismiss: () {
        if (!overlayNotifier.isMounted) return;
        overlayNotifier.setBottomSheetOpenForOwner(
          bottomSheetOwner,
          isOpen: false,
        );
      },
    );
  }

  /// Shows a [VineBottomSheetSelectionMenu] that automatically pauses video
  /// playback.
  ///
  /// [VineBottomSheetSelectionMenu.show] does not expose
  /// `onShow`/`onDismiss`, so the overlay flag is toggled here around the
  /// returned future. Uses the same owner-backed semantics as
  /// [showVideoPausingVineBottomSheet], so the current player is paused but
  /// retained for instant resume.
  Future<String?> showVideoPausingSelectionMenu({
    required List<VineBottomSheetSelectionOptionData> options,
    Widget? title,
    String? selectedValue,
    EdgeInsetsGeometry? headerPadding,
    DivineIconButton? headerLeadingAction,
    DivineIconButton? headerTrailingAction,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    final bottomSheetOwner = Object();

    overlayNotifier.setBottomSheetOpenForOwner(bottomSheetOwner, isOpen: true);

    return VineBottomSheetSelectionMenu.show(
      context: this,
      options: options,
      title: title,
      selectedValue: selectedValue,
      headerPadding: headerPadding,
      headerLeadingAction: headerLeadingAction,
      headerTrailingAction: headerTrailingAction,
    ).whenComplete(() {
      if (!overlayNotifier.isMounted) return;
      overlayNotifier.setBottomSheetOpenForOwner(
        bottomSheetOwner,
        isOpen: false,
      );
    });
  }
}
