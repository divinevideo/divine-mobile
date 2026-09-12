// ABOUTME: Screen displaying another user's following list
// ABOUTME: Uses OthersFollowingBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/profile/searchable_follow_list.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for displaying another user's following list.
///
/// Creates both [OthersFollowingBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state) and provides them to the view.
class OthersFollowingScreen extends ConsumerWidget {
  const OthersFollowingScreen({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OthersFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            currentUserPubkey: nostrClient.publicKey,
          )..add(OthersFollowingListLoadRequested(pubkey)),
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
            listKind: FollowListKind.following,
            profileRepository: profileRepository,
          ),
        ),
      ],
      child: _OthersFollowingView(pubkey: pubkey, displayName: displayName),
    );
  }
}

class _OthersFollowingView extends ConsumerWidget {
  const _OthersFollowingView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowingBloc>().add(
        const OthersFollowingBlocklistChanged(),
      );
    });
    ref.listen(profileRepositoryProvider, (_, repository) {
      context.read<FollowListSearchBloc>().add(
        FollowListSearchProfileRepositoryChanged(repository),
      );
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? context.l10n.followingTitleForName(displayName!)
        : context.l10n.followingTitle;

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget:
            FollowerCountTitle<OthersFollowingBloc, OthersFollowingState>(
              title: appBarTitle,
              selector: (state) => state.status == OthersFollowingStatus.success
                  ? state.followingPubkeys.length
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
        child: BlocBuilder<OthersFollowingBloc, OthersFollowingState>(
          builder: (context, state) {
            return switch (state.status) {
              OthersFollowingStatus.initial => const Center(
                child: BrandedLoadingIndicator(),
              ),
              OthersFollowingStatus.success => LoadingOverlay(
                isLoading: state.isRefreshing,
                child: _FollowingListBody(
                  following: state.followingPubkeys,
                  targetPubkey: pubkey,
                ),
              ),
              OthersFollowingStatus.failure => _FollowingErrorBody(
                onRetry: () {
                  final targetPubkey = context
                      .read<OthersFollowingBloc>()
                      .state
                      .targetPubkey;
                  if (targetPubkey != null) {
                    context.read<OthersFollowingBloc>().add(
                      OthersFollowingListLoadRequested(targetPubkey),
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

class _FollowingListBody extends StatelessWidget {
  const _FollowingListBody({
    required this.following,
    required this.targetPubkey,
  });

  final List<String> following;
  final String targetPubkey;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return SearchableFollowList(
      pubkeys: following,
      onRefresh: () async {
        context.read<OthersFollowingBloc>().add(
          OthersFollowingListLoadRequested(targetPubkey, forceRefresh: true),
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
              index: index,
              addToListEntryPoint: PeopleListEntryPoint.followingList,
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

class _FollowingEmptyState extends StatelessWidget {
  const _FollowingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.userPlus,
            size: 64,
            color: context.vineColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.followingEmptyTitle,
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

class _FollowingErrorBody extends StatelessWidget {
  const _FollowingErrorBody({required this.onRetry});

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
            context.l10n.followingFailedToLoadList,
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
