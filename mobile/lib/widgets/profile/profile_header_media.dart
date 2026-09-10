part of 'profile_header_widget.dart';

/// Hero tag for the avatar ↔ lightbox shared-element flight, scoped to the
/// user. A global tag would let two profile headers with the same tag in one
/// navigator (e.g. other-profile → other-profile, both on the root navigator)
/// morph one user's avatar into another's during the page transition.
String _avatarHeroTag(String userIdHex) => 'profile_avatar_hero_$userIdHex';

/// Size and corner radius of the full-screen lightbox avatar.
const double _lightboxAvatarSize = 288;
const double _lightboxAvatarCornerRadius = 112;

/// Corner-radius-to-size ratio of the lightbox avatar, also matched by the
/// 144px header avatar (56px radius). The Hero flight reproduces this ratio at
/// every interpolated size so the corner stays proportional. The default
/// flight shuttle instead paints the destination's fixed 112px radius onto the
/// shrinking flight box, which clamps to a full circle while the box is smaller
/// than 224px and makes the avatar briefly round mid-flight.
const double _avatarHeroCornerRatio =
    _lightboxAvatarCornerRadius / _lightboxAvatarSize;

/// Matches the profile editor's locked banner crop and upload shape.
const double _profileBannerAspectRatio = 3;

class _AboutText extends StatefulWidget {
  const _AboutText({required this.about});

  final String about;

  /// Maximum lines to show when collapsed.
  static const int _collapsedMaxLines = 3;

  @override
  State<_AboutText> createState() => _AboutTextState();
}

class _AboutTextState extends State<_AboutText> {
  bool _isExpanded = false;
  bool _needsExpansion = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = VineTheme.bodyMediumFont(
      color: context.vineColors.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure if text exceeds max lines
        final textSpan = TextSpan(text: widget.about, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: _AboutText._collapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        _needsExpansion = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExpanded)
              SelectableLinkifiedText(text: widget.about, style: textStyle)
            else
              LinkifiedText(
                text: widget.about,
                style: textStyle,
                maxLines: _AboutText._collapsedMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            if (_needsExpansion)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isExpanded
                        ? context.l10n.profileShowLess
                        : context.l10n.profileShowMore,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The 334px background banner area. Shows a banner image, a color gradient,
/// or a plain dark background depending on what the profile provides.
///
/// Uses a foreground [BoxDecoration] gradient scrim instead of a [Stack] to
/// avoid parentData assertions during route transitions.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({
    required this.height,
    this.bannerUrl,
    this.profileColor,
    super.key,
  });

  final double height;
  final String? bannerUrl;
  final Color? profileColor;

  @override
  Widget build(BuildContext context) {
    // Gradient scrim that fades to the surface background at the bottom.
    // Applied as foregroundDecoration so it overlays the background content.
    final scrimDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          context.vineColors.surface.withValues(alpha: 0),
          context.vineColors.surface,
        ],
      ),
    );

    final fallback = _BannerFallback(
      height: height,
      profileColor: profileColor,
      scrimDecoration: scrimDecoration,
    );

    if (bannerUrl != null) {
      return _BannerImage(
        bannerUrl: bannerUrl!,
        height: height,
        scrimDecoration: scrimDecoration,
        fallback: fallback,
      );
    }

    return fallback;
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({
    required this.height,
    required this.profileColor,
    required this.scrimDecoration,
  });

  final double height;
  final Color? profileColor;
  final BoxDecoration scrimDecoration;

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = profileColor != null
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [profileColor!, profileColor!],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.vineColors.containerLow,
              context.vineColors.surface,
            ],
          );

    return Container(
      key: const ValueKey('profile_banner_fallback'),
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(gradient: backgroundGradient),
      foregroundDecoration: scrimDecoration,
    );
  }
}

/// Banner with a network image and a gradient scrim overlay.
/// Uses [VineCachedImage] so banner art benefits from the shared on-disk
/// cache layer instead of hitting the network on every rebuild.
class _BannerImage extends StatelessWidget {
  const _BannerImage({
    required this.bannerUrl,
    required this.height,
    required this.scrimDecoration,
    required this.fallback,
  });

