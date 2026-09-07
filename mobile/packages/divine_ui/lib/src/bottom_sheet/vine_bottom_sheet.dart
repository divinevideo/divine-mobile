// ABOUTME: Reusable bottom sheet component with Vine design system
// ABOUTME: Supports both scrollable (draggable) and fixed modes

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A reusable bottom sheet component following Vine's design system.
///
/// Features:
/// - Drag handle for gesture indication
/// - Customizable header with title, trailing actions, and optional
///   [headerLeadingAction]/[headerTrailingAction] icon buttons
///   (see [VineBottomSheetHeader])
/// - Two modes: scrollable (draggable) and fixed
/// - Optional bottom input section
/// - Dark mode optimized with proper theming
///
/// Use [VineBottomSheet.show] to display the sheet:
/// - `scrollable: true` (default) - Draggable sheet with scrollable content
/// - `scrollable: false` - Fixed height based on content, not draggable
class VineBottomSheet extends StatelessWidget {
  /// Creates a [VineBottomSheet] with the given parameters.
  ///
  /// Set [expanded] to false for content that should wrap (not fill space).
  const VineBottomSheet({
    this.scrollable = true,
    this.showHeader = true,
    this.title,
    this.contentTitle,
    this.contentTitleTrailing,
    this.scrollController,
    this.children,
    this.body,
    this.buildScrollBody,
    this.trailing,
    this.onComplete,
    this.closeSemanticLabel = 'Close',
    this.completeSemanticLabel = 'Done',
    this.bottomInput,
    this.expanded = true,
    this.showHeaderDivider = true,
    this.showDragHandle = true,
    this.headerPadding,
    this.headerLeadingAction,
    this.headerTrailingAction,
    super.key,
  }) : assert(
         children != null || body != null || buildScrollBody != null,
         'Provide either children, body, or buildScrollBody',
       ),
       assert(
         buildScrollBody == null || scrollController != null,
         'scrollController must be provided when using buildScrollBody',
       );

  /// Whether the sheet is scrollable/draggable.
  ///
  /// When true (default), the sheet uses DraggableScrollableSheet and content
  /// is scrollable. When false, the sheet has fixed height based on content.
  final bool scrollable;

  /// Whether to show the full header (drag handle + title + divider).
  ///
  /// When false, only the drag handle is shown and content starts immediately
  /// below it. Useful for sheets where the title is part of the scrollable
  /// content rather than pinned in a header bar.
  final bool showHeader;

  /// Optional title widget displayed in the header (above divider)
  final Widget? title;

  /// Optional title displayed in the content area (below divider)
  ///
  /// Styled with titleMedium font in onSurface color.
  final String? contentTitle;

  /// Optional action rendered at the end of the [contentTitle] row.
  ///
  /// [trailing] sits in the header, above the divider, so it reads as detached
  /// from [contentTitle]. Use this slot instead when the action belongs to the
  /// titled content — "Clear all" next to a selection title, for example.
  final Widget? contentTitleTrailing;

  /// Scroll controller from DraggableScrollableSheet (used when scrollable)
  final ScrollController? scrollController;

  /// Content widgets to display
  final List<Widget>? children;

  /// Custom body widget (alternative to children)
  final Widget? body;

  /// Builder function for custom scrollable content.
  ///
  /// Use this when you need direct access to the [ScrollController]
  /// for custom scroll behavior. Requires [scrollController] to be provided.
  final Widget Function(ScrollController scrollController)? buildScrollBody;

  /// Optional trailing widget in header (e.g., badge, button)
  final Widget? trailing;

  /// Optional callback invoked when the complete/check button is tapped.
  ///
  /// When provided, the header automatically shows a close (X) button on the
  /// left and a check button on the right. The close button dismisses the
  /// sheet; the check button awaits [onComplete] then dismisses the sheet.
  /// The check button shows a loading indicator while [onComplete] is running.
  final AsyncCallback? onComplete;

