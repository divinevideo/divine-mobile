// ABOUTME: Full-screen bottom sheet for searching and selecting a user.
// ABOUTME: Used by the share sheet to find recipients for video sharing via DM.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Full-screen bottom sheet for finding and selecting a user to share with.
///
/// Shows [contacts] (pre-loaded by the calling BLoC) initially, with search
/// functionality to find any Nostr user by name or npub.
/// Returns a [ShareableUser] when a user is selected.
class FindPeopleSheet extends ConsumerStatefulWidget {
  const FindPeopleSheet({
    required this.contacts,
    required this.currentUserPubkey,
    this.scrollController,
    this.searchTimeout = const Duration(seconds: 20),
    super.key,
  });

  /// Pre-loaded contacts from the parent share sheet BLoC.
  final List<ShareableUser> contacts;

  /// The signed-in user, excluded from DM recipient search results.
  final String currentUserPubkey;

  /// Scroll controller handed down by the enclosing [VineBottomSheet] so
  /// flinging the result list drags the sheet itself.
  final ScrollController? scrollController;

  /// Optional timeout forwarded to the internally created [UserSearchBloc].
  final Duration? searchTimeout;

  /// Fraction of the viewport the sheet occupies, matching the Figma spec
  /// (node 13945:91140) — tall enough for the list, short enough to leave
  /// the scrim visible above it.
  static const double _sheetHeightFraction = 0.92;

  @override
  ConsumerState<FindPeopleSheet> createState() => _FindPeopleSheetState();

  /// Show the find people sheet and return the selected user.
  ///
  /// [contacts] are passed from the calling BLoC so this sheet does not
  /// need to load them independently.
  static Future<ShareableUser?> show(
    BuildContext context, {
    required String currentUserPubkey,
    List<ShareableUser> contacts = const [],
  }) {
    return VineBottomSheet.show<ShareableUser>(
      context: context,
      showHeader: false,
      showHeaderDivider: false,
      initialChildSize: _sheetHeightFraction,
      maxChildSize: _sheetHeightFraction,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => FindPeopleSheet(
        contacts: contacts,
        currentUserPubkey: currentUserPubkey,
        scrollController: scrollController,
      ),
    );
  }
}

class _FindPeopleSheetState extends ConsumerState<FindPeopleSheet> {
  final TextEditingController _searchController = TextEditingController();
  UserSearchBloc? _searchBloc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo != null) {
      _searchBloc = UserSearchBloc(
        profileRepository: profileRepo,
        searchTimeout: widget.searchTimeout,
        excludedPubkey: widget.currentUserPubkey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: .search,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.shareFindPeople,
              hintStyle: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
              prefixIconConstraints: const BoxConstraints(),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                child: DivineIcon(
                  icon: DivineIconName.search,
                  color: context.vineColors.secondaryText,
                ),
              ),
              filled: true,
              fillColor: context.vineColors.containerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          // VineBottomSheet paints its surface with a ColoredBox, which would
          // hide the tiles' ink splashes without an own Material in between.
          child: Material(
            type: MaterialType.transparency,
            child: _ResultsList(
              searchQuery: _searchQuery,
              searchBloc: _searchBloc,
              contacts: widget.contacts,
              scrollController: widget.scrollController,
              onSelectUser: _selectUser,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _searchBloc?.add(const UserSearchCleared());
    } else {
      _searchBloc?.add(UserSearchQueryChanged(value));
    }
    setState(() => _searchQuery = trimmed);
  }

  void _selectUser(ShareableUser user) {
    Navigator.of(context).pop(user);
  }

  @override
  void dispose() {
    _searchBloc?.close();
    _searchController.dispose();
    super.dispose();
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.searchQuery,
    required this.searchBloc,
    required this.contacts,
    required this.scrollController,
    required this.onSelectUser,
  });

  final String searchQuery;
  final UserSearchBloc? searchBloc;
  final List<ShareableUser> contacts;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty && searchBloc != null) {
      return BlocBuilder<UserSearchBloc, UserSearchState>(
        bloc: searchBloc,
        builder: (context, state) {
          return switch (state.status) {
            UserSearchStatus.loading when state.results.isNotEmpty =>
              _SearchResultsList(
                results: state.results,
                scrollController: scrollController,
                onSelectUser: onSelectUser,
              ),
            UserSearchStatus.loading => Center(
              child: DivineCircularProgressIndicator(
                color: context.vineColors.accentPositive,
              ),
            ),
            UserSearchStatus.success when state.results.isNotEmpty =>
              _SearchResultsList(
                results: state.results,
                scrollController: scrollController,
                onSelectUser: onSelectUser,
              ),
            UserSearchStatus.success => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.userSearchNoResults,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
            ),
            UserSearchStatus.failure => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.userPickerSearchFailedTryAgain,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
            ),
            UserSearchStatus.initial => _ContactsList(
              contacts: contacts,
              scrollController: scrollController,
              onSelectUser: onSelectUser,
            ),
          };
        },
      );
    }

    return _ContactsList(
      contacts: contacts,
      scrollController: scrollController,
      onSelectUser: onSelectUser,
    );
  }
}

