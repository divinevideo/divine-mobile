// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/camera_permission_check.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/notification_badge.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shared bottom navigation bar used by AppShell and standalone profile screens.
class VineBottomNav extends ConsumerWidget {
  const VineBottomNav({required this.currentIndex, super.key});

  /// Currently selected tab index (0-3), or -1 if no tab is selected.
  final int currentIndex;

  /// Handles tab tap - navigates to last known position in that tab
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = routeTypeForTab(tabIndex);
    final lastIndex = ref
        .read(lastTabPositionProvider.notifier)
        .getPosition(routeType);

    // Log user interaction
    Log.info(
      '👆 User tapped bottom nav: tab=$tabIndex (${tabName(tabIndex)})',
      name: 'Navigation',
      category: LogCategory.ui,
    );

    // Re-tapping the active home tab refreshes the feed instead of
    // navigating. The cubit is provided above AppShell (see shell.dart).
    if (tabIndex == 0 && currentIndex == 0) {
      context.read<HomeFeedRetapCubit>().request();
      return;
    }

    // Pop any pushed routes first
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    // Navigate to last position in that tab
    if (tabIndex == 3) {
      // Navigate to own profile grid mode using actual npub (matches AppShell behavior).
      // When already on /profile/{npub}, GoRouter sees the same URL and no-ops.
      final authService = ref.read(authServiceProvider);
      final hex = authService.currentPublicKeyHex;
      if (hex != null) {
        final npub = NostrKeyUtils.encodePubKey(hex);
        context.go(ProfileScreenRouter.pathForNpub(npub));
      }
      return;
    }