  final String bannerUrl;
  final double height;
  final BoxDecoration scrimDecoration;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      foregroundDecoration: scrimDecoration,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: context.vineColors.surface),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final hasBoundedSize =
              constraints.hasBoundedWidth &&
              constraints.maxWidth > 0 &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight > 0;
          final logicalDecodeHeight = hasBoundedSize
              ? constraints.maxHeight >
                        constraints.maxWidth / _profileBannerAspectRatio
                    ? constraints.maxHeight
                    : constraints.maxWidth / _profileBannerAspectRatio
              : null;
          return VineCachedImage(
            imageUrl: bannerUrl,
            // Decode the app's 3:1 banner shape large enough for BoxFit.cover.
            // A contain-sized decode would be upscaled along the covering axis.
            memCacheWidth: logicalDecodeHeight != null
                ? (logicalDecodeHeight * _profileBannerAspectRatio * pixelRatio)
                      .ceil()
                : constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? (constraints.maxWidth * pixelRatio).ceil()
                : null,
            memCacheHeight: logicalDecodeHeight != null
                ? (logicalDecodeHeight * pixelRatio).ceil()
                : constraints.hasBoundedHeight && constraints.maxHeight > 0
                ? (constraints.maxHeight * pixelRatio).ceil()
                : null,
            resizePolicy: ResizeImagePolicy.fit,
            errorWidget: (_, _, _) => fallback,
          );
        },
      ),
    );
  }
}

/// Stats row displaying Followers, Following, Likes, and Loops with dividers.
///
/// Shows a skeleton for up to [_ProfileStatsRowState._skeletonTimeout] while
/// stats are being fetched. After the timeout the row keeps its columns
/// visible but renders a `—` placeholder for each count, rather than
/// shimmering indefinitely or collapsing the row (which would shift the
/// surrounding profile layout).
///
/// One shift is unavoidable and accepted: whether Loops is shown depends on
/// the count, which is not known until stats load. A visitor to a profile
/// under [profileLoopsVisibilityFloor] therefore sees four skeleton columns
/// resolve to three. Reserving the slot only for owners would move that shift
/// onto popular profiles instead of removing it, so the loading state stays
/// uniform and the settle is where the column count changes.
class _ProfileStatsRow extends StatefulWidget {
  const _ProfileStatsRow({
    required this.userIdHex,
    required this.displayName,
    required this.isOwnProfile,
    this.profileStats,
  });

  final String userIdHex;

  /// Whether the signed-in viewer owns this profile.
  ///
  /// Owners always see their own loop total, however small. A visitor only
  /// sees it once it is large enough to impress — see
  /// [profileLoopsVisibilityFloor].
  final bool isOwnProfile;

  final String? displayName;
  final ProfileStats? profileStats;

  @override
  State<_ProfileStatsRow> createState() => _ProfileStatsRowState();
}

class _ProfileStatsRowState extends State<_ProfileStatsRow> {
  static const _skeletonTimeout = Duration(seconds: 7);

  /// Two-digit placeholder painted behind the Skeletonizer shimmer while the
  /// real stats load. The number itself is never visible — it only sets the
  /// width of the skeleton bar.
  static const _skeletonPlaceholderCount = 99;

  Timer? _timer;
  bool _timeoutExpired = false;

