// ABOUTME: Followers stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate followers BLoC based on pubkey.
class ProfileFollowersStat extends ConsumerWidget {
  const ProfileFollowersStat({
    required this.pubkey,
    required this.displayName,
    required this.isOwnProfile,
    this.initialCount,
    super.key,
  });

  /// The public key of the profile user whose followers count to display.
  final String pubkey;

  /// The display name of the user for the followers screen title.
  final String? displayName;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Initial count from profile data, shown while the BLoC loads.
  final int? initialCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

    if (isOwnProfile) {
      return BlocProvider(
        key: ValueKey((followRepository, blocklistRepository, pubkey)),
        create: (_) => MyFollowersBloc(
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
        )..add(const MyFollowersListLoadRequested()),
        child: _MyFollowersStatView(
          pubkey: pubkey,
          displayName: displayName,
          initialCount: initialCount,
        ),
      );
    } else {
      // Use the OthersFollowersBloc from parent context (provided by
      // ProfileGridView). This allows the follow button to update the
      // count optimistically.
      return _OthersFollowersStatView(
        pubkey: pubkey,
        displayName: displayName,
        initialCount: initialCount,
      );
    }
  }
}

/// View widget for current user's followers stat.
class _MyFollowersStatView extends ConsumerWidget {
  const _MyFollowersStatView({
    required this.pubkey,
    required this.displayName,
    this.initialCount,
  });

  final String pubkey;
  final String? displayName;
  final int? initialCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowersBloc>().add(const MyFollowersBlocklistChanged());
    });

    return BlocBuilder<MyFollowersBloc, MyFollowersState>(
      builder: (context, state) {
        final isLoading =
            state.status == MyFollowersStatus.initial ||
            state.status == MyFollowersStatus.loading;
        final hasLoadedCount = state.status == MyFollowersStatus.success;

        return ProfileStatColumn(
          count: hasLoadedCount ? state.followerCount : initialCount,
          label: context.l10n.profileFollowersLabel,
          isLoading: (isLoading || !hasLoadedCount) && initialCount == null,
          onTap: () => context.push(
            FollowersScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}

/// View widget for other user's followers stat.
class _OthersFollowersStatView extends ConsumerWidget {
  const _OthersFollowersStatView({
    required this.pubkey,
    required this.displayName,
    this.initialCount,
  });

  final String pubkey;
  final String? displayName;
  final int? initialCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowersBloc>().add(
        const OthersFollowersBlocklistChanged(),
      );
    });

    return BlocBuilder<OthersFollowersBloc, OthersFollowersState>(
      builder: (context, state) {
        final isLoading =
            state.status == OthersFollowersStatus.initial ||
            state.status == OthersFollowersStatus.loading;
        final hasLoadedCount =
            state.status == OthersFollowersStatus.success &&
            state.targetPubkey == pubkey;

        return ProfileStatColumn(
          count: hasLoadedCount ? state.followerCount : initialCount,
          label: context.l10n.profileFollowersLabel,
          isLoading: (isLoading || !hasLoadedCount) && initialCount == null,
          onTap: () => context.push(
            FollowersScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}