/// The list of profiles matching the current search query.
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.scrollController,
    required this.onSelectUser,
  });

  final List<UserProfile> results;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: 16 + bottomSafeArea),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = ShareableUser.fromProfile(
          results[index].pubkey,
          results[index],
        );
        return _UserResultTile(user: user, onTap: onSelectUser);
      },
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.contacts,
    required this.scrollController,
    required this.onSelectUser,
  });

  final List<ShareableUser> contacts;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.findPeopleNoContacts,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: 16 + bottomSafeArea),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _UserResultTile(user: contact, onTap: onSelectUser);
      },
    );
  }
}

/// One search result, as a DM send target.
///
/// Find People routes straight into `DmRepository.sendMessage`, so it names
/// its peer through the same chain the inbox rows use. Its search reaches
/// third-party NIP-50 relays, which a NIP-62 vanish addressed elsewhere never
/// obliged to forget — so a deleted account's kind 0 can and does come back
/// here under its real name (#8421).
class _UserResultTile extends ConsumerWidget {
  const _UserResultTile({required this.user, required this.onTap});

  final ShareableUser user;
  final ValueChanged<ShareableUser> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVanished = ref.watch(profileVanishedProvider(user.pubkey));
    // `dmPeerName` rather than the `profile:`-shaped wrapper: a
    // [ShareableUser] already carries the step-4 value (it is built from
    // `UserProfile.bestDisplayName`), and it is NOT a `displayNameOverride` —
    // that step outranks moderation, which would let the moderation account's
    // own kind-0 name win over the shared label.
    final displayName = dmPeerName(
      pubkeyHex: user.pubkey,
      isVanished: isVanished,
      isModeration: isModerationAccount(user.pubkey),
      labels: dmPeerLabels(context),
      profileName: user.displayName,
    );
    final avatar = dmPeerAvatar(
      pubkeyHex: user.pubkey,
      isVanished: isVanished,
      pictureUrl: user.picture,
    );
    // A vanished account's NIP-05 identifies it as surely as its name does.
    final handle = isVanished ? null : user.handle;
    // Hand the resolved identity on, so the share sheet's selection chip and
    // its success snackbar name the peer the way this row did.
    final resolved = ShareableUser(
      pubkey: user.pubkey,
      displayName: displayName,
      handle: handle,
      picture: avatar.imageUrl,
    );

    return ListTile(
      leading: UserAvatar(
        imageUrl: avatar.imageUrl,
        name: displayName,
        placeholderSeed: user.pubkey,
        size: 48,
        contentOverride: avatar.contentOverride,
      ),
      title: Text(
        displayName,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      // No npub fallback: a row without a nip05 or a name shows the name
      // line only, matching the Figma spec and the new-message sheet.
      subtitle: handle == null
          ? null
          : Text(
              handle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => onTap(resolved),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
