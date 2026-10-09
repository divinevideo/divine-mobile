part of 'share_action_button.dart';

/// Placeholder rows shown (skeletonized) while the real contacts load, so the
/// shimmer has the same avatar + name shape it dissolves into — instead of a
/// spinner that pops. See #5391.
final List<ShareableUser> _skeletonContacts = List.generate(
  6,
  (_) => const ShareableUser(pubkey: '', displayName: 'Username'),
);
const ShareableUser _skeletonContact = ShareableUser(
  pubkey: '',
  displayName: 'Username',
);

// ---------------------------------------------------------------------------
// "Share with" horizontal contact row
// ---------------------------------------------------------------------------

class _ShareWithSection extends StatelessWidget {
  const _ShareWithSection({
    required this.contacts,
    required this.contactsLoaded,
    required this.selectedPubkeys,
    required this.onFindPeople,
    required this.onContactTapped,
  });

  final List<ShareableUser> contacts;
  final bool contactsLoaded;
  final Set<String> selectedPubkeys;
  final VoidCallback onFindPeople;
  final ValueChanged<ShareableUser> onContactTapped;

  static const double _itemWidth = 72;
  static const double _avatarSize = 48;
  static const double _avatarRadius = _avatarSize * 0.286;
  static const double _rowHeight = 90;

  @override
  Widget build(BuildContext context) {
    // While loading, render placeholder rows so the shimmer matches the real
    // avatar + name layout it will dissolve into.
    final displayContacts = contactsLoaded ? contacts : _skeletonContacts;

    return Semantics(
      identifier: SemanticIds.shareWithSection,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.shareWithTitle,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: _rowHeight,
              // Skeleton contacts shimmer, then dissolve into the real list when
              // it loads (enableSwitchAnimation), instead of a spinner that pops.
              child: IdentitySkeletonizer(
                isLoading: !contactsLoaded,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // +1 for the always-present "Find people" entry.
                  itemCount: displayContacts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Keep "Find people" solid + tappable during the shimmer.
                      return Skeleton.keep(
                        child: _FindPeopleItem(onTap: onFindPeople),
                      );
                    }

                    final contact = displayContacts[index - 1];
                    final isPendingIdentity =
                        !contactsLoaded || !contact.hasVisibleIdentity;
                    if (isPendingIdentity) {
                      // Placeholder bone — not interactive, excluded from a11y.
                      return IgnorePointer(
                        child: ExcludeSemantics(
                          child: IdentitySkeletonizer(
                            isLoading: true,
                            child: _ContactItem(
                              user: _skeletonContact,
                              isSelected: false,
                              onTap: (_) {},
                            ),
                          ),
                        ),
                      );
                    }

                    return Semantics(
                      identifier: SemanticIds.shareContact(index - 1),
                      child: _ContactItem(
                        user: contact,
                        isSelected: selectedPubkeys.contains(contact.pubkey),
                        onTap: onContactTapped,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindPeopleItem extends StatelessWidget {
  const _FindPeopleItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.shareFindPeople,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _ShareWithSection._itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: _ShareWithSection._avatarSize,
                height: _ShareWithSection._avatarSize,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    _ShareWithSection._avatarRadius,
                  ),
                ),
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ),
              Text(
                context.l10n.shareFindPeopleMultiline,
                style: TextStyle(
                  color: context.vineColors.secondaryText,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One contact in the "Share with" row.
///
/// The row is a DM send target — tapping it selects a recipient that
/// `ShareSheetBloc` hands to `DmRepository.sendMessage` — so it resolves its
/// peer through the same chain the inbox rows use, and hands the *resolved*
/// [ShareableUser] to [onTap] so the selection chip, the screen-reader
/// announcement and the success snackbar all name the same account (#8421).
class _ContactItem extends ConsumerWidget {
  const _ContactItem({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final ShareableUser user;
  final bool isSelected;
  final ValueChanged<ShareableUser> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVanished = ref.watch(profileVanishedProvider(user.pubkey));
    // `dmPeerName` rather than the `profile:`-shaped wrapper: a
    // [ShareableUser] already carries the step-4 value (it is built from
    // `UserProfile.bestDisplayName`), and it is NOT a `displayNameOverride` —
    // that step outranks moderation, which would let the moderation account's
    // own kind-0 name win over the shared label.
    final moderation = ref.watch(moderationPresentationProvider(user.pubkey));
    final displayName = dmPeerName(
      pubkeyHex: user.pubkey,
      isVanished: isVanished,
      moderation: moderation,
      labels: dmPeerLabels(context),
      profileName: user.displayName,
    );
    final avatar = dmPeerAvatar(
      isVanished: isVanished,
      moderation: moderation,
      pictureUrl: user.picture,
    );
    final resolved = ShareableUser(
      pubkey: user.pubkey,
      displayName: displayName,
      // A vanished account's NIP-05 identifies it as surely as its name does.
      handle: isVanished ? null : user.handle,
      picture: avatar.imageUrl,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(resolved),
        child: SizedBox(
          width: _ShareWithSection._itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Stack(
                children: [
                  UserAvatar(
                    imageUrl: avatar.imageUrl,
                    name: displayName,
                    size: _ShareWithSection._avatarSize,
                    contentOverride: avatar.contentOverride,
                  ),
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: VineTheme.vineGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const DivineIcon(
                          icon: DivineIconName.check,
                          size: 14,
                          color: VineTheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                displayName,
                style: TextStyle(
                  color: isSelected
                      ? context.vineColors.accentPositive
                      : context.vineColors.secondaryText,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