  /// Screen-reader label for the [onComplete] header's close (X) button.
  ///
  /// `divine_ui` carries no localizations, so callers pass a translated
  /// string; the default is the English fallback.
  final String closeSemanticLabel;

  /// Screen-reader label for the [onComplete] header's check button.
  ///
  /// `divine_ui` carries no localizations, so callers pass a translated
  /// string; the default is the English fallback.
  final String completeSemanticLabel;

  /// Optional bottom input section (e.g., comment input)
  final Widget? bottomInput;

  /// Whether the body should expand to fill available space.
  /// Set to false for simple content that should wrap.
  final bool expanded;

  /// Whether to show the divider below the header.
  ///
  /// Defaults to true.
  final bool showHeaderDivider;

  /// Whether to show the drag handle at the top of the header.
  ///
  /// Forwarded to [VineBottomSheetHeader.showDragHandle]. Defaults to true.
  final bool showDragHandle;

  /// Optional padding override forwarded to [VineBottomSheetHeader].
  final EdgeInsetsGeometry? headerPadding;

  /// Optional icon button on the left side of the header.
  ///
  /// Forwarded to [VineBottomSheetHeader.leadingAction].
  final DivineIconButton? headerLeadingAction;

  /// Optional icon button on the right side of the header.
  ///
  /// Forwarded to [VineBottomSheetHeader.trailingAction].
  final DivineIconButton? headerTrailingAction;