    return switch (tabIndex) {
      1 => context.go(ExploreScreen.path),
      2 => context.go(InboxPage.path),
      _ => context.go(VideoFeedPage.pathForIndex(lastIndex ?? 0)),
    };
  }

  /// Combined unread count for the inbox tab (DMs + notifications).
  int _inboxUnreadCount(BuildContext context, WidgetRef ref) {
    final dmCount = context.watch<DmUnreadCountCubit>().state;
    final notifCount = context.watch<NotificationBadgeCubit>().state;
    return dmCount + notifCount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds only when the refreshing flag flips, not on every state emit.
    final isHomeRefreshing = context.select(
      (HomeFeedRetapCubit cubit) => cubit.state.isRefreshing,
    );
    return ColoredBox(
      // Same surface the shell paints behind its rounded corners.
      color: context.vineColors.nav,
      // The bottom nav has no Container padding — all four edges of the
      // breathing room around the icons are folded into adjacent tab hit
      // targets (see [_kTopExtraTapHeight], [_kBottomExtraTapHeight],
      // [_kHorizontalEdgePad]). [SafeArea] still keeps tap targets clear
      // of the iOS home indicator and Android navigation bar.
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Each tab's slot covers its icon plus half of each adjacent
            // inter-icon gap, so taps closer to a given icon than to its
            // neighbour route to that tab. Home and Profile additionally
            // span the [_kHorizontalEdgePad] strip out to the screen edge.
            // Icons sit at their Figma-specified positions.
            const iconWidth = kMinInteractiveDimension;
            const cameraWidth = _kCameraButtonWidth;
            const totalIconWidth = iconWidth * 4 + cameraWidth;
            const totalEdgePad = _kHorizontalEdgePad * 2;
            // 4 inter-icon gaps × 2 halves = 8.
            final halfGap =
                ((constraints.maxWidth - totalIconWidth - totalEdgePad) / 8)
                    .clamp(0.0, double.infinity);

            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: fixedRowTextScaleLimit,
              child: Row(
                children: [
                  _HomeTabButton(
                    semanticLabel: context.l10n.navHome,
                    isSelected: currentIndex == 0,
                    isRefreshing: isHomeRefreshing,
                    onTap: () => _handleTabTap(context, ref, 0),
                    tapTargetWidth: _kHorizontalEdgePad + iconWidth + halfGap,
                    iconAlignment: AlignmentDirectional.centerStart,
                    edgePadding: const EdgeInsetsDirectional.only(
                      start: _kHorizontalEdgePad,
                    ),
                  ),
                  _IconTabButton(
                    semanticIdentifier: SemanticIds.exploreTab,
                    semanticLabel: context.l10n.navExplore,
                    icon: DivineIconName.search,
                    isSelected: currentIndex == 1,
                    onTap: () => _handleTabTap(context, ref, 1),
                    tapTargetWidth: iconWidth + halfGap * 2,
                  ),
                  // Camera button in center of bottom nav
                  _CameraButton(
                    tapTargetWidth: cameraWidth + halfGap * 2,
                    onTap: () {
                      Log.info(
                        '👆 User tapped camera button',
                        name: 'Navigation',
                        category: LogCategory.ui,
                      );
                      context.pushToCameraWithPermission(
                        entryPoint: CreationEntryPoint.bottomNav,
                      );
                    },
                  ),
                  _IconTabButton(
                    semanticIdentifier: 'inbox_tab',
                    semanticLabel: context.l10n.navInbox,
                    icon: DivineIconName.chat,
                    isSelected: currentIndex == 2,
                    onTap: () => _handleTabTap(context, ref, 2),
                    tapTargetWidth: iconWidth + halfGap * 2,
                    badgeCount: _inboxUnreadCount(context, ref),
                  ),
                  _ProfileTabButton(
                    semanticLabel: context.l10n.navProfile,
                    isSelected: currentIndex == 3,
                    onTap: () => _handleTabTap(context, ref, 3),
                    tapTargetWidth: iconWidth + halfGap + _kHorizontalEdgePad,
                    iconAlignment: AlignmentDirectional.centerEnd,
                    edgePadding: const EdgeInsetsDirectional.only(
                      end: _kHorizontalEdgePad,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Visible width of the green camera-button pill in the bottom nav.
const double _kCameraButtonWidth = 72;

/// Extra hit-target height stacked above the [kMinInteractiveDimension]
/// icon row, so taps in the strip immediately above the visible icons
/// route to the tab below.
const double _kTopExtraTapHeight = 12;

/// Extra hit-target height stacked below the [kMinInteractiveDimension]
/// icon row (above the [SafeArea] inset), so taps in the strip
/// immediately beneath the visible icons route to the tab above.
const double _kBottomExtraTapHeight = 12;

/// Total vertical hit-target height per tab. The icon container sits at
/// the vertical centre of this slot — top and bottom extras are equal —
/// so taps both above and below the visible glyph route to the right tab.
const double _kTabSlotHeight =
    kMinInteractiveDimension + _kTopExtraTapHeight + _kBottomExtraTapHeight;

/// Lateral inset between the screen edge and the visible position of the
/// outermost icons (Home / Profile). Folded into Home's and Profile's hit
/// targets so taps inside the 16 px strip on the screen edge still route
/// to the adjacent tab.
const double _kHorizontalEdgePad = 16;

// =============================================================================
// Tab buttons
// =============================================================================
//
// The Figma component (node 5595:133692) specifies two tab-button shapes:
//   * **Icon tabs** (Home / Search / Inbox) — 48×48 tap target, 24×24 glyph,
//     selected = full opacity + shadow-10 drop shadows on the glyph,
//     unselected = 32 % opacity, no shadow.
//   * **Profile tab** — 48×48 tap target, 24×24 rounded-8 box,
//     lime fallback fill with the user's avatar on top. Selected and
//     unselected differ only in the outer border (2 px `onNav` vs 1 px
//     `onNavMuted`); no filter / opacity / shadow on the avatar
//     itself.

/// Shared hit-target + [Semantics] wrapper for every bottom-nav tab.
///
/// Holds the Figma hit geometry in one place: an opaque [GestureDetector]
/// filling [tapTargetWidth] × [_kTabSlotHeight] so taps in the surrounding
/// gap route to the right tab, with the visible [child] positioned by
/// [edgePadding] and [iconAlignment] (defaults centre the child, matching a
/// bare [Center]).
class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.identifier,
    required this.label,
    required this.onTap,
    required this.tapTargetWidth,
    required this.child,
    this.value,
    this.edgePadding = EdgeInsets.zero,
    this.iconAlignment = Alignment.center,
  });

  final String identifier;
  final String label;

  /// Optional [Semantics.value] — e.g. the unread badge count on the Inbox
  /// tab. Null on tabs that carry no supplementary value.
  final String? value;
  final VoidCallback onTap;

  /// Full width the [GestureDetector] occupies inside the nav row — usually
  /// larger than the visible icon so taps in the surrounding gap and edge
  /// strips also route to this tab.
  final double tapTargetWidth;

  /// Inset folded into the hit target on the outermost tabs (Home / Profile)
  /// so taps in the screen-edge strip still route to the adjacent tab.
  final EdgeInsetsGeometry edgePadding;
  final AlignmentGeometry iconAlignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      label: label,
      value: value,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: tapTargetWidth,
          height: _kTabSlotHeight,
          child: Padding(
            padding: edgePadding,
            child: Align(alignment: iconAlignment, child: child),
          ),
        ),
      ),
    );
  }
}

