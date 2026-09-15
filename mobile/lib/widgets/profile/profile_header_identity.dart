part of 'profile_header_widget.dart';

class _ProfileNameAndBio extends StatelessWidget {
  const _ProfileNameAndBio({
    required this.profile,
    required this.userIdHex,
    required this.nip05,
    required this.about,
    required this.isOwnProfile,
    required this.monetizationLinks,
    this.displayNameHint,
    this.isVanished = false,
    this.accentColor,
  });

  final UserProfile? profile;
  final String userIdHex;
  final String? nip05;
  final String? about;
  final bool isOwnProfile;

  /// Storefront-filtered tip/support links for the displayed profile.
  final List<MonetizationLink> monetizationLinks;

  final String? displayNameHint;

  /// Whether the account behind [userIdHex] has requested NIP-62 deletion.
  ///
  /// Suppresses the generated-from-pubkey fallback name: for a deleted account
  /// that fallback reads as a real (if odd) handle rather than as an absence.
  final bool isVanished;

  /// Optional accent color (from profile color) for links/buttons.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final website = profile?.website;
    final showWebsite = website?.isNotEmpty == true;
    // Every child except the badge row carries the horizontal inset. The
    // badge block spans the full width so its row can scroll edge-to-edge.
    const inset = EdgeInsets.symmetric(
      horizontal: _profileIdentityHorizontalInset,
    );
    return Column(
      children: [
        Padding(
          padding: inset,
          child: Column(
            children: [
              _ProfileHeaderNameRow(
                isVanished: isVanished,
                profile: profile,
                userIdHex: userIdHex,
                isOwnProfile: isOwnProfile,
                displayNameHint: displayNameHint,
              ),
              Skeleton.keep(
                child: _UniqueIdentifier(
                  userIdHex: userIdHex,
                  nip05: nip05,
                  isOwnProfile: isOwnProfile,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ),
        Skeleton.keep(child: _ProfileBadgesBlock(userIdHex: userIdHex)),
        Padding(
          padding: inset,
          child: Column(
            children: [
              _ProfileHeaderReveal(
                child: about != null && about!.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Skeleton.keep(child: _AboutText(about: about!)),
                      )
                    : null,
              ),
              Skeleton.keep(
                child: _ProfileSupportButton(links: monetizationLinks),
              ),
              _ProfileHeaderReveal(
                child: showWebsite
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Skeleton.keep(
                          child: ProfileWebsiteRow(url: website!),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        _VerifiedAccountsBlock(isOwnProfile: isOwnProfile),
      ],
    );
  }
}

String? _ownProfileNamePlaceholder({
  required bool isOwnProfile,
  required String? displayNameHint,
  required String userIdHex,
}) {
  if (!isOwnProfile) return null;
  final hint = displayNameHint?.trim();
  if (hint != null && hint.isNotEmpty) return hint;
  return NostrKeyUtils.encodePubKey(userIdHex);
}

/// Horizontal inset applied to the name/bio identity block. Shared so the
/// badge row can break out of it and scroll edge-to-edge.
const double _profileIdentityHorizontalInset = 16;

class _ProfileHeaderNameRow extends ConsumerWidget {
  const _ProfileHeaderNameRow({
    required this.isVanished,
    required this.profile,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.displayNameHint,
  });

  final bool isVanished;
  final UserProfile? profile;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayNameHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyle = VineTheme.titleLargeFont(
      color: context.vineColors.primaryText,
    );
    // Every chit beside the name is gated on !isVanished for the reason the
    // comment below gives: all three rosters are compiled in, so none of them
    // can drop an account that vanishes after release. Only the beta chit
    // carried the gate until now, which left a vanished team pubkey rendering
    // "Deleted account" with a checkmark beside it.
    final isOgViner =
        !isVanished &&
        ref.watch(
          ogVinerCacheServiceProvider.select(
            (service) => service.isOgViner(userIdHex),
          ),
        );
    final showCheckmark =
        !isVanished && shouldShowSpecialProfileCheckmark(userIdHex);
    // The beta chit yields to both the checkmark and the OG Viner chit, so a
    // name never carries two of them. The Viner rosters are disjoint by
    // construction; many team accounts also appear on the beta roster, so the
    // checkmark still has to be checked here.
    // A vanished account renders profileDeletedAccountName, so a chit beside
    // it is incoherent. The roster is compiled in and cannot drop anyone who
    // vanishes after release, so the gate has to live here.
    final isOgBetaTester =
        !isVanished &&
        !isOgViner &&
        !showCheckmark &&
        isOgBetaTesterPubkey(userIdHex);
    final name = isVanished
        // Deliberately not a UserName: that widget re-resolves the profile
        // through its own provider and falls back to a generated handle, which
        // is exactly what must not appear.
        ? Text(context.l10n.profileDeletedAccountName, style: textStyle)
        : profile != null
        ? UserName.fromUserProfile(
            profile!,
            style: textStyle,
            // A kind-0 with empty name and display_name still falls through to
            // the generated handle without this (#6423). Use the route hint,
            // then the full npub, as the non-generated steady state so the
            // header never renders a blank title.
            anonymousName: _ownProfileNamePlaceholder(
              isOwnProfile: isOwnProfile,
              displayNameHint: displayNameHint,
              userIdHex: userIdHex,
            ),
            neverGenerateName: isOwnProfile,
            showProfileBadges: false,
          )
        : UserName.fromPubKey(
            userIdHex,
            style: textStyle,
            anonymousName:
                _ownProfileNamePlaceholder(
                  isOwnProfile: isOwnProfile,
                  displayNameHint: displayNameHint,
                  userIdHex: userIdHex,
                ) ??
                displayNameHint,
            // Never show the signed-in user a generated handle in place of
            // their own name — that is the #6423 report verbatim.
            neverGenerateName: isOwnProfile,
            showProfileBadges: false,
          );

    if (!isOgViner && !isOgBetaTester && !showCheckmark) return name;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: name),
        if (showCheckmark)
          const _ProfileHeaderBadgeExplanationButton(
            type: ProfileBadgeExplanationType.profileCheckmark,
          ),
        if (isOgViner)
          const _ProfileHeaderBadgeExplanationButton(
            type: ProfileBadgeExplanationType.ogViner,
          ),
        if (isOgBetaTester)
          const _ProfileHeaderBadgeExplanationButton(
            type: ProfileBadgeExplanationType.ogBetaTester,
          ),
      ],
    );
  }
}

/// Diameter of a header badge. Sized off the 22px display name beside it,
/// where the inline badges elsewhere sit beside much smaller name rows.
const double _profileHeaderBadgeDiameter = 22;

/// Padding between the checkmark glyph and the edge of its filled circle.
const double _checkmarkRing = 4;

/// A profile badge in the header name row, tappable for its explainer.
///
/// Renders the same badge the feed and inline name rows show, so a checkmark
/// reads identically wherever it appears. The header is the one place with
/// room for a real touch target, so only here it opens the explainer.
class _ProfileHeaderBadgeExplanationButton extends StatelessWidget {
  const _ProfileHeaderBadgeExplanationButton({required this.type});

  final ProfileBadgeExplanationType type;

  @override
  Widget build(BuildContext context) {
    final title = type.title(context.l10n);
    return Semantics(
      label: title,
      value: type.body(context.l10n),
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: () => showProfileBadgeExplanationSheet(context, type),
          child: Tooltip(
            message: title,
            // Same text as the label; announcing it twice adds nothing.
            excludeFromSemantics: true,
            child: SizedBox.square(
              // The badge itself is smaller than the 48dp minimum, so the
              // box around it — not the badge — carries the touch target.
              dimension: DivineIcon.scaleSize(context, 48),
              child: Center(child: ExcludeSemantics(child: type.badge)),
            ),
          ),
        ),
      ),
    );
  }
}

extension on ProfileBadgeExplanationType {
  String title(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.ogVinerBadgeLabel,
      ProfileBadgeExplanationType.ogBetaTester => l10n.ogBetaTesterBadgeLabel,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkTitle,
    };
  }

