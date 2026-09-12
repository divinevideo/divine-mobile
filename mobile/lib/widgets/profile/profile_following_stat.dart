// ABOUTME: Following stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate following BLoC based on pubkey.
class ProfileFollowingStat extends ConsumerWidget {
  const ProfileFollowingStat({
    required this.pubkey,
    required this.displayName,
    required this.isOwnProfile,
    this.initialCount,
    super.key,
  });

  /// The public key of the profile user whose following count to display.
  final String pubkey;

  /// The display name of the user for the following screen title.
  final String? displayName;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Initial count from profile data, shown while the BLoC loads.
  final int? initialCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

    if (isOwnProfile) {
      return BlocProvider(
        key: ValueKey((followRepository, blocklistRepository, pubkey)),
        create: (_) => MyFollowingBloc(
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
        )..add(const MyFollowingListLoadRequested()),
        child: _MyFollowingStatView(
          pubkey: pubkey,
          displayName: displayName,
          initialCount: initialCount,
        ),
      );
    } else {
      return BlocProvider(
        key: ValueKey(
          (
            followRepository,
            blocklistRepository,
            nostrClient.publicKey,
            pubkey,
          ),
        ),
        create: (_) => OthersFollowingBloc(
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
          currentUserPubkey: nostrClient.publicKey,
        )..add(OthersFollowingListLoadRequested(pubkey)),
        child: _OthersFollowingStatView(
          pubkey: pubkey,
          displayName: displayName,
          initialCount: initialCount,
        ),
      );
    }
  }
}

/// View widget for current user's following stat.
class _MyFollowingStatView extends ConsumerWidget {
  const _MyFollowingStatView({
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
      context.read<MyFollowingBloc>().add(const MyFollowingBlocklistChanged());
    });

    return BlocBuilder<MyFollowingBloc, MyFollowingState>(
      builder: (context, state) {
        // MyFollowingBloc starts with success status (cached data)
        final isLoading = state.status == MyFollowingStatus.initial;
        final hasLoadedCount =
            state.status == MyFollowingStatus.success ||
            state.status == MyFollowingStatus.toggleFailure;

        return ProfileStatColumn(
          count: hasLoadedCount ? state.followingPubkeys.length : initialCount,
          label: context.l10n.profileFollowingStatLabel,
          isLoading: (isLoading || !hasLoadedCount) && initialCount == null,
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}

/// View widget for other user's following stat.
class _OthersFollowingStatView extends ConsumerWidget {
  const _OthersFollowingStatView({
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
      context.read<OthersFollowingBloc>().add(
        const OthersFollowingBlocklistChanged(),
      );
    });

    return BlocBuilder<OthersFollowingBloc, OthersFollowingState>(
      builder: (context, state) {
        final isLoading = state.status == OthersFollowingStatus.initial;
        final hasLoadedCount = state.status == OthersFollowingStatus.success;

        return ProfileStatColumn(
          count: hasLoadedCount ? state.followingPubkeys.length : initialCount,
          label: context.l10n.profileFollowingStatLabel,
          isLoading: (isLoading || !hasLoadedCount) && initialCount == null,
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}