  /// Shows the bottom sheet as a modal.
  ///
  /// Set [scrollable] to false for fixed-height sheets (e.g., action menus).
  /// The size parameters are only used when [scrollable] is true.
  ///
  /// When [scrollable] is true, [snap] and [snapSizes] are forwarded to the
  /// underlying [DraggableScrollableSheet] to enable snap-to-position
  /// behaviour between user-defined fractions of the viewport.
  ///
  /// [useRootNavigator] is forwarded to [showModalBottomSheet]; set it to
  /// true when the sheet must appear above a nested navigator such as the
  /// tab shell.
  ///
  /// [tapOutsideToDismiss], when true (the default) and [scrollable] is
  /// true, wraps the sheet so that taps on the scrim above the sheet
  /// dismiss the modal. This compensates for
  /// [DraggableScrollableSheet]'s default `expand: true` behaviour, which
  /// otherwise absorbs barrier-tap events. Set to false to keep the
  /// original layout semantics (full-viewport draggable area, no outer
  /// tap-catcher). Has no effect in fixed mode — the standard modal
  /// barrier already dismisses on tap there.
  ///
  /// [headerLeadingAction] and [headerTrailingAction] are forwarded to
  /// [VineBottomSheetHeader] to place icon buttons on the left/right side of
  /// the header. When only one is set, the other side receives an invisible
  /// placeholder to keep the title centered.
  ///
  /// [contentWrapper] wraps the entire sheet subtree once. Useful for
  /// injecting a single `BlocProvider` / `InheritedWidget` above every
  /// slot (title, trailing, bottomInput, body, buildScrollBody) without
  /// having to re-wrap each slot individually at the call site.
  ///
  /// [draggableController] is forwarded to the underlying
  /// [DraggableScrollableSheet] so callers can programmatically animate
  /// the sheet between sizes (e.g. expand to [maxChildSize] when a form
  /// field is revealed). Has no effect in fixed (`scrollable: false`)
  /// mode.
  ///
  /// When [showDragHandle] is omitted, the handle follows [enableDrag]. The
  /// handle advertises the modal route's drag gesture, so a non-draggable
  /// sheet does not show an inert affordance by default. Pass an explicit
  /// value to override this behavior.
  static Future<T?> show<T>({
    required BuildContext context,
    List<Widget>? children,
    bool scrollable = true,
    bool showHeader = true,
    Widget? title,
    String? contentTitle,
    Widget? contentTitleTrailing,
    Widget? body,
    Widget Function(ScrollController scrollController)? buildScrollBody,
    Widget? trailing,
    AsyncCallback? onComplete,
    String closeSemanticLabel = 'Close',
    String completeSemanticLabel = 'Done',
    Widget? bottomInput,
    bool expanded = true,
    bool showHeaderDivider = true,
    bool? showDragHandle,
    EdgeInsetsGeometry? headerPadding,
    DivineIconButton? headerLeadingAction,
    DivineIconButton? headerTrailingAction,
    bool? isScrollControlled,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    bool snap = false,
    List<double>? snapSizes,
    bool useRootNavigator = false,
    bool tapOutsideToDismiss = true,
    Widget Function(BuildContext context, Widget child)? contentWrapper,
    VoidCallback? onShow,
    VoidCallback? onDismiss,
    bool isDismissible = true,
    bool enableDrag = true,
    DraggableScrollableController? draggableController,
  }) {
    // Call onShow callback before showing modal
    onShow?.call();
    assert(
      children != null || body != null || buildScrollBody != null,
      'Provide either children, body, or buildScrollBody to '
      'VineBottomSheet.show',
    );
    assert(
      scrollable || buildScrollBody == null,
      'buildScrollBody can only be used when scrollable is true',
    );
    assert(
      scrollable || !snap,
      'snap can only be used when scrollable is true',
    );
    assert(snapSizes == null || snap, 'snapSizes requires snap: true');

    // When `tapOutsideToDismiss` is explicitly disabled, also disable
    // Flutter's modal barrier dismissal so the two outside-tap mechanisms
    // stay consistent. Otherwise a caller that set `tapOutsideToDismiss:
    // false` would still see the sheet dismissed by barrier taps above the
    // DraggableScrollableSheet's content area.
    final effectiveIsDismissible = isDismissible && tapOutsideToDismiss;
    final effectiveShowDragHandle = showDragHandle ?? enableDrag;

    if (scrollable) {
      // Draggable/scrollable mode
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        isDismissible: effectiveIsDismissible,
        enableDrag: enableDrag,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        builder: (modalContext) {
          Widget buildSheet(ScrollController scrollController) {
            final Widget sheet = VineBottomSheet(
              showHeader: showHeader,
              title: title,
              contentTitle: contentTitle,
              contentTitleTrailing: contentTitleTrailing,
              scrollController: scrollController,
              buildScrollBody: buildScrollBody,
              trailing: trailing,
              onComplete: onComplete,
              closeSemanticLabel: closeSemanticLabel,
              completeSemanticLabel: completeSemanticLabel,
              bottomInput: bottomInput,
              expanded: expanded,
              showHeaderDivider: showHeaderDivider,
              showDragHandle: effectiveShowDragHandle,
              headerPadding: headerPadding,
              headerLeadingAction: headerLeadingAction,
              headerTrailingAction: headerTrailingAction,
              body: body,
              children: children,
            );
            return contentWrapper?.call(modalContext, sheet) ?? sheet;
          }

          // Default path preserves the original layout semantics
          // (`expand: true`, no outer tap-catcher).
          if (!tapOutsideToDismiss) {
            return DraggableScrollableSheet(
              controller: draggableController,
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              snap: snap,
              snapSizes: snapSizes,
              builder: (context, scrollController) =>
                  buildSheet(scrollController),
            );
          }

          // Tap-outside-to-dismiss path.
          //
          // Three layers each with a specific job:
          //   * Outer translucent GestureDetector — receives taps in the
          //     empty area above the sheet and pops the route.
          //   * `expand: false` on DraggableScrollableSheet — stops it from
          //     claiming the entire modal area, so the region above the
          //     sheet is free space the outer detector can own.
          //   * Inner opaque GestureDetector with an empty onTap — swallows
          //     taps on non-interactive sheet surfaces so they do not
          //     bubble up to the outer detector. Drags still win via
          //     gesture arena, and interactive children handle their own
          //     taps before bubbling.
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            // The route's ModalBarrier already publishes a localized
            // dismiss node; a second unlabeled one just adds noise.
            excludeFromSemantics: true,
            // coverage:ignore-start
            // Defensive fallback. In practice the modal barrier pops the
            // route first on taps above the DraggableScrollableSheet, so
            // this lambda rarely if ever fires — hence the coverage
            // exemption. Kept in place for scenarios where the barrier is
            // somehow non-dismissible but the sheet should still close on
            // an outside tap.
            onTap: () => Navigator.of(modalContext).pop(),
            // coverage:ignore-end
            child: DraggableScrollableSheet(
              controller: draggableController,
              expand: false,
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              snap: snap,
              snapSizes: snapSizes,
              builder: (context, scrollController) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Swallows taps for the gesture arena only — it performs
                  // no action, so it must not surface as a tappable node.
                  excludeFromSemantics: true,
                  onTap: () {},
                  child: buildSheet(scrollController),
                );
              },
            ),
          );
        },
      ).whenComplete(() => onDismiss?.call());
    } else {
      // Fixed mode
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled ?? expanded,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        isDismissible: effectiveIsDismissible,
        enableDrag: enableDrag,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        builder: (modalContext) {
          final Widget sheet = VineBottomSheet(
            scrollable: false,
            showHeader: showHeader,
            title: title,
            contentTitle: contentTitle,
            contentTitleTrailing: contentTitleTrailing,
            trailing: trailing,
            onComplete: onComplete,
            closeSemanticLabel: closeSemanticLabel,
            completeSemanticLabel: completeSemanticLabel,
            bottomInput: bottomInput,
            expanded: expanded,
            showHeaderDivider: showHeaderDivider,
            showDragHandle: effectiveShowDragHandle,
            headerPadding: headerPadding,
            headerLeadingAction: headerLeadingAction,
            headerTrailingAction: headerTrailingAction,
            body: body,
            children: children,
          );
          return contentWrapper?.call(modalContext, sheet) ?? sheet;
        },
      ).whenComplete(() => onDismiss?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: ColoredBox(
        color: context.vineColors.surface,
        child: scrollable
            ? _ScrollableContent(
                showHeader: showHeader,
                title: title,
                trailing: trailing,
                onComplete: onComplete,
                closeSemanticLabel: closeSemanticLabel,
                completeSemanticLabel: completeSemanticLabel,
                body: body,
                buildScrollBody: buildScrollBody,
                scrollController: scrollController,
                contentTitle: contentTitle,
                contentTitleTrailing: contentTitleTrailing,
                bottomInput: bottomInput,
                showHeaderDivider: showHeaderDivider,
                showDragHandle: showDragHandle,
                headerPadding: headerPadding,
                headerLeadingAction: headerLeadingAction,
                headerTrailingAction: headerTrailingAction,
                children: children,
              )
            : _FixedContent(
                showHeader: showHeader,
                title: title,
                trailing: trailing,
                onComplete: onComplete,
                closeSemanticLabel: closeSemanticLabel,
                completeSemanticLabel: completeSemanticLabel,
                body: body,
                contentTitle: contentTitle,
                contentTitleTrailing: contentTitleTrailing,
                bottomInput: bottomInput,
                showHeaderDivider: showHeaderDivider,
                showDragHandle: showDragHandle,
                headerPadding: headerPadding,
                headerLeadingAction: headerLeadingAction,
                headerTrailingAction: headerTrailingAction,
                children: children,
              ),
      ),
    );
  }
}