  String body(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.profileBadgeOgVinerBody,
      ProfileBadgeExplanationType.ogBetaTester =>
        l10n.profileBadgeOgBetaTesterBody,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkBody,
    };
  }

  Widget get badge {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => const OgVinerBadge(
        size: _profileHeaderBadgeDiameter,
        leadingGap: 0,
      ),
      ProfileBadgeExplanationType.ogBetaTester => const OgBetaBadge(
        size: _profileHeaderBadgeDiameter,
        leadingGap: 0,
      ),
      // The checkmark sizes from the inside out: glyph plus ring padding.
      ProfileBadgeExplanationType.profileCheckmark =>
        const SpecialProfileCheckmark(
          iconSize: _profileHeaderBadgeDiameter - _checkmarkRing * 2,
          padding: _checkmarkRing,
          leadingGap: 0,
        ),
    };
  }
}

/// Grows a late-arriving header block into place instead of snapping it in.
///
/// The profile, its verified claims, and its badges all resolve after the
/// header has painted, each on its own timing. Revealing them over a short
/// window keeps everything below — bio, stats row, action buttons, grid —
/// sliding down smoothly rather than jumping.
///
/// A null [child] is the empty state. The wrapper stays mounted at zero
/// height so the arrival it is waiting for has a size to animate from;
/// dropping it from the tree instead would mount the content at full size.
class _ProfileHeaderReveal extends StatelessWidget {
  const _ProfileHeaderReveal({this.child});