/// Home tab button that animates between the house icon and a spinning
/// refresh arrow while the feed is reloading after a retap.
///
/// On retap: house zooms out and fades, arrow fades in, zooms in, and spins.
/// On load complete: arrow fades out and shrinks back, house fades in and
/// zooms back to full size. Rotation always completes its current turn.
class _HomeTabButton extends StatefulWidget {
  const _HomeTabButton({
    required this.semanticLabel,
    required this.isSelected,
    required this.isRefreshing,
    required this.onTap,
    required this.tapTargetWidth,
    required this.iconAlignment,
    required this.edgePadding,
  });

  final String semanticLabel;
  final bool isSelected;
  final bool isRefreshing;
  final VoidCallback onTap;
  final double tapTargetWidth;
  final AlignmentGeometry iconAlignment;
  final EdgeInsetsGeometry edgePadding;

  @override
  State<_HomeTabButton> createState() => _HomeTabButtonState();
}

class _HomeTabButtonState extends State<_HomeTabButton>
    with TickerProviderStateMixin {
  // Controls house ↔ arrow cross-fade and scale (0 = house, 1 = arrow).
  late final AnimationController _swapController;
  // Controls continuous rotation of the arrow icon.
  late final AnimationController _rotationController;

  late final Animation<double> _houseOpacity;
  late final Animation<double> _houseScale;
  late final Animation<double> _arrowOpacity;
  late final Animation<double> _arrowScale;

  bool _didSyncInitialRefresh = false;

  @override
  void initState() {
    super.initState();

    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // House: full size + opaque at 0, scaled down + transparent at 1.
    _houseOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.easeInOut),
    );
    _houseScale = Tween<double>(begin: 1, end: 0.5).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.easeInOut),
    );

    // Arrow: transparent + small at 0, full size + opaque at 1.
    _arrowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.easeInOut),
    );
    _arrowScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the initial controller state on first mount. If the widget mounts
    // while a refresh is already in flight (the cubit outlives this widget),
    // start in the spinning-arrow state instead of the static house.
    // Subsequent transitions are handled by [didUpdateWidget]. This lives in
    // didChangeDependencies rather than initState because the sync reads
    // MediaQuery.disableAnimationsOf(context) via _startRefreshAnimation.
    if (!_didSyncInitialRefresh) {
      _didSyncInitialRefresh = true;
      if (widget.isRefreshing) _startRefreshAnimation();
    }
  }

  @override
  void dispose() {
    _swapController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _startRefreshAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: swap to the arrow instantly, without zoom or spin.
      _swapController.value = 1;
      return;
    }
    _swapController.forward();
    _rotationController.repeat();
  }

  void _stopRefreshAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _swapController.value = 0;
      _rotationController
        ..stop()
        ..value = 0;
      return;
    }
    // Let the current rotation complete before stopping.
    _rotationController.forward(from: _rotationController.value).then((_) {
      if (mounted) _rotationController.stop();
    });
    _swapController.reverse();
  }

  @override
  void didUpdateWidget(_HomeTabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _startRefreshAnimation();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _stopRefreshAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconBox = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(
        child: Opacity(
          opacity: widget.isSelected ? 1.0 : 0.32,
          child: AnimatedBuilder(
            animation: Listenable.merge([_swapController, _rotationController]),
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // House icon — fades out and shrinks on refresh.
                  Opacity(
                    opacity: _houseOpacity.value,
                    child: Transform.scale(
                      scale: _houseScale.value,
                      child: _ShadowedNavIcon(
                        icon: DivineIconName.houseSimple,
                        showShadow: widget.isSelected,
                      ),
                    ),
                  ),
                  // Refresh arrow — fades in, scales up, and rotates.
                  Opacity(
                    opacity: _arrowOpacity.value,
                    child: Transform.scale(
                      scale: _arrowScale.value,
                      child: Transform.rotate(
                        angle: _rotationController.value * 2 * pi,
                        child: DivineIcon(
                          icon: DivineIconName.arrowClockwise,
                          color: context.vineColors.onNav,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    return _TabSlot(
      identifier: 'home_tab',
      label: widget.semanticLabel,
      onTap: widget.onTap,
      tapTargetWidth: widget.tapTargetWidth,
      edgePadding: widget.edgePadding,
      iconAlignment: widget.iconAlignment,
      child: iconBox,
    );
  }
}

/// Tap target + Semantics wrapper shared by the Explore and Inbox tabs.
///
/// The child gets the 32 %-opacity dim in the unselected state and the
/// glyph-shaped shadow pair in the selected state. See [_ShadowedNavIcon].
///
/// [tapTargetWidth] is the full width the GestureDetector occupies inside
/// the bottom nav row — usually larger than the 48 px icon container so
/// taps in the surrounding gap also route to this tab. The icon itself
/// stays a centred [kMinInteractiveDimension]-sized box.
class _IconTabButton extends StatelessWidget {
  const _IconTabButton({
    required this.semanticIdentifier,
    required this.semanticLabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tapTargetWidth,
    this.badgeCount,
  });

  final String semanticIdentifier;
  final String semanticLabel;
  final DivineIconName icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double tapTargetWidth;

  /// When non-null, wraps the inner icon container in a [NotificationBadge]
  /// so the badge stays anchored to the icon's top-right corner rather
  /// than to the (potentially much wider) tap target. Pass `null` on tabs
  /// that never show a badge — that keeps `NotificationBadge` out of the
  /// widget tree entirely so finders downstream still match exactly one
  /// instance.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget iconBox = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(
        child: Opacity(
          // Figma: unselected tabs render at 32 % opacity; selected stays
          // at 100 %. No color tint — just dim + shadow toggle.
          opacity: isSelected ? 1.0 : 0.32,
          child: _ShadowedNavIcon(icon: icon, showShadow: isSelected),
        ),
      ),
    );

    if (badgeCount != null) {
      iconBox = NotificationBadge(count: badgeCount!, child: iconBox);
    }

    final semanticValue = badgeCount != null && badgeCount! > 0
        ? context.l10n.notificationsBadgeUnread(badgeCount!)
        : null;

    return _TabSlot(
      identifier: semanticIdentifier,
      label: semanticLabel,
      value: semanticValue,
      onTap: onTap,
      tapTargetWidth: tapTargetWidth,
      child: iconBox,
    );
  }
}

/// 24×24 [DivineIcon] that optionally paints the Figma `effects/shadow-10`
/// drop-shadow pair underneath the glyph. The shadow copies are
/// [DivineIcon]s tinted in [VineTheme.innerShadow] and blurred via
/// [ImageFiltered] so the shadow silhouette tracks the glyph, not the
/// bounding rect.
///
/// Same pattern as `_ShadowedIcon` in `video_action_button.dart` — when we
/// consolidate those, move to a shared `divine_ui` widget.
class _ShadowedNavIcon extends StatelessWidget {
  const _ShadowedNavIcon({required this.icon, required this.showShadow});

  final DivineIconName icon;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final glyph = DivineIcon(icon: icon, color: context.vineColors.onNav);
    if (!showShadow) return glyph;
    return Stack(
      alignment: Alignment.center,
      children: [
        _NavIconShadow(icon: icon, offset: const Offset(1, 1), blurSigma: 1),
        _NavIconShadow(
          icon: icon,
          offset: const Offset(0.4, 0.4),
          blurSigma: 0.6,
        ),
        glyph,
      ],
    );
  }
}

class _NavIconShadow extends StatelessWidget {
  const _NavIconShadow({
    required this.icon,
    required this.offset,
    required this.blurSigma,
  });

  final DivineIconName icon;
  final Offset offset;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        // Excluded from semantics — the foreground glyph carries the
        // accessibility node; these are decorative shadow copies.
        child: ExcludeSemantics(
          child: DivineIcon(icon: icon, color: VineTheme.innerShadow),
        ),
      ),
    );
  }
}

