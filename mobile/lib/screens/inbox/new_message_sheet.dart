// ABOUTME: Bottom sheet for composing a new direct message.
// ABOUTME: Shows searchable user list for selecting a DM recipient.
// ABOUTME: Uses NewMessageSearchBloc for contact loading and search.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/bloc/bloc.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';

/// A bottom sheet for selecting a recipient to start a new DM conversation.
///
/// Shows the user's followed contacts initially. Typing in the search
/// field queries for users by name or npub. Selecting a user returns
/// their [UserProfile] and dismisses the sheet.
class NewMessageSheet extends StatelessWidget {
  const NewMessageSheet({
    required this.profileRepository,
    required this.followRepository,
    required this.currentUserPubkey,
    super.key,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;

  /// The signed-in user, excluded from the candidate list — Divine does not
  /// support a self-addressed conversation (#8351).
  final String currentUserPubkey;

  /// Shows the sheet and returns the selected [UserProfile], or null if
  /// the user dismissed without selecting.
  static Future<UserProfile?> show(
    BuildContext context, {
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
    required String currentUserPubkey,
  }) {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewMessageSheet(
        profileRepository: profileRepository,
        followRepository: followRepository,
        currentUserPubkey: currentUserPubkey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewMessageSearchBloc(
        profileRepository: profileRepository,
        followRepository: followRepository,
        currentUserPubkey: currentUserPubkey,
      )..add(const NewMessageSearchStarted()),
      child: const _PeerLabelSync(child: _NewMessageSheetView()),
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
  const _NewMessageSheetView();

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
            const Expanded(child: _ResultsBody()),
          ],
        ),
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
        const SizedBox(height: 20),
        Text(
          context.l10n.newMessageTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 1,
          color: context.vineColors.outlineMuted,
        ),
      ],
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

    return ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 1,
        color: context.vineColors.outlineMuted,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _UserTile(
          profile: profile,
          onTap: () => Navigator.of(context).pop(profile),
        );
      },
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
  const _UserTile({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVanished = ref.watch(profileVanishedProvider(profile.pubkey));
    final displayName = dmPeerDisplayName(
      context,
      pubkeyHex: profile.pubkey,
      isVanished: isVanished,
      profile: profile,
    );
    final avatar = dmPeerAvatar(
      pubkeyHex: profile.pubkey,
      isVanished: isVanished,
      pictureUrl: profile.picture,
    );
    // A vanished account's NIP-05 identifies it as surely as its name does.
    final handle = isVanished ? '' : profile.handle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: avatar.imageUrl,
              name: displayName,
              placeholderSeed: profile.pubkey,
              size: 40,
              contentOverride: avatar.contentOverride,
            ),
            const SizedBox(width: 16),
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
          ],
        ),
      ),
    );
  }
}
