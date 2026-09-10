// ABOUTME: Screen displaying another user's followers list
// ABOUTME: Uses OthersFollowersBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/profile/searchable_follow_list.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for displaying another user's followers list.
///
/// Creates both [OthersFollowersBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state) and provides them to the view.
class OthersFollowersScreen extends ConsumerWidget {
  const OthersFollowersScreen({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OthersFollowersBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            currentUserPubkey: nostrClient.publicKey,
          )..add(OthersFollowersListLoadRequested(pubkey)),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowingListLoadRequested()),
        ),
        // Deliberately not keyed on profileRepository: it resolves from null
        // shortly after mount, and a ValueKey here would re-inflate the whole
        // view. The late instance is pushed in by the ref.listen below.
        BlocProvider(
          create: (_) => FollowListSearchBloc(
            followRepository: followRepository,
            subjectPubkey: pubkey,
            listKind: FollowListKind.followers,
            profileRepository: profileRepository,
          ),
        ),
      ],
      child: _OthersFollowersView(pubkey: pubkey, displayName: displayName),
    );
  }
}

class _OthersFollowersView extends ConsumerWidget {
  const _OthersFollowersView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowersBloc>().add(
        const OthersFollowersBlocklistChanged(),
      );
    });
    ref.listen(profileRepositoryProvider, (_, repository) {
      context.read<FollowListSearchBloc>().add(
        FollowListSearchProfileRepositoryChanged(repository),
      );
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? context.l10n.followersTitleForName(displayName!)
        : context.l10n.followersTitle;

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget:
            FollowerCountTitle<OthersFollowersBloc, OthersFollowersState>(
              title: appBarTitle,
              selector: (state) => state.status == OthersFollowersStatus.success
                  ? state.followerCount
                  : 0,
            ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyFollowingBloc, MyFollowingState>(
            listenWhen: (previous, current) =>
                current.status == MyFollowingStatus.toggleFailure &&
                previous.status != MyFollowingStatus.toggleFailure,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.followersUpdateFollowFailed),
                ),
              );
            },
          ),
        ],
        child: BlocBuilder<OthersFollowersBloc, OthersFollowersState>(
          builder: (context, state) {
            final showFollowersList = state.followersPubkeys.isNotEmpty;

            return switch (state.status) {
              OthersFollowersStatus.initial => const Center(
                child: BrandedLoadingIndicator(),
              ),
              OthersFollowersStatus.loading when showFollowersList =>
                LoadingOverlay(
                  isLoading: state.isRefreshing,
                  child: _FollowersListBody(
                    followers: state.followersPubkeys,
                    targetPubkey: pubkey,
                  ),
                ),
              OthersFollowersStatus.loading => const Center(
                child: BrandedLoadingIndicator(),
              ),
              OthersFollowersStatus.success => LoadingOverlay(
                isLoading: state.isRefreshing,
                child: _FollowersListBody(
                  followers: state.followersPubkeys,
                  targetPubkey: pubkey,
                ),
              ),
              OthersFollowersStatus.failure => _FollowersErrorBody(
                onRetry: () {
                  final targetPubkey = context
                      .read<OthersFollowersBloc>()
                      .state
                      .targetPubkey;
                  if (targetPubkey != null) {
                    context.read<OthersFollowersBloc>().add(
                      OthersFollowersListLoadRequested(targetPubkey),
                    );
                  }
                },
              ),
            };
          },
        ),
      ),
    );
  }
}

class _FollowersListBody extends StatelessWidget {
  const _FollowersListBody({
    required this.followers,
    required this.targetPubkey,
  });

  final List<String> followers;
  final String targetPubkey;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return const _FollowersEmptyState();
    }

    return SearchableFollowList(
      pubkeys: followers,
      onRefresh: () async {
        context.read<OthersFollowersBloc>().add(
          OthersFollowersListLoadRequested(targetPubkey, forceRefresh: true),
        );
      },
      itemBuilder: (context, userPubkey, index) {
        // Use MyFollowingBloc to check if current user follows this person
        return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
          selector: (state) => state.isFollowing(userPubkey),
          builder: (context, isFollowing) {
            return UserProfileTile(
              pubkey: userPubkey,
              onTap: () => context.pushOtherProfile(userPubkey),
              isFollowing: isFollowing,
              onToggleFollow: () {
                context.read<MyFollowingBloc>().add(
                  MyFollowingToggleRequested(userPubkey),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FollowersEmptyState extends StatelessWidget {
  const _FollowersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.users,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.followersEmptyTitle,
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowersErrorBody extends StatelessWidget {
  const _FollowersErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.followersFailedToLoadList,
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}