/// Standalone drag handle shown when [VineBottomSheet.showHeader] is false.
///
/// When [showDivider] is true, a 1 px divider is appended below the
/// handle padding so the sheet's drag-handle chrome remains visually
/// distinct from the content even when the content scrolls underneath.
class _HeaderlessDragHandle extends StatelessWidget {
  const _HeaderlessDragHandle({required this.showDivider});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 20),
          child: Center(child: VineBottomSheetDragHandle()),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: context.vineColors.isLight
                ? context.vineColors.outlineDisabled
                : const Color(0x0DFFFFFF),
          ),
      ],
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({
    required this.showHeader,
    required this.title,
    required this.trailing,
    required this.onComplete,
    required this.closeSemanticLabel,
    required this.completeSemanticLabel,
    required this.body,
    required this.buildScrollBody,
    required this.scrollController,
    required this.contentTitle,
    required this.contentTitleTrailing,
    required this.children,
    required this.bottomInput,
    required this.showHeaderDivider,
    this.showDragHandle = true,
    this.headerPadding,
    this.headerLeadingAction,
    this.headerTrailingAction,
  });

  final bool showHeader;
  final Widget? title;
  final Widget? trailing;
  final AsyncCallback? onComplete;
  final String closeSemanticLabel;
  final String completeSemanticLabel;
  final Widget? body;
  final Widget Function(ScrollController scrollController)? buildScrollBody;
  final ScrollController? scrollController;
  final String? contentTitle;
  final Widget? contentTitleTrailing;
  final List<Widget>? children;
  final Widget? bottomInput;
  final bool showHeaderDivider;
  final bool showDragHandle;
  final EdgeInsetsGeometry? headerPadding;
  final DivineIconButton? headerLeadingAction;
  final DivineIconButton? headerTrailingAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHeader)
          // Header with drag handle, title, trailing actions, and divider
          VineBottomSheetHeader(
            title: title,
            leading: onComplete != null
                ? _CloseButton(
                    onClose: () => Navigator.of(context).pop(),
                    semanticLabel: closeSemanticLabel,
                  )
                : null,
            trailing: onComplete != null
                ? _CompleteButton(
                    onComplete: onComplete!,
                    onDismiss: () => Navigator.of(context).pop(),
                    semanticLabel: completeSemanticLabel,
                  )
                : trailing,
            showDivider: showHeaderDivider,
            showDragHandle: showDragHandle,
            padding: headerPadding,
            leadingAction: headerLeadingAction,
            trailingAction: headerTrailingAction,
          )
        else if (showDragHandle)
          // Drag handle only — content manages its own layout below.
          // The divider is rendered inside _HeaderlessDragHandle (gated
          // by showHeaderDivider) so it stays pinned to the chrome.
          _HeaderlessDragHandle(showDivider: showHeaderDivider),

        // `body` and `buildScrollBody` hand the content area to the caller, so
        // the title cannot live inside their scroll view — it is pinned above
        // instead. Only the `children` path can scroll it away.
        if (contentTitle != null && children == null)
          _SheetContentTitle(contentTitle!, trailing: contentTitleTrailing),

        Expanded(
          child:
              body ??
              buildScrollBody?.call(scrollController!) ??
              ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Optional content title (56px total height)
                  if (contentTitle != null)
                    _SheetContentTitle(
                      contentTitle!,
                      trailing: contentTitleTrailing,
                    ),
                  ...children!,
                ],
              ),
        ),
        if (bottomInput != null)
          Divider(height: 2, color: context.vineColors.surfaceContainer),

        // Optional bottom input
        if (bottomInput != null)
          VineKeyboardAwareFooter(includeSafeArea: true, child: bottomInput!),
      ],
    );
  }
}

