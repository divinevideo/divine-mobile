// ABOUTME: Bottom sheet for composing a new direct message.
// ABOUTME: Shows a searchable user list for picking one DM recipient, or
// ABOUTME: several for a group. Uses NewMessageSearchBloc for its state.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/bloc/bloc.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';

/// Widest a picked person's name runs on their chip before it is ellipsized,
/// so one long name cannot push every other chip out of the strip.
const double _chipNameMaxWidth = 120;

/// Corner radius of a chip's pill.
const double _chipRadius = 16;

/// A bottom sheet for selecting who to start a new DM conversation with.
///
/// Shows the user's followed contacts initially. Typing in the search
/// field queries for users by name or npub. Tapping a user returns them and
/// dismisses the sheet. With [allowGroups], a "New group" row switches the
/// sheet to picking several people, which "Start chat" returns together.
class NewMessageSheet extends ConsumerWidget {
  const NewMessageSheet({
    required this.profileRepository,
    required this.followRepository,
    required this.currentUserPubkey,
    required this.allowGroups,
    super.key,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;

  /// The signed-in user, excluded from the candidate list — Divine does not
  /// support a self-addressed conversation (#8351).
  final String currentUserPubkey;

  /// Whether the sheet offers the "New group" row, and with it the mode that
  /// picks several people. Without it the first tap picks one person.
  final bool allowGroups;

  /// Shows the sheet and returns who the new conversation is with: one
  /// profile for a one-to-one, two or more for a group, in the order they
  /// were picked. Null if the user dismissed without choosing.
  static Future<List<UserProfile>?> show(
    BuildContext context, {
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
    required String currentUserPubkey,
    required bool allowGroups,
  }) {
    return showModalBottomSheet<List<UserProfile>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewMessageSheet(
        profileRepository: profileRepository,
        followRepository: followRepository,
        currentUserPubkey: currentUserPubkey,
        allowGroups: allowGroups,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => NewMessageSearchBloc(
        profileRepository: profileRepository,
        followRepository: followRepository,
        currentUserPubkey: currentUserPubkey,
        moderationPresentation: ref.read(
          moderationPresentationResolverProvider,
        ),
      )..add(const NewMessageSearchStarted()),
      child: _PeerLabelSync(
        child: _NewMessageSheetView(allowGroups: allowGroups),
      ),
    );
  }
}

/// Feeds the sheet's [DmPeerLabels] down to the BLoC that matches on them.
///
/// The sort and the search filter resolve peer names through [dmPeerName],
/// which needs already-translated substitutes; only a widget can read them.
/// Mirrors the inbox's own `_PeerLabelSync`.
class _PeerLabelSync extends StatefulWidget {
  const _PeerLabelSync({required this.child});

  final Widget child;

  @override
  State<_PeerLabelSync> createState() => _PeerLabelSyncState();
}

class _PeerLabelSyncState extends State<_PeerLabelSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<NewMessageSearchBloc>().add(
      NewMessageSearchPeerLabelsChanged(dmPeerLabels(context)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NewMessageSheetView extends StatefulWidget {
  const _NewMessageSheetView({required this.allowGroups});

  final bool allowGroups;

  @override
  State<_NewMessageSheetView> createState() => _NewMessageSheetViewState();
}

class _NewMessageSheetViewState extends State<_NewMessageSheetView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      context.read<NewMessageSearchBloc>().add(const NewMessageSearchCleared());
    } else {
      context.read<NewMessageSearchBloc>().add(
        NewMessageSearchQueryChanged(trimmed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isGroupMode = context.select(
      (NewMessageSearchBloc bloc) => bloc.state.isGroupMode,
    );

    return Material(
      color: context.vineColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: SizedBox(
        height: screenHeight * 0.92,
        child: Column(
          children: [
            const _SheetHeader(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
            ),
            if (!isGroupMode && widget.allowGroups) const _NewGroupRow(),
            // Keyed because its neighbours come and go with the mode. Without
            // the key the list is rebuilt on every switch and loses its
            // scroll position.
            const Expanded(
              key: ValueKey('new-message-people'),
              child: _People(),
            ),
            if (isGroupMode) const _StartGroupFooter(),
          ],
        ),
      ),
    );
  }
}

/// The picked people, once there are any, over the list to pick from.
///
/// The picks stay in view while the list scrolls. They get at most half of
/// the room: with the keyboard up, a small screen and large text they scroll
/// in place rather than push the list, or the button below it, off the sheet.
class _People extends StatelessWidget {
  const _People();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
            child: const SingleChildScrollView(child: _SelectedRecipients()),
          ),
          const Expanded(child: _ResultsBody()),
        ],
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<NewMessageSearchBloc, NewMessageSearchState>(
      // A pick changes neither the people listed nor the status. Each row
      // watches its own selection, so the list itself need not rebuild.
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.contacts != current.contacts ||
          previous.results != current.results,
      builder: (context, state) {
        return switch (state.status) {
          NewMessageSearchStatus.loadingContacts => Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          ),
          NewMessageSearchStatus.idle => _UserProfileList(
            profiles: state.contacts,
            emptyMessage: l10n.newMessageNoContacts,
          ),
          NewMessageSearchStatus.searching when state.results.isEmpty => Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          ),
          NewMessageSearchStatus.searching => _UserProfileList(
            profiles: state.results,
          ),
          NewMessageSearchStatus.searchSuccess when state.results.isNotEmpty =>
            _UserProfileList(profiles: state.results),
          NewMessageSearchStatus.searchSuccess => _UserProfileList(
            profiles: const [],
            emptyMessage: l10n.newMessageNoUsersFound,
          ),
          NewMessageSearchStatus.searchFailure when state.results.isNotEmpty =>
            _UserProfileList(profiles: state.results),
          NewMessageSearchStatus.searchFailure => _UserProfileList(
            profiles: const [],
            emptyMessage: l10n.userPickerSearchFailedTryAgain,
          ),
        };
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    final isGroupMode = context.select(
      (NewMessageSearchBloc bloc) => bloc.state.isGroupMode,
    );

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 4,
          decoration: BoxDecoration(
            color: context.vineColors.disabled,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        if (isGroupMode)
          const _GroupTitleRow()
        else ...[
          const SizedBox(height: 20),
          Text(
            context.l10n.newMessageTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Divider(
          height: 1,
          thickness: 1,
          color: context.vineColors.outlineMuted,
        ),
      ],
    );
  }
}

/// The header's title line in group mode: the way back out of the mode, and
/// the title centred on the full width beside it.
class _GroupTitleRow extends StatelessWidget {
  const _GroupTitleRow();

  @override
  Widget build(BuildContext context) {
    final backLabel = context.l10n.commonBack;
    // Kept clear on both sides, so the title stays centred: the back control,
    // which grows with the text scale, plus a gap.
    final titleInset =
        DivineIcon.scaleSize(context, kMinInteractiveDimension) + 8;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DivineIconButton(
              icon: DivineIconName.caretLeft,
              type: DivineIconButtonType.secondary,
              size: DivineIconButtonSize.small,
              tooltip: backLabel,
              semanticLabel: backLabel,
              onPressed: () => context.read<NewMessageSearchBloc>().add(
                const NewMessageSearchGroupModeChanged(enabled: false),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: titleInset),
            child: Text(
              context.l10n.newMessageNewGroup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.search,
            color: context.vineColors.onSurfaceMuted,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.primaryText,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.newMessageFindPeople,
                hintStyle: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Switches the picker to picking several people. Shaped like the rows below
/// it, so its icon lines up with their avatars.
class _NewGroupRow extends StatelessWidget {
  const _NewGroupRow();

  static const double _iconTileSize = 40;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          identifier: SemanticIds.newMessageNewGroupRow,
          button: true,
          child: InkWell(
            onTap: () => context.read<NewMessageSearchBloc>().add(
              const NewMessageSearchGroupModeChanged(enabled: true),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                spacing: 16,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: _iconTileSize,
                      height: _iconTileSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.vineColors.iconButton,
                        borderRadius: BorderRadius.circular(
                          UserAvatar.cornerRadiusForSize(_iconTileSize),
                        ),
                      ),
                      child: DivineIcon(
                        icon: DivineIconName.users,
                        color: context.vineColors.onIconButton,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.newMessageNewGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.vineColors.outlineMuted,
          indent: 72,
        ),
      ],
    );
  }
}

/// Who is in the group so far, and the notice that it is full once it is.
class _SelectedRecipients extends StatelessWidget {
  const _SelectedRecipients();

  static const _revealDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final (recipients, isGroupFull) = context.select(
      (NewMessageSearchBloc bloc) => (
        bloc.state.selectedRecipients,
        bloc.state.isGroupFull,
      ),
    );

    // The first pick opens this strip and moves the list down. Easing it in,
    // as the collaborator picker does, keeps the rows from jumping under the
    // finger.
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _revealDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: recipients.isEmpty
          // Full width already, so only the height animates.
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                // Stretched so the chips start at the leading edge. Left to
                // shrink-wrap, the strip is centred and shifts on every pick.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      spacing: 8,
                      children: [
                        for (final (index, recipient) in recipients.indexed)
                          _RecipientChip(
                            key: ValueKey(recipient.pubkey),
                            index: index,
                            profile: recipient,
                          ),
                      ],
                    ),
                  ),
                  if (isGroupFull) const _GroupFullNotice(),
                ],
              ),
            ),
    );
  }
}

