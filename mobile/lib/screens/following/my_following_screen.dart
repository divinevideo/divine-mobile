// ABOUTME: Screen displaying current user's following list
// ABOUTME: Uses MyFollowingBloc for reactive updates via repository

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
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

/// Page widget for displaying current user's following list.
///
/// Creates [MyFollowingBloc] and provides it to the view.
class MyFollowingScreen extends ConsumerWidget {
  const MyFollowingScreen({required this.displayName, super.key});

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
            subjectPubkey: currentUserPubkey,
            listKind: FollowListKind.following,
            profileRepository: profileRepository,
          ),
        ),
      ],
      child: _MyFollowingView(displayName: displayName),
    );
  }
}

class _MyFollowingView extends ConsumerWidget {
  const _MyFollowingView({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowingBloc>().add(const MyFollowingBlocklistChanged());
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
        ? context.l10n.followingTitleForName(displayName!)
        : context.l10n.followingTitle;

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        titleWidget: FollowerCountTitle<MyFollowingBloc, MyFollowingState>(
          title: appBarTitle,
          selector: (state) => state.status == MyFollowingStatus.success
              ? state.followingPubkeys.length
              : 0,
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.funnelSimple.assetPath),
            semanticLabel: context.l10n.followingSortSemanticLabel,
            tooltip: context.l10n.followingSortSemanticLabel,
            onPressed: () => _openSortMenu(context),
          ),
        ],
      ),
      body: BlocConsumer<MyFollowingBloc, MyFollowingState>(
        listenWhen: (previous, current) =>
            (current.status == MyFollowingStatus.success &&
                previous.status != MyFollowingStatus.success) ||
            (current.status == MyFollowingStatus.toggleFailure &&
                previous.status != MyFollowingStatus.toggleFailure),
        listener: (context, state) {
          if (state.status == MyFollowingStatus.success) {
            ref
                .read(screenAnalyticsServiceProvider)
                .markDataLoaded(
                  'following',
                  dataMetrics: {
                    'following_count': state.followingPubkeys.length,
                  },
                );
          }
          if (state.status == MyFollowingStatus.toggleFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.followersUpdateFollowFailed),
              ),
            );
          }
        },
        builder: (context, state) {
          final body = switch (state.status) {
            MyFollowingStatus.initial => const Center(
              child: BrandedLoadingIndicator(),
            ),
            MyFollowingStatus.toggleFailure ||
            MyFollowingStatus.success => _FollowingListBody(
              following: state.followingPubkeys,
            ),
            MyFollowingStatus.failure => _FollowingErrorBody(
              onRetry: () {
                context.read<MyFollowingBloc>().add(
                  const MyFollowingListLoadRequested(),
                );
              },
            ),
          };
          return LoadingOverlay(isLoading: state.isRefreshing, child: body);
        },
      ),
    );
  }

  Future<void> _openSortMenu(BuildContext context) async {
    final bloc = context.read<MyFollowingBloc>();
    final selected = await showFollowSortMenu(
      context: context,
      current: bloc.state.sortOrder,
    );

    if (selected == null) return;
    bloc.add(MyFollowingSortOrderChanged(selected));
  }
}

class _FollowingListBody extends StatelessWidget {
  const _FollowingListBody({required this.following});

  final List<String> following;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return SearchableFollowList(
      pubkeys: following,
      onRefresh: () async {
        context.read<MyFollowingBloc>().add(
          const MyFollowingListLoadRequested(),
        );
      },
      itemBuilder: (context, userPubkey, index) {
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