/// The `contentTitle` row: title at the start, optional action at the end.
///
/// 56px tall with a bare title; a taller [trailing] grows the row.
class _SheetContentTitle extends StatelessWidget {
  const _SheetContentTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _FixedContent extends StatelessWidget {
  const _FixedContent({
    required this.showHeader,
    required this.title,
    required this.trailing,
    required this.onComplete,
    required this.closeSemanticLabel,
    required this.completeSemanticLabel,
    required this.body,
    required this.contentTitle,
    required this.contentTitleTrailing,
    required this.children,
    required this.bottomInput,
    required this.showHeaderDivider,
    this.showDragHandle = true,
    this.headerPadding,
    this.headerLeadingAction,
    this.headerTrailingAction,
  });

  final bool showHeader;
  final Widget? title;
  final Widget? trailing;
  final AsyncCallback? onComplete;
  final String closeSemanticLabel;
  final String completeSemanticLabel;
  final Widget? body;
  final String? contentTitle;
  final Widget? contentTitleTrailing;
  final List<Widget>? children;
  final Widget? bottomInput;
  final bool showHeaderDivider;
  final bool showDragHandle;
  final EdgeInsetsGeometry? headerPadding;
  final DivineIconButton? headerLeadingAction;
  final DivineIconButton? headerTrailingAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader)
            // Header with drag handle and divider
            VineBottomSheetHeader(
              title: title,
              leading: onComplete != null
                  ? _CloseButton(
                      onClose: () => Navigator.of(context).pop(),
                      semanticLabel: closeSemanticLabel,
                    )
                  : null,
              trailing: onComplete != null
                  ? _CompleteButton(
                      onComplete: onComplete!,
                      onDismiss: () => Navigator.of(context).pop(),
                      semanticLabel: completeSemanticLabel,
                    )
                  : trailing,
              showDivider: showHeaderDivider,
              showDragHandle: showDragHandle,
              padding:
                  headerPadding ??
                  const EdgeInsetsDirectional.only(start: 24, end: 24, top: 8),
              leadingAction: headerLeadingAction,
              trailingAction: headerTrailingAction,
            )
          else if (showDragHandle)
            // Drag handle only — divider gated by showHeaderDivider.
            _HeaderlessDragHandle(showDivider: showHeaderDivider),

