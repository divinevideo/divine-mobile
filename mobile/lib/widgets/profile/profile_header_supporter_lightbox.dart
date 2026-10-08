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

/// Header avatar of another user's supporter profile.
///
/// The whole group — avatar, wings and halo — is the Hero, so the treatment
/// flies into the supporter lightbox and keeps moving instead of being left
/// behind on the profile.
class _SupporterAvatarHero extends StatelessWidget {
  const _SupporterAvatarHero({
    required this.userIdHex,
    required this.avatarSize,
    required this.avatar,
    this.imageUrl,
  });

  final String? imageUrl;
  final String userIdHex;
  final double avatarSize;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.supporterLightboxBadge,
      child: GestureDetector(
        onTap: () => _showSupporterLightbox(
          context,
          imageUrl: imageUrl,
          userIdHex: userIdHex,
        ),
        child: Hero(
          tag: _avatarHeroTag(userIdHex),
          createRectTween: _supporterRectTween,
          flightShuttleBuilder: _supporterShuttle(imageUrl, userIdHex),
          child: SupporterHaloWings(
            avatarSize: avatarSize,
            builder: (_, _) => avatar,
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
      sparkles: CurvedAnimation(
        parent: animation,
        curve: _supporterSparkleReveal,
      ),
      builder: (_, _) => UserAvatar(
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
  String? imageUrl,
}) {
  _runProfileDetached(
    _awaitProfileResult(
      Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: VineTheme.transparent,
          barrierDismissible: true,
          barrierLabel: context.l10n.profileAvatarLightboxBarrierLabel,
          pageBuilder: (context, _, _) =>
              _SupporterLightbox(imageUrl: imageUrl, userIdHex: userIdHex),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    ),
    'open supporter lightbox',
  );
}

/// Full-screen view of another user's supporter avatar, explaining what the
/// status means and inviting the viewer to become a supporter too.
class _SupporterLightbox extends StatelessWidget {
  const _SupporterLightbox({required this.userIdHex, this.imageUrl});

  final String? imageUrl;
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = context.vineColors;
    final route = ModalRoute.of(context)!.animation!;
    final reveal = context.reduceMotion
        ? route
        : CurvedAnimation(parent: route, curve: _supporterContentReveal);
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
              Positioned.fill(
                child: Semantics(
                  label: context.l10n.profileAvatarLightboxCloseSemanticLabel,
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Padding(
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
                      child: Column(
                        children: [
                          _SupporterLightboxHeadline(userIdHex: userIdHex),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.supporterLightboxBody,
                            textAlign: TextAlign.center,
                            style: VineTheme.bodyLargeFont(
                              color: colors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const _SupporterBenefits(),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: reveal,
                      child: const _SupporterLightboxActions(),
                    ),
                  ],
                ),
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

class _SupporterLightboxAvatar extends StatelessWidget {
  const _SupporterLightboxAvatar({required this.userIdHex, this.imageUrl});

  final String? imageUrl;
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    const size = _supporterLightboxAvatarSize;
    return Hero(
      tag: _avatarHeroTag(userIdHex),
      createRectTween: _supporterRectTween,
      flightShuttleBuilder: _supporterShuttle(imageUrl, userIdHex),
      child: SupporterHaloWings(
        avatarSize: size,
        sparkles: kAlwaysCompleteAnimation,
        builder: (_, _) => UserAvatar(
          imageUrl: imageUrl,
          placeholderSeed: userIdHex,
          size: size,
          cornerRadius: size * _avatarHeroCornerRatio,
          previewDecodeSize: _headerAvatarSize,
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
        // A name that leads the sentence gets a line of its own, as in the
        // design; otherwise it flows inline.
        if (template.startsWith(_nameToken)) {
          spans.add(const TextSpan(text: '\n'));
        }
      }
      final pieces = part.trimLeft().split(_badgeToken);
      for (final (badgeIndex, piece) in pieces.indexed) {
        if (badgeIndex > 0) {
          spans.add(
            TextSpan(
              text: l10n.supporterLightboxBadge,
              style: style.copyWith(color: VineTheme.vineGreen),
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.iconButton,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: DivineIcon(
                  icon: icon,
                  color: colors.accentBrand,
                ),
              ),
            ),
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

/// The call to action, hidden when the viewer already supports Divine.
class _SupporterLightboxActions extends ConsumerWidget {
  const _SupporterLightboxActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supporterApiConfiguredProvider)) {
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