  static const _duration = Duration(milliseconds: 220);

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // The empty state spans the full width so only the height animates.
    final content = child ?? const SizedBox(width: double.infinity);
    // Drop the animators entirely under reduce motion rather than passing
    // them Duration.zero: a zero-duration AnimatedSize completes its
    // controller synchronously inside performLayout, which re-dirties the
    // render object mid-layout and trips a framework assertion.
    if (MediaQuery.disableAnimationsOf(context)) return content;

    return AnimatedSize(
      duration: _duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: _duration, child: content),
    );
  }
}

class _ProfileBadgesBlock extends ConsumerWidget {
  const _ProfileBadgesBlock({required this.userIdHex});

  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A refresh keeps the badges it already had; a first load and an outright
    // error read as "no badges". Most profiles have none, so reserving a
    // placeholder row would trade one jump for a worse one.
    final items =
        ref.watch(profileAcceptedBadgesProvider(userIdHex)).value ??
        const <ProfileBadgeViewData>[];
    return _ProfileHeaderReveal(
      child: items.isEmpty ? null : _ProfileBadgesRow(items: items),
    );
  }
}

class _ProfileBadgesRow extends StatelessWidget {
  const _ProfileBadgesRow({required this.items});

  final List<ProfileBadgeViewData> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The block spans the full width (its siblings carry the horizontal
          // inset instead), so the row scrolls edge-to-edge. A resting lead
          // keeps chips aligned with the text above while letting them peek
          // past the screen edge once they overflow.
          const inset = _profileIdentityHorizontalInset;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: inset),
            // Centered when the badges fit; scrollable once they overflow.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - inset * 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  for (final item in items) _ProfileBadgeChip(badge: item),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileBadgeChip extends StatelessWidget {
  const _ProfileBadgeChip({required this.badge});

