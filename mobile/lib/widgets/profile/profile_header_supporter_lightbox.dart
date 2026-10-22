part of 'profile_header_widget.dart';

/// Avatar size in the supporter lightbox. Smaller than the plain lightbox so
/// the wings, the headline and the call to action fit on one screen.
const double _supporterLightboxAvatarSize = 192;

/// Share of the route transition after which the text and buttons fade in,
/// so they arrive once the avatar has landed and leave first on close.
const Interval _supporterContentReveal = Interval(
  0.6,
  1,
  curve: Curves.easeOut,
);

/// Share of the route transition over which the sparkles fade in.
const Interval _supporterSparkleReveal = Interval(0.4, 1);

/// Header avatar of a supporter's profile.
///
/// The whole group — avatar, wings and halo — is the Hero, so the treatment
/// flies into the supporter lightbox and keeps moving instead of being left
/// behind on the profile.
class _SupporterAvatarHero extends StatelessWidget {
  const _SupporterAvatarHero({
    required this.userIdHex,
    required this.avatarSize,
    required this.avatar,
    required this.reveal,
    required this.isOwnProfile,
    this.imageUrl,
  });

  final String? imageUrl;
  final String userIdHex;
  final double avatarSize;
  final Widget avatar;

  /// Owned outside the Hero, which remounts its child when a flight lands.
  final Animation<double> reveal;

  /// Opens the owner's own supporter view rather than the one other viewers
  /// see.
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.supporterTitle,
      child: GestureDetector(
        onTap: () => _showSupporterLightbox(
          context,
          imageUrl: imageUrl,
          userIdHex: userIdHex,
          isOwnProfile: isOwnProfile,
        ),
        child: Hero(
          tag: _avatarHeroTag(userIdHex),
          createRectTween: _supporterRectTween,
          flightShuttleBuilder: _supporterShuttle(imageUrl, userIdHex),
          child: SupporterHaloWings(
            avatarSize: avatarSize,
            reveal: reveal,
            avatar: avatar,
          ),
        ),
      ),
    );
  }
}

/// The group in flight: laid out once at its lightbox size and scaled as a
/// single piece, so the wings and halo can never drift from the avatar while
/// the Hero box grows or shrinks.
HeroFlightShuttleBuilder _supporterShuttle(String? imageUrl, String userIdHex) {
  return (context, animation, _, _, _) => FittedBox(
    child: SupporterHaloWings(
      avatarSize: _supporterLightboxAvatarSize,
      // A driven tween, unlike a CurvedAnimation, adds no listener to the
      // route animation that would outlive this flight.
      sparkles: animation.drive(CurveTween(curve: _supporterSparkleReveal)),
      avatar: UserAvatar(
        imageUrl: imageUrl,
        placeholderSeed: userIdHex,
        size: _supporterLightboxAvatarSize,
        cornerRadius: _supporterLightboxAvatarSize * _avatarHeroCornerRatio,
        decodeSize: _headerAvatarSize,
      ),
    ),
  );
}

/// A straight-line Hero path. The default arc reshapes the box mid-flight,
/// which would stretch the group out of proportion.
RectTween _supporterRectTween(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end);

void _showSupporterLightbox(
  BuildContext context, {
  required String userIdHex,
  required bool isOwnProfile,
  String? imageUrl,
}) {
  _pushAvatarLightbox(
    context,
    _SupporterLightbox(
      imageUrl: imageUrl,
      userIdHex: userIdHex,
      isOwnProfile: isOwnProfile,
    ),
    'open supporter lightbox',
  );
}

/// Full-screen view of a supporter's avatar. Other viewers see what the
/// status means and an invitation to join; the owner sees their membership.
class _SupporterLightbox extends StatelessWidget {
  const _SupporterLightbox({
    required this.userIdHex,
    required this.isOwnProfile,
    this.imageUrl,
  });

