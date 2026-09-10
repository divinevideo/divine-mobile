// ABOUTME: Content widget for the More sheet with animated transitions
// ABOUTME: Manages menu and block/unblock confirmation states

import 'package:flutter/material.dart';

import 'package:openvine/widgets/profile/more_sheet/block_confirmation_view.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_menu.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/more_sheet/unblock_confirmation_view.dart';

/// The current mode of the More sheet.
enum MoreSheetMode {
  /// Shows the main menu with copy, unfollow, block options.
  menu,

  /// Shows the block confirmation view.
  blockConfirmation,

  /// Shows the unblock confirmation view.
  unblockConfirmation,
}

/// Content widget for the More sheet that manages menu and confirmation states.
///
/// Provides smooth animated transitions between menu and confirmation views.
class MoreSheetContent extends StatefulWidget {
  /// Creates a More sheet content widget.
  const MoreSheetContent({
    required this.userIdHex,
    required this.displayName,
    required this.isFollowing,
    required this.isBlocked,
    this.initialMode = MoreSheetMode.menu,
    this.showAddToList = false,
    this.showReport = false,
    this.showBlock = true,
    this.showCopy = true,
    this.showEmbedCode = false,
    super.key,
  });

  /// The hex public key of the user.
  final String userIdHex;

  /// The display name of the user.
  final String displayName;

  /// Whether the current user is following this user.
  final bool isFollowing;

  /// Whether this user is blocked.
  final bool isBlocked;

  /// The initial mode to display.
  final MoreSheetMode initialMode;

  /// Whether to show the "Add to list" action (curated-lists feature flag).
  final bool showAddToList;

  /// Whether to show the "Report" action.
  ///
  /// Hidden on the current user's own profile, where reporting yourself
  /// is meaningless.
  final bool showReport;

  /// Whether to show the "Block"/"Unblock" action.
  ///
  /// Defaults to true — every profile surface offers it. A group DM thread
  /// passes false: block takes one account, and that sheet is opened from a
  /// room whose name is not any one member's.
  final bool showBlock;

  /// Whether to show the "Copy public key" action.
  ///
  /// Defaults to true. A group DM passes false because this sheet's key is
  /// the first member's key, not the room's identity.
  final bool showCopy;

  /// Whether to show the "Get embed code" action.
  ///
  /// Own-profile only. Defaults to false. Independent of [showBlock] — a
  /// caller that wants both sets both explicitly.
  final bool showEmbedCode;

  @override
  State<MoreSheetContent> createState() => _MoreSheetContentState();
}

class _MoreSheetContentState extends State<MoreSheetContent>
    with SingleTickerProviderStateMixin {
  late MoreSheetMode _targetMode;
  late MoreSheetMode _displayedMode;
  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  /// End of the fade-out phase as a fraction of [_controller]'s duration.
  /// Shared with the [Interval] below so the content swap and the fade can
  /// never drift apart if the duration changes.
  static const _fadeOutEnd = 0.333;

  @override
  void initState() {
    super.initState();
    _targetMode = widget.initialMode;
    _displayedMode = widget.initialMode;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Fade out menu: 0-250ms (0.0-0.333 of total)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, _fadeOutEnd, curve: Curves.easeOut),
      ),
    );

    // Fade in confirmation: 500-750ms (0.667-1.0 of total)
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.addListener(_swapDisplayedModeAfterFadeOut);
  }

  /// Shows the target content once the fade-out phase has finished.
  ///
  /// A [CurvedAnimation] over an [Interval] reports its *parent's* status, not
  /// the interval's, so an [AnimationStatus] listener on [_fadeOutAnimation]
  /// would not fire until the whole transition ended. The controller's own
  /// value is the signal.
  void _swapDisplayedModeAfterFadeOut() {
    if (_displayedMode == _targetMode) return;
    if (_controller.value < _fadeOutEnd) return;
    setState(() => _displayedMode = _targetMode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _transitionTo(MoreSheetMode mode) {
    setState(() => _targetMode = mode);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    // If we started directly in a non-menu mode, show content at full opacity
    final startedInConfirmation = widget.initialMode != MoreSheetMode.menu;
    if (startedInConfirmation) {
      return _buildContent();
    }

    final isTransitioning = _targetMode != MoreSheetMode.menu;

    return SingleChildScrollView(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final opacity = isTransitioning
                ? (_displayedMode != MoreSheetMode.menu
                      ? _fadeInAnimation.value
                      : 0.0)
                : _fadeOutAnimation.value;

            return Opacity(
              opacity: isTransitioning ? opacity : _fadeOutAnimation.value,
              child: _buildContent(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_displayedMode) {
      case MoreSheetMode.menu:
        return _buildMenu();
      case MoreSheetMode.blockConfirmation:
        return _buildBlockConfirmation();
      case MoreSheetMode.unblockConfirmation:
        return _buildUnblockConfirmation();
    }
  }

  Widget _buildMenu() {
    return MoreSheetMenu(
      displayName: widget.displayName,
      isFollowing: widget.isFollowing,
      isBlocked: widget.isBlocked,
      onCopy: widget.showCopy
          ? () => Navigator.of(context).pop(MoreSheetResult.copy)
          : null,
      onUnfollow: () => Navigator.of(context).pop(MoreSheetResult.unfollow),
      onBlockTap: widget.showBlock
          ? () {
              if (widget.isBlocked) {
                _transitionTo(MoreSheetMode.unblockConfirmation);
              } else {
                _transitionTo(MoreSheetMode.blockConfirmation);
              }
            }
          : null,
      onAddToList: widget.showAddToList
          ? () => Navigator.of(context).pop(MoreSheetResult.addToList)
          : null,
      onReport: widget.showReport
          ? () => Navigator.of(context).pop(MoreSheetResult.report)
          : null,
      onEmbedCode: widget.showEmbedCode
          ? () => Navigator.of(context).pop(MoreSheetResult.embedCode)
          : null,
    );
  }

  Widget _buildBlockConfirmation() {
    return BlockConfirmationView(
      displayName: widget.displayName,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () =>
          Navigator.of(context).pop(MoreSheetResult.blockConfirmed),
    );
  }

  Widget _buildUnblockConfirmation() {
    return UnblockConfirmationView(
      displayName: widget.displayName,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () =>
          Navigator.of(context).pop(MoreSheetResult.unblockConfirmed),
    );
  }
}