/// Profile tab: 24×24 rounded-8 box with a lime fallback background and
/// the currently-signed-in user's avatar on top. Selection state is
/// communicated only by the outer border (1 px `onNavMuted` →
/// 2 px `onNav`).
///
/// Falls back to the standard icon-tab treatment with [DivineIconName.userCircle]
/// when no user is signed in (e.g. during sign-out) or while the profile
/// is still loading.
class _ProfileTabButton extends ConsumerWidget {
  const _ProfileTabButton({
    required this.semanticLabel,
    required this.isSelected,
    required this.onTap,
    required this.tapTargetWidth,
    this.iconAlignment = Alignment.center,
    this.edgePadding = EdgeInsets.zero,
  });

  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final double tapTargetWidth;
  final AlignmentGeometry iconAlignment;

  /// See [_TabSlot.edgePadding].
  final EdgeInsetsGeometry edgePadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    final profile = pubkey == null
        ? null
        : ref.watch(userProfileReactiveProvider(pubkey)).value;
    final imageUrl = profile?.picture;
    final hasAvatar = imageUrl != null && isUsableNetworkImageUrl(imageUrl);

    final iconBox = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(
        child: hasAvatar
            ? _ProfileAvatarBox(imageUrl: imageUrl, isSelected: isSelected)
            // No signed-in avatar: render the same icon-tab treatment
            // (opacity dim / shadow) as Home / Search / Inbox so the
            // nav bar still feels uniform until the profile loads.
            : Opacity(
                opacity: isSelected ? 1.0 : 0.32,
                child: _ShadowedNavIcon(
                  icon: DivineIconName.userCircle,
                  showShadow: isSelected,
                ),
              ),
      ),
    );

    return _TabSlot(
      identifier: 'profile_tab',
      label: semanticLabel,
      onTap: onTap,
      tapTargetWidth: tapTargetWidth,
      edgePadding: edgePadding,
      iconAlignment: iconAlignment,
      child: iconBox,
    );
  }
}