          // See the note in _ScrollableContent: a caller-supplied `body` owns
          // the content area, so the title is pinned above it.
          if (contentTitle != null && children == null)
            _SheetContentTitle(contentTitle!, trailing: contentTitleTrailing),

          // Fixed content area with minimum height for menu entries (2 × 56px)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child:
                  body ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Optional content title (56px total height)
                      if (contentTitle != null)
                        _SheetContentTitle(
                          contentTitle!,
                          trailing: contentTitleTrailing,
                        ),
                      ...children!,
                    ],
                  ),
            ),
          ),

          if (bottomInput != null)
            Divider(height: 2, color: context.vineColors.surfaceContainer),

          // Optional bottom input
          if (bottomInput != null)
            VineKeyboardAwareFooter(
              includeSafeArea: false,
              child: bottomInput!,
            ),
        ],
      ),
    );
  }
}

/// Close (X) button used in the header when [VineBottomSheet.onComplete]
/// is set.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose, required this.semanticLabel});

  final VoidCallback onClose;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: DivineIconName.x,
      type: DivineIconButtonType.secondary,
      size: DivineIconButtonSize.small,
      onPressed: onClose,
      semanticLabel: semanticLabel,
    );
  }
}

/// Check button used in the header when [VineBottomSheet.onComplete] is set.
///
/// Shows a loading indicator while the async [onComplete] callback runs,
/// then calls [onDismiss] to close the sheet.
class _CompleteButton extends StatefulWidget {
  const _CompleteButton({
    required this.onComplete,
    required this.onDismiss,
    required this.semanticLabel,
  });

  final AsyncCallback onComplete;
  final VoidCallback onDismiss;
  final String semanticLabel;

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        widget.onDismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.primary,
              semanticsLabel: widget.semanticLabel,
            ),
          ),
        ),
      );
    }

    return DivineIconButton(
      icon: DivineIconName.check,
      size: DivineIconButtonSize.small,
      onPressed: _handleTap,
      semanticLabel: widget.semanticLabel,
    );
  }
}