/// One picked recipient.
///
/// The whole chip is the remove target, so nobody has to hit the small mark
/// at its end. It names its peer through the same chain the rows use, or a
/// vanished account would be "Deleted account" in the list and themselves on
/// the chip (#8421).
class _RecipientChip extends ConsumerWidget {
  const _RecipientChip({
    required this.index,
    required this.profile,
    super.key,
  });

  /// Position in the order people were picked.
  final int index;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVanished = ref.watch(profileVanishedProvider(profile.pubkey));
    final moderation = ref.watch(
      moderationPresentationProvider(profile.pubkey),
    );
    final displayName = dmPeerDisplayName(
      context,
      pubkeyHex: profile.pubkey,
      isVanished: isVanished,
      moderation: moderation,
      profile: profile,
    );
    final avatar = dmPeerAvatar(
      isVanished: isVanished,
      moderation: moderation,
      pictureUrl: profile.picture,
    );

    return Semantics(
      identifier: SemanticIds.newMessageRecipientChip(index),
      button: true,
      label: context.l10n.userPickerRemoveSelectionSemantics(displayName),
      child: GestureDetector(
        // Opaque so the margin that brings the pill up to a full-size tap
        // target is part of the target, not just of the layout.
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<NewMessageSearchBloc>().add(
          NewMessageSearchRecipientToggled(profile),
        ),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(_chipRadius),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      UserAvatar(
                        imageUrl: avatar.imageUrl,
                        name: displayName,
                        placeholderSeed: profile.pubkey,
                        size: 24,
                        contentOverride: avatar.contentOverride,
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _chipNameMaxWidth,
                        ),
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.titleSmallFont(
                            color: context.vineColors.onSurface,
                          ),
                        ),
                      ),
                      DivineIcon(
                        icon: DivineIconName.x,
                        size: 16,
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says why nobody else can be picked. A live region, so a screen reader
/// hears it the moment the last pick fills the group.
class _GroupFullNotice extends StatelessWidget {
  const _GroupFullNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        liveRegion: true,
        child: Text(
          context.l10n.newMessageGroupFull(dmGroupMaxParticipants),
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The button that starts the group, held above the keyboard the search
/// field keeps open.
class _StartGroupFooter extends StatelessWidget {
  const _StartGroupFooter();

  @override
  Widget build(BuildContext context) {
    final canStartGroup = context.select(
      (NewMessageSearchBloc bloc) => bloc.state.canStartGroup,
    );
    final label = context.l10n.newMessageStartChat;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: context.vineColors.outlineMuted,
        ),
        VineKeyboardAwareFooter(
          includeSafeArea: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: DivineButton(
              label: label,
              // Repeats the label on purpose: with it the button announces
              // itself as a disabled button, not as a line of plain text.
              semanticLabel: label,
              semanticIdentifier: SemanticIds.newMessageStartGroupButton,
              expanded: true,
              onPressed: canStartGroup
                  ? () => Navigator.of(context).pop(
                      List<UserProfile>.of(
                        context
                            .read<NewMessageSearchBloc>()
                            .state
                            .selectedRecipients,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserProfileList extends StatelessWidget {
  const _UserProfileList({required this.profiles, this.emptyMessage});

  final List<UserProfile> profiles;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty && emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage!,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // In group mode a drag on the list puts the keyboard away: the picks and
    // the start button leave the rows little room. Done by hand, in both
    // modes, because `keyboardDismissBehavior` adds its listener only when it
    // is on, which rebuilds the list and loses its place on a mode switch.
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        final isGroupMode = context
            .read<NewMessageSearchBloc>()
            .state
            .isGroupMode;
        final scope = FocusScope.of(context);
        // The same test the framework's own drag-to-dismiss makes: only when
        // a field inside this scope holds the focus.
        if (isGroupMode &&
            notification.dragDetails != null &&
            !scope.hasPrimaryFocus &&
            scope.hasFocus) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: profiles.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 1,
          color: context.vineColors.outlineMuted,
          indent: 72,
        ),
        itemBuilder: (context, index) =>
            _CandidateRow(profile: profiles[index]),
      ),
    );
  }
}

/// One row of the people list, wired to what a tap means in the current
/// mode: pick this person and close, or add them to and drop them from the
/// group.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final (isGroupMode, isSelected, isGroupFull) = context.select(
      (NewMessageSearchBloc bloc) => (
        bloc.state.isGroupMode,
        bloc.state.isSelected(profile.pubkey),
        bloc.state.isGroupFull,
      ),
    );

    if (!isGroupMode) {
      return _UserTile(
        profile: profile,
        onTap: () => Navigator.of(context).pop(<UserProfile>[profile]),
      );
    }

    return _UserTile(
      profile: profile,
      isSelected: isSelected,
      // A full group takes nobody new, but whoever is in it can still leave.
      onTap: isGroupFull && !isSelected
          ? null
          : () => context.read<NewMessageSearchBloc>().add(
              NewMessageSearchRecipientToggled(profile),
            ),
    );
  }
}

/// One candidate recipient row.
///
/// A send-target picker names its peer through the same chain the inbox rows
/// use, or the two disagree about who an account is: this row said
/// "Aeontropy" over their photo while the thread with the same pubkey said
/// "Deleted account", and gave Divine's own moderation account a generic
/// placeholder avatar (#8421).
class _UserTile extends ConsumerWidget {
  const _UserTile({
    required this.profile,
    required this.onTap,
    this.isSelected,
  });

  final UserProfile profile;

  /// What a tap does. Null makes the row inert and dims it.
  final VoidCallback? onTap;

  /// Whether this person is picked for the group. Null outside group mode,
  /// where a row has no selection to show.
  final bool? isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVanished = ref.watch(profileVanishedProvider(profile.pubkey));
    final moderation = ref.watch(
      moderationPresentationProvider(profile.pubkey),
    );
    final displayName = dmPeerDisplayName(
      context,
      pubkeyHex: profile.pubkey,
      isVanished: isVanished,
      moderation: moderation,
      profile: profile,
    );
    final avatar = dmPeerAvatar(
      isVanished: isVanished,
      moderation: moderation,
      pictureUrl: profile.picture,
    );
    final handle =
        dmPeerHandle(
          isVanished: isVanished,
          moderation: moderation,
          handle: profile.handle,
        ) ??
        '';
    final isSelected = this.isSelected;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        spacing: 16,
        children: [
          // The name beside it already says who this is.
          ExcludeSemantics(
            child: UserAvatar(
              imageUrl: avatar.imageUrl,
              name: displayName,
              placeholderSeed: profile.pubkey,
              size: 40,
              contentOverride: avatar.contentOverride,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                if (handle.isNotEmpty)
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected != null)
            // The row itself reports `selected`; this is the mark for the eye.
            ExcludeSemantics(
              child: DivineSpriteCheckbox(
                state: isSelected
                    ? DivineCheckboxState.selected
                    : DivineCheckboxState.unselected,
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        // Dimmed only inside group mode, the one place a row can be inert.
        child: isSelected == null
            ? content
            : Opacity(
                opacity: onTap == null ? DivineCheckboxTile.disabledOpacity : 1,
                child: content,
              ),
      ),
    );
  }
}
