// ABOUTME: Screen displaying current user's followers list
// ABOUTME: Uses MyFollowersBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/follow_sort_menu.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/profile/searchable_follow_list.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for displaying current user's followers list.
///
/// Creates both [MyFollowersBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state - to show "follow back") and provides them.
class MyFollowersScreen extends ConsumerWidget {
  const MyFollowersScreen({required this.displayName, super.key});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    final currentUserPubkey = ref.watch(nostrServiceProvider).publicKey;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MyFollowersBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowersListLoadRequested()),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowingListLoadRequested()),
        ),
        // Deliberately unkeyed: profileRepositoryProvider resolves from null
        // shortly after mount, and a ValueKey here would re-inflate the whole
        // view. The late instance is pushed in by the ref.listen below.
        BlocProvider(
          create: (_) => FollowListSearchBloc(
            followRepository: followRepository,
            subjectPubkey: currentUserPubkey,
            listKind: FollowListKind.followers,
            profileRepository: profileRepository,
          ),
        ),
      ],
      child: _MyFollowersView(displayName: displayName),
    );
  }
}

class _MyFollowersView extends ConsumerWidget {
  const _MyFollowersView({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowersBloc>().add(const MyFollowersBlocklistChanged());
    });
    ref.listen(profileRepositoryProvider, (_, repository) {
      context.read<FollowListSearchBloc>().add(
        FollowListSearchProfileRepositoryChanged(repository),
      );
    });
    // The client is rebuilt when the key container changes, which is how the
    // cold-start empty pubkey becomes the signed-in one. Without this the
    // search BLoC would keep the empty one and never search server-side.
    ref.listen(nostrServiceProvider, (_, client) {
      context.read<FollowListSearchBloc>().add(
        FollowListSearchSubjectPubkeyChanged(client.publicKey),
      );
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? context.l10n.followersTitleForName(displayName!)
        : context.l10n.followersTitle;

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget: FollowerCountTitle<MyFollowersBloc, MyFollowersState>(
          title: appBarTitle,
          selector: (state) => state.status == MyFollowersStatus.success
              ? state.followerCount
              : 0,
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.funnelSimple.assetPath),
            semanticLabel: context.l10n.followersSortSemanticLabel,
            tooltip: context.l10n.followersSortSemanticLabel,
            onPressed: () => _openSortMenu(context),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyFollowersBloc, MyFollowersState>(
            listener: (context, state) {
              if (state.status == MyFollowersStatus.success) {
                ref
                    .read(screenAnalyticsServiceProvider)
                    .markDataLoaded(
                      'followers',
                      dataMetrics: {
                        'followers_count': state.followersPubkeys.length,
                      },
                    );
              }
            },
          ),
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
        child: BlocBuilder<MyFollowersBloc, MyFollowersState>(
          builder: (context, state) {
            return switch (state.status) {
              MyFollowersStatus.initial || MyFollowersStatus.loading =>
                const Center(child: BrandedLoadingIndicator()),
              MyFollowersStatus.success => LoadingOverlay(
                isLoading: state.isRefreshing,
                child: _FollowersListBody(
                  followers: state.followersPubkeys,
                ),
              ),
              MyFollowersStatus.failure => _FollowersErrorBody(
                onRetry: () {
                  context.read<MyFollowersBloc>().add(
                    const MyFollowersListLoadRequested(),
                  );
                },
              ),
            };
          },
        ),
      ),
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final bloc = context.read<MyFollowersBloc>();
    final selected = await showFollowSortMenu(
      context: context,
      current: bloc.state.sortOrder,
    );

    if (selected == null) return;
    bloc.add(MyFollowersSortOrderChanged(selected));
  }
}

class _FollowersListBody extends StatelessWidget {
  const _FollowersListBody({required this.followers});

  final List<String> followers;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return const _FollowersEmptyState();
    }

    return SearchableFollowList(
      pubkeys: followers,
      onRefresh: () async {
        context.read<MyFollowersBloc>().add(
          const MyFollowersListLoadRequested(),
        );
      },
      itemBuilder: (context, userPubkey, index) {
        // Use MyFollowingBloc to check if current user follows this follower
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