  final ProfileBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    final imageUrl = badge.imageUrl;
    final l10n = context.l10n;
    const radius = 16.0;
    return Semantics(
      button: true,
      label: l10n.profileBadgeSemanticLabel(badge.displayName),
      child: Material(
        color: context.vineColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: context.vineColors.isLight
                ? context.vineColors.outlineMuted
                : VineTheme.neutral10,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showProfileBadgeSheet(context, badge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileBadgeImage(
                    imageUrl: imageUrl,
                    semanticLabel: badge.displayName,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      badge.displayName,
                      style: VineTheme.labelMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _ProfileBadgeImage extends StatelessWidget {
  const _ProfileBadgeImage({
    required this.imageUrl,
    this.size = 20,
    this.semanticLabel,
  });

  final String? imageUrl;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ?? context.l10n.profileBadgeFallbackSemanticLabel;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.vineGreen,
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            'B',
            style: VineTheme.labelSmallFont(color: VineTheme.primaryDarkGreen),
          ),
        ),
      ),
    );

    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl == null || imageUrl!.isEmpty
              ? fallback
              : ClipOval(
                  child: VineCachedImage(
                    imageUrl: imageUrl!,
                    width: size,
                    height: size,
                    errorWidget: (_, _, _) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

void _showProfileBadgeSheet(BuildContext context, ProfileBadgeViewData badge) {
  _runProfileDetached(
    _awaitProfileResult(
      VineBottomSheet.show<void>(
        context: context,
        showHeaderDivider: false,
        body: _ProfileBadgeDetailsSheet(badge: badge),
      ),
    ),
    'show profile badge sheet',
  );
}

class _ProfileBadgeDetailsSheet extends StatelessWidget {
  const _ProfileBadgeDetailsSheet({required this.badge});

  static const _maxVisibleRecipients = 12;

  final ProfileBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    final issuerPubkey = badge.issuerPubkey;
    final recipients = badge.uniqueRecipientPubkeys;
    final visibleRecipients = recipients.take(_maxVisibleRecipients).toList();
    final hiddenRecipientCount = recipients.length - visibleRecipients.length;
    final description = badge.description?.trim();
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileBadgeImage(
                    imageUrl: badge.imageUrl,
                    size: 56,
                    semanticLabel: badge.displayName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.displayName,
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.onSurface,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: VineTheme.bodyMediumFont(
                              color: context.vineColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (issuerPubkey != null && issuerPubkey.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ProfileBadgeSheetSectionTitle(l10n.profileBadgeAwardedBy),
                UserProfileTile(
                  pubkey: issuerPubkey,
                  showFollowButton: false,
                  onTap: () =>
                      _openProfileFromBadgeSheet(context, issuerPubkey),
                ),
              ],
              if (recipients.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ProfileBadgeSheetSectionTitle(l10n.profileBadgeRecipients),
                for (final recipientPubkey in visibleRecipients)
                  UserProfileTile(
                    pubkey: recipientPubkey,
                    showFollowButton: false,
                    onTap: () =>
                        _openProfileFromBadgeSheet(context, recipientPubkey),
                  ),
                if (hiddenRecipientCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      l10n.profileBadgeMoreRecipients(hiddenRecipientCount),
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text(
                l10n.profileBadgeFooterBody,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              DivineButton(
                label: l10n.profileBadgeFooterLink,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                leadingIcon: DivineIconName.plus,
                onPressed: () => _openBadgeEditorFromBadgeSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBadgeSheetSectionTitle extends StatelessWidget {
  const _ProfileBadgeSheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        text,
        style: VineTheme.labelMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

void _openProfileFromBadgeSheet(BuildContext context, String pubkey) {
  final path = OtherProfileScreen.pathForNpub(
    NostrKeyUtils.encodePubKey(pubkey),
  );
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  _runProfileDetached(
    _awaitProfileResult(router.push(path)),
    'open badge recipient profile',
  );
}

void _openBadgeEditorFromBadgeSheet(BuildContext context) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  // Seat the dashboard under the editor. The editor pops itself once the
  // badge is published, and landing back on someone's profile reads as if
  // nothing happened — the new badge is on the dashboard.
  _runProfileDetached(
    _awaitProfileResult(router.push(BadgesScreen.path)),
    'open badges dashboard',
  );
  _runProfileDetached(
    _awaitProfileResult(router.push(BadgeEditorScreen.createPath)),
    'open badge editor',
  );
}

class _VerifiedAccountsBlock extends StatelessWidget {
  const _VerifiedAccountsBlock({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final claims = isOwnProfile
        ? _readMyClaims(context)
        : _readOtherClaims(context);
    return _ProfileHeaderReveal(
      child: claims.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: VerifiedAccountsRow(
                claims: claims,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                center: true,
              ),
            ),
    );
  }

  static List<IdentityClaim> _readMyClaims(BuildContext context) {
    try {
      return context.select<MyProfileBloc, List<IdentityClaim>>((bloc) {
        final state = bloc.state;
        if (state is MyProfileLoaded) return state.verifiedClaims;
        if (state is MyProfileUpdated) return state.verifiedClaims;
        if (state is MyProfileLoading) return state.verifiedClaims;
        return const [];
      });
    } on ProviderNotFoundException {
      return const [];
    }
  }

  static List<IdentityClaim> _readOtherClaims(BuildContext context) {
    try {
      return context.select<OtherProfileBloc, List<IdentityClaim>>((bloc) {
        final state = bloc.state;
        if (state is OtherProfileLoaded) return state.verifiedClaims;
        if (state is OtherProfileLoading) return state.verifiedClaims;
        return const [];
      });
    } on ProviderNotFoundException {
      return const [];
    }
  }
}

/// Unique identifier display (NIP-05 or full npub with ellipsis).
/// Uses profile accent color when available, falls back to vineGreen.
/// Shows warning for failed NIP-05 verification on own profile.
/// Hides unverified NIP-05s for other profiles (potential impersonation).
class _UniqueIdentifier extends ConsumerWidget {
  const _UniqueIdentifier({
    required this.userIdHex,
    required this.nip05,
    required this.isOwnProfile,
    this.accentColor,
  });

  final String userIdHex;
  final String? nip05;
  final bool isOwnProfile;

  /// Optional accent color (from profile color) for the link text and icon.
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNip05 = nip05 != null && nip05!.isNotEmpty;
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    final linkColor = context.vineColors.accentPositive;

    // Watch NIP-05 verification status
    final verificationStatus = hasNip05
        ? ref
              .watch(nip05VerificationProvider(userIdHex))
              .whenOrNull(data: (status) => status)
        : null;

    final verificationFailed =
        verificationStatus == Nip05VerificationStatus.failed;

    // For other profiles: hide unverified NIP-05s (show npub instead)
    // For own profile: show with warning so user knows there's an issue
    final String displayText;
    if (hasNip05) {
      if (verificationFailed && !isOwnProfile) {
        // Don't show unverified NIP-05s for other users - potential impersonation
        displayText = truncateNpubForDisplay(npub);
      } else {
        displayText = nip05!;
      }
    } else {
      displayText = truncateNpubForDisplay(npub);
    }

    return GestureDetector(
      onTap: () {
        final verifiedNip05 = hasNip05 && !verificationFailed ? nip05 : null;
        final profileUrl = buildProfileUrl(verifiedNip05, npub);
        _runProfileDetached(
          ClipboardUtils.copy(
            context,
            profileUrl,
            message: context.l10n.profileLinkCopied,
          ),
          'copy profile link',
        );
      },
      child: Text(
        displayText,
        style: VineTheme.bodyMediumFont(color: linkColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Maximum characters of a raw npub to show before the ellipsis when it is
/// used as the fallback identifier on the profile screen.
const int profileNpubMaxChars = 16;

/// Trim a raw npub for the profile identifier row.
///
/// Shows the first [profileNpubMaxChars] characters followed by an ellipsis
/// when the npub is longer than that. Used only when no NIP-05 / divine
/// username is available (or the NIP-05 is unverified on another user's
/// profile).
String truncateNpubForDisplay(String npub) {
  if (npub.length <= profileNpubMaxChars) return npub;
  return '${npub.substring(0, profileNpubMaxChars)}...';
}

/// Build a shareable profile URL.
///
/// If the user has a `.divine.video` NIP-05 subdomain (e.g. `_@thomas.divine.video`),
/// returns `https://thomas.divine.video`. Otherwise falls back to
/// `https://divine.video/profile/{npub}`.
@visibleForTesting
String buildProfileUrl(String? nip05, String npub) {
  if (nip05 != null && nip05.isNotEmpty) {
    // NIP-05 format: `_@username.divine.video` or `user@domain.com`
    final atIndex = nip05.indexOf('@');
    if (atIndex != -1) {
      final domain = nip05.substring(atIndex + 1);
      if (domain.endsWith('.divine.video')) {
        return 'https://$domain';
      }
    }
  }
  return 'https://divine.video/profile/$npub';
}

/// About/bio text display with expandable "Show more/less" functionality.