  final String? imageUrl;
  final String userIdHex;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = context.vineColors;
    final route = ModalRoute.of(context)!.animation!;
    // Driven rather than a CurvedAnimation, which would add a listener to the
    // route animation on every rebuild and never remove it.
    final reveal = context.reduceMotion
        ? route
        : route.drive(CurveTween(curve: _supporterContentReveal));
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      // Text here needs a Material ancestor for its default style; the route
      // sits on the root navigator, above the app's scaffolds.
      child: Material(
        color: colors.background.withValues(alpha: 0.92),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 0.8,
              colors: [
                VineTheme.vineGreen.withValues(alpha: 0.18),
                VineTheme.vineGreen.withValues(alpha: 0),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Scrolls only when short screens or large text overflow it.
              CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    // Tapping the backdrop closes; the labelled close button
                    // is the accessible route, so this stays out of semantics.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          padding.top + 72,
                          24,
                          padding.bottom + 16,
                        ),
                        child: Column(
                          children: [
                            const Spacer(),
                            _SupporterLightboxAvatar(
                              imageUrl: imageUrl,
                              userIdHex: userIdHex,
                            ),
                            const SizedBox(height: 30),
                            FadeTransition(
                              opacity: reveal,
                              child: isOwnProfile
                                  ? const _OwnSupporterDetails()
                                  : _SupporterDetails(userIdHex: userIdHex),
                            ),
                            const Spacer(),
                            if (!isOwnProfile)
                              FadeTransition(
                                opacity: reveal,
                                child: const _SupporterLightboxActions(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: padding.top + 12,
                left: 12,
                child: DivineIconButton(
                  icon: DivineIconName.x,
                  type: DivineIconButtonType.ghostSecondary,
                  size: DivineIconButtonSize.small,
                  semanticLabel:
                      context.l10n.profileAvatarLightboxCloseSemanticLabel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What another user's supporter status means.
class _SupporterDetails extends StatelessWidget {
  const _SupporterDetails({required this.userIdHex});

  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SupporterLightboxHeadline(userIdHex: userIdHex),
        const SizedBox(height: 12),
        Text(
          context.l10n.supporterLightboxBody,
          textAlign: TextAlign.center,
          style: VineTheme.bodyLargeFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        const _SupporterBenefits(),
      ],
    );
  }
}

/// The owner's own membership, in the words of the Supporter settings.
class _OwnSupporterDetails extends StatelessWidget {
  const _OwnSupporterDetails();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Column(
      children: [
        Text(
          l10n.supporterHeroTitle,
          textAlign: TextAlign.center,
          style: VineTheme.headlineSmallFont(color: colors.primaryText),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.supporterMembershipBody,
          textAlign: TextAlign.center,
          style: VineTheme.bodyLargeFont(color: colors.secondaryText),
        ),
        const SizedBox(height: 32),
        MergeSemantics(
          child: Row(
            spacing: 12,
            children: [
              const _SupporterIconBadge(DivineIconName.heart),
              Expanded(
                child: Text(
                  l10n.supporterActiveBadge,
                  style: VineTheme.bodyLargeFont(color: colors.primaryText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupporterLightboxAvatar extends StatelessWidget {
  const _SupporterLightboxAvatar({required this.userIdHex, this.imageUrl});

  final String? imageUrl;
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    const size = _supporterLightboxAvatarSize;
    // The wings make the group wider than some phones allow; scale it as one
    // piece there rather than let the wings slide over the avatar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Hero(
        tag: _avatarHeroTag(userIdHex),
        createRectTween: _supporterRectTween,
        flightShuttleBuilder: _supporterShuttle(imageUrl, userIdHex),
        child: SupporterHaloWings(
          avatarSize: size,
          sparkles: kAlwaysCompleteAnimation,
          avatar: UserAvatar(
            imageUrl: imageUrl,
            placeholderSeed: userIdHex,
            size: size,
            cornerRadius: size * _avatarHeroCornerRatio,
            previewDecodeSize: _headerAvatarSize,
          ),
        ),
      ),
    );
  }
}

/// "{name} is a Divine Supporter", with the name resolved like everywhere
/// else and the status in the brand accent, in whatever order the
/// translation puts them.
class _SupporterLightboxHeadline extends StatelessWidget {
  const _SupporterLightboxHeadline({required this.userIdHex});

  final String userIdHex;

  static const String _nameToken = '\u0001';
  static const String _badgeToken = '\u0002';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final style = VineTheme.headlineSmallFont(color: colors.primaryText);
    final template = l10n.supporterLightboxHeadline(_nameToken, _badgeToken);
    final spans = <InlineSpan>[];
    for (final (index, part) in template.split(_nameToken).indexed) {
      var text = part;
      if (index > 0) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: UserName.fromPubKey(
              userIdHex,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              showProfileBadges: false,
            ),
          ),
        );
        // Give a leading name its own line only at a word boundary. Attached
        // honorifics (for example in Japanese and Korean) stay with the name.
        if (template.startsWith(_nameToken) && text.startsWith(RegExp(r'\s'))) {
          spans.add(const TextSpan(text: '\n'));
          // The break replaces that space; a name mid-sentence keeps its own.
          text = text.trimLeft();
        }
      }
      final pieces = text.split(_badgeToken);
      for (final (badgeIndex, piece) in pieces.indexed) {
        if (badgeIndex > 0) {
          spans.add(
            TextSpan(
              text: l10n.supporterLightboxBadge,
              style: style.copyWith(color: colors.accentBrand),
            ),
          );
        }
        spans.add(TextSpan(text: piece));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _SupporterBenefits extends StatelessWidget {
  const _SupporterBenefits();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        _SupporterBenefit(
          icon: DivineIconName.heart,
          label: l10n.supporterLightboxBenefitIndependent,
        ),
        _SupporterBenefit(
          icon: DivineIconName.users,
          label: l10n.supporterLightboxBenefitFeatures,
        ),
        _SupporterBenefit(
          icon: DivineIconName.paintBrush,
          label: l10n.supporterLightboxBenefitCommunity,
        ),
      ],
    );
  }
}

class _SupporterBenefit extends StatelessWidget {
  const _SupporterBenefit({required this.icon, required this.label});

  final DivineIconName icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Expanded(
      child: MergeSemantics(
        child: Column(
          spacing: 12,
          children: [
            _SupporterIconBadge(icon),
            Text(
              label,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(color: colors.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon in the filled circle the supporter view's benefits share.
class _SupporterIconBadge extends StatelessWidget {
  const _SupporterIconBadge(this.icon);

  final DivineIconName icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.iconButton,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DivineIcon(icon: icon, color: colors.accentBrand),
      ),
    );
  }
}

/// The call to action, hidden when the viewer already supports Divine.
class _SupporterLightboxActions extends ConsumerWidget {
  const _SupporterLightboxActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) {
      return const _SupporterLightboxButtons();
    }
    // A guest has no membership to read, and reading one would start the
    // store connection behind it.
    ref.watch(currentAuthStateProvider);
    if (!ref.watch(authServiceProvider).isAuthenticated) {
      return const _SupporterLightboxButtons();
    }
    final repository = ref.watch(supporterRepositoryProvider);
    return BlocProvider(
      key: ValueKey(repository),
      create: (_) =>
          SupporterCubit(repository: repository)..start(loadStore: false),
      child: BlocSelector<SupporterCubit, SupporterState, bool>(
        selector: (state) => state.isSupporter,
        builder: (context, isSupporter) => isSupporter
            ? const SizedBox.shrink()
            : const _SupporterLightboxButtons(),
      ),
    );
  }
}

class _SupporterLightboxButtons extends StatelessWidget {
  const _SupporterLightboxButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      spacing: 8,
      children: [
        DivineButton(
          label: l10n.supporterJoinLabel,
          expanded: true,
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            _runProfileDetached(
              _awaitProfileResult(router.push<Object?>(SupporterScreen.path)),
              'open supporter screen',
            );
          },
        ),
        const _SupporterMaybeLater(),
      ],
    );
  }
}

/// Low-emphasis dismiss under the call to action: plain text, not a button.
class _SupporterMaybeLater extends StatelessWidget {
  const _SupporterMaybeLater();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: Text(
              context.l10n.supporterLightboxMaybeLater,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Provides the supporter status every part of the header reads, from one
/// request per profile: the halo and wings show only where the profile's
/// supporter status is public, so a profile looks the same to its owner as
/// to everyone else.
///
/// The owner's profile also gets their membership, which carries a change
/// to their public setting as soon as it is saved.
class _SupporterStatusScope extends ConsumerWidget {
  const _SupporterStatusScope({
    required this.pubkey,
    required this.isOwnProfile,
    required this.enabled,
    required this.child,
  });

  final String pubkey;
  final bool isOwnProfile;

  /// False for a deleted account, which never shows supporter status.
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled || !ref.watch(supporterApiConfiguredProvider)) return child;
    final scoped = isOwnProfile
        ? SupporterMembershipScope(child: child)
        : child;
    final client = ref.watch(supporterApiClientProvider);
    if (client == null) return scoped;
    return BlocProvider(
      key: ValueKey((client, pubkey)),
      // Eager, so the request runs while the profile itself still loads;
      // the header reads the result only once that load has finished.
      lazy: false,
      create: (_) {
        final cubit = PublicSupporterCubit(client: client, pubkey: pubkey);
        unawaited(cubit.load());
        return cubit;
      },
      child: scoped,
    );
  }
}

/// Whether the header shows the halo and wings: the profile's public
/// supporter status. On the owner's profile, their membership answers as
/// soon as it is known, so changing the public setting shows straight away.
/// False while loading and outside a [_SupporterStatusScope].
bool _showsSupporterTreatment(
  BuildContext context, {
  required bool isOwnProfile,
}) {
  if (isOwnProfile) {
    final own = _ownPublicRecognition(context);
    if (own != null) return own;
  }
  return context.select<PublicSupporterCubit?, bool>(
    (cubit) => cubit?.state ?? false,
  );
}

/// The owner's published supporter status, or null until their account has
/// been read.
bool? _ownPublicRecognition(BuildContext context) {
  return context.select<SupporterCubit?, bool?>((cubit) {
    final state = cubit?.state;
    if (state == null || state.snapshot == null) return null;
    return state.isSupporter && state.haloVisible;
  });
}