/// The Figma profile-tab avatar box: 24×24 rounded-8 container with a
/// lime fallback fill and the user's avatar image on top. The two
/// variants differ only in the outer border — 1 px `onNavMuted`
/// when unselected, 2 px `onNav` when selected.
class _ProfileAvatarBox extends StatelessWidget {
  const _ProfileAvatarBox({required this.imageUrl, required this.isSelected});

  final String imageUrl;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        children: [
          // Lime base — visible through transparent pixels of the
          // avatar and while the image is still loading.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const ColoredBox(color: VineTheme.accentLime),
            ),
          ),
          // Avatar image, clipped to the rounded 8-px square.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VineCachedImage(imageUrl: imageUrl, width: 24, height: 24),
            ),
          ),
          // Border on top — 1 px `onNavMuted` when unselected,
          // 2 px `onNav` when selected. (No inset shadow / opacity / blend
          // — the avatar shows in full color in both states.)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? context.vineColors.onNav
                        : context.vineColors.onNavMuted,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera button in the center of the bottom navigation bar.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap, required this.tapTargetWidth});

  final VoidCallback onTap;
  final double tapTargetWidth;

  @override
  Widget build(BuildContext context) {
    // The pill is centred (default [_TabSlot] alignment) so it keeps its
    // on-screen position even though the slot is taller and wider than the
    // pill — the extra space all goes to hit-target absorption.
    return _TabSlot(
      identifier: 'camera_button',
      label: context.l10n.navOpenCamera,
      onTap: onTap,
      tapTargetWidth: tapTargetWidth,
      child: Container(
        width: _kCameraButtonWidth,
        height: kMinInteractiveDimension,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: VineTheme.cameraButtonGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const DivineIcon(icon: .cameraRetro, size: 32),
      ),
    );
  }
}