  @override
  void initState() {
    super.initState();
    if (widget.profileStats == null) {
      _timer = Timer(_skeletonTimeout, () {
        if (mounted) setState(() => _timeoutExpired = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.profileStats == null;

    final hasLikes = widget.profileStats?.totalLikes != null;
    final totalViews = widget.profileStats?.totalViews;
    // A visitor landing on a new creator's profile should not be met by a
    // discouraging headline number. Owners keep theirs, and a total large
    // enough to impress still leads the row.
    final loopsAreVisible =
        totalViews != null &&
        (widget.isOwnProfile || totalViews >= profileLoopsVisibilityFloor);
    final hasLoops = loopsAreVisible;

    final l10n = context.l10n;
    final columns = <Widget>[
      if (hasLoops || isLoading)
        ProfileStatColumn(
          count: isLoading ? _skeletonPlaceholderCount : totalViews!,
          label: l10n.profileLoopsLabel,
          isLoading: isLoading && _timeoutExpired,
        ),
      if (hasLikes || isLoading)
        ProfileStatColumn(
          count: isLoading
              ? _skeletonPlaceholderCount
              : widget.profileStats!.totalLikes,
          label: l10n.profileLikesLabel,
          isLoading: isLoading && _timeoutExpired,
        ),
      // Followers / Following always render: the BLoC-backed columns own their
      // own loading state, and a null cached count means "not known yet"
      // rather than zero.
      if (isLoading)
        ProfileStatColumn(
          count: _skeletonPlaceholderCount,
          label: l10n.profileFollowingLabel,
          isLoading: _timeoutExpired,
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(widget.userIdHex),
          ),
        )
      else
        ProfileFollowingStat(
          pubkey: widget.userIdHex,
          displayName: widget.displayName,
          isOwnProfile: widget.isOwnProfile,
          initialCount: widget.profileStats!.following,
        ),
      if (isLoading)
        ProfileStatColumn(
          count: _skeletonPlaceholderCount,
          label: l10n.profileFollowersLabel,
          isLoading: _timeoutExpired,
          onTap: () => context.push(
            FollowersScreenRouter.pathForPubkey(widget.userIdHex),
          ),
        )
      else
        ProfileFollowersStat(
          pubkey: widget.userIdHex,
          displayName: widget.displayName,
          isOwnProfile: widget.isOwnProfile,
          initialCount: widget.profileStats!.followers,
        ),
    ];

    return Skeletonizer(
      enabled: isLoading && !_timeoutExpired,
      enableSwitchAnimation: true,
      effect: vineSkeletonEffectOf(context),
      child: Semantics(
        identifier: SemanticIds.profileStatsRow,
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              if (i > 0) const _StatDivider(),
              Expanded(child: columns[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vertical divider between stat columns.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: 44,
      child: ColoredBox(color: context.vineColors.outlineMuted),
    );
  }
}

/// Profile avatar with optional action label overlapping the bottom edge.
///
/// When [pendingActions] is non-empty, a pill-shaped label (e.g. "Secure
/// your account") is centred below the avatar. A red count badge appears
/// on the label when more than one action is pending. Tapping either the
/// avatar or the label triggers [onActionTap].
///
/// While [showSkeleton] is set the avatar is swapped for an [_AvatarBone] and
/// the pending-action label is dropped, so neither is tappable during the
/// loading window (#4163).
///
/// The swap is driven by that flag rather than by [Skeleton.replace] because
/// `Skeleton.replace` resolves against the enclosing [Skeletonizer]'s scope,
/// which sits above the switch animation's `AnimatedSwitcher`. The outgoing
/// half of the cross-fade would then rebuild into the real avatar too, putting
/// two [Hero]s with the same tag in the tree for the length of the animation.
class _ProfileAvatarWithColor extends StatelessWidget {
  const _ProfileAvatarWithColor({
    required this.imageUrl,
    required this.userIdHex,
    required this.showSkeleton,
    this.profileColor,
    this.pendingActions = const [],
    this.onActionTap,
  });

  final String? imageUrl;

  /// Hex pubkey used as the placeholder tone seed so the same user gets
  /// the same accent color here as in notifications and other surfaces.
  final String userIdHex;

  /// Whether the identity is still resolving. Mirrors the `enabled` flag of
  /// the [Skeletonizer] this widget sits under.
  final bool showSkeleton;

  final Color? profileColor;

  /// Ordered list of pending profile actions. The first action determines
  /// the label text and icon.
  final List<ProfileActionType> pendingActions;

  /// Called when the label or avatar is tapped.
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 144.0;
    final Widget avatar;
    if (showSkeleton) {
      avatar = const _AvatarBone(size: avatarSize);
    } else {
      final avatarWidget = UserAvatar(
        imageUrl: imageUrl,
        placeholderSeed: userIdHex,
        size: avatarSize,
      );
      final hasAvatar = imageUrl != null && imageUrl!.isNotEmpty;
      avatar = hasAvatar
          ? GestureDetector(
              onTap: () => _showAvatarLightbox(
                context,
                imageUrl: imageUrl,
                userIdHex: userIdHex,
              ),
              child: Hero(
                tag: _avatarHeroTag(userIdHex),
                flightShuttleBuilder: (_, _, _, _, _) =>
                    _AvatarHeroFlightShuttle(
                      imageUrl: imageUrl,
                      userIdHex: userIdHex,
                    ),
                child: avatarWidget,
              ),
            )
          : avatarWidget;
    }

    if (pendingActions.isEmpty) return avatar;

    // The label overlaps the avatar bottom, so we need extra space below.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Reserve space for label overflow below the avatar.
        const SizedBox(width: avatarSize, height: avatarSize + 16),
        avatar,
        if (!showSkeleton)
          Positioned(
            bottom: 0,
            child: Semantics(
              identifier: SemanticIds.profilePendingAction,
              button: true,
              child: GestureDetector(
                onTap: onActionTap,
                child: _ProfileActionLabel(
                  action: pendingActions.first,
                  badgeCount: pendingActions.length,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Stand-in painted in place of the avatar while the identity loads: a flat
/// tile in the avatar's own geometry with the brand mark animating on top.
///
/// [Skeletonizer] repaints leaf shapes with the shimmer but keeps the
/// decoration of every container that has children, so shimmering the real
/// [UserAvatar] leaves its generated placeholder — a gradient tile with a
/// person silhouette cut into it — showing through the sweep.
class _AvatarBone extends StatelessWidget {
  const _AvatarBone({required this.size});

  /// Diameter of the brand mark centred on the tile.
  static const double _markSize = 64;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Positioned.fill because a childless DecoratedBox takes the
          // smallest size its constraints allow, and Stack hands
          // non-positioned children loose ones — the tile would collapse to
          // nothing.
          Positioned.fill(
            child: Skeleton.leaf(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.skeleton,
                  borderRadius: BorderRadius.circular(
                    UserAvatar.cornerRadiusForSize(size),
                  ),
                ),
              ),
            ),
          ),
          // Skeleton.keep, not .ignore: `ignore` paints nothing while the
          // enclosing Skeletonizer is enabled, which is the only time this
          // widget is on screen.
          const Skeleton.keep(child: BrandedLoadingIndicator(size: _markSize)),
        ],
      ),
    );
  }
}

/// Pill-shaped label shown below the profile avatar for the highest-priority
/// pending action. Displays an icon and text matching the action type, with
/// an optional red badge when multiple actions are pending.
class _ProfileActionLabel extends StatelessWidget {
  const _ProfileActionLabel({required this.action, required this.badgeCount});

  final ProfileActionType action;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (action) {
      ProfileActionType.accountRestricted => (
        DivineIconName.warning,
        context.l10n.profileAccountRestricted,
      ),
      ProfileActionType.secureAccount => (
        DivineIconName.lockSimple,
        context.l10n.profileSecureYourAccount,
      ),
      ProfileActionType.completeProfile => (
        DivineIconName.pencilSimple,
        context.l10n.profileCompleteYourProfile,
      ),
    };

    final chip = action == ProfileActionType.accountRestricted
        ? context.vineColors.accentChipOrange
        : context.vineColors.accentChipYellow;
    final maxWidth = MediaQuery.sizeOf(context).width - 32;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          decoration: BoxDecoration(
            color: chip.container,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              DivineIcon(icon: icon, size: 16, color: chip.onContainer),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.titleSmallFont(color: chip.onContainer),
                ),
              ),
            ],
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: VineTheme.error,
                borderRadius: BorderRadius.circular(1000),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount.toString(),
                style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar lightbox
// ---------------------------------------------------------------------------

class _AvatarHeroFlightShuttle extends StatelessWidget {
  const _AvatarHeroFlightShuttle({required this.userIdHex, this.imageUrl});

  final String? imageUrl;
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest.shortestSide;
        return UserAvatar(
          imageUrl: imageUrl,
          placeholderSeed: userIdHex,
          size: boxSize,
          cornerRadius: boxSize * _avatarHeroCornerRatio,
        );
      },
    );
  }
}

void _showAvatarLightbox(
  BuildContext context, {
  required String userIdHex,
  String? imageUrl,
}) {
  // Push on the root navigator so the full-screen blurred backdrop covers the
  // bottom navigation bar: on the own-profile tab the nearest navigator is the
  // StatefulShellRoute branch, confined to the Scaffold body. (The previous
  // showGeneralDialog used useRootNavigator: true for the same reason.) The
  // Hero flight still runs across the boundary because Flutter collects heroes
  // from the current PageRoute of nested navigators, so the header avatar
  // (branch) and the lightbox (root) are matched. A PageRoute — not a
  // PopupRoute like showGeneralDialog — is required for the HeroController.
  Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      barrierDismissible: true,
      barrierLabel: context.l10n.profileAvatarLightboxBarrierLabel,
      pageBuilder: (context, _, _) =>
          _AvatarLightbox(imageUrl: imageUrl, userIdHex: userIdHex),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _AvatarLightbox extends StatelessWidget {
  const _AvatarLightbox({required this.userIdHex, this.imageUrl});

  final String? imageUrl;

  /// Pubkey used as the placeholder seed so the lightbox's fallback
  /// colour matches the avatar everywhere else when the image fails.
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Semantics(
      label: context.l10n.profileAvatarLightboxCloseSemanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.expand(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ColoredBox(
              color: VineTheme.scrim65,
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: _avatarHeroTag(userIdHex),
                      child: UserAvatar(
                        imageUrl: imageUrl,
                        placeholderSeed: userIdHex,
                        size: _lightboxAvatarSize,
                        cornerRadius: _lightboxAvatarCornerRadius,
                      ),
                    ),
                  ),
                  Positioned(
                    top: safeAreaTop + 12,
                    left: 12,
                    child: DivineIconButton(
                      icon: DivineIconName.x,
                      type: DivineIconButtonType.ghostOverMedia,
                      size: DivineIconButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
