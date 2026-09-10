// ABOUTME: Riverpod->BLoC bridge that provides a keyed ProfileFeedCubit.
// ABOUTME: Reused at every profile-feed entry point (in-shell and off-shell).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';

/// Provides a [ProfileFeedCubit] for [userIdHex], keyed so it is recreated when
/// any identity-flippable dependency changes (content/divine-host filter
/// version → fresh repo cache; repo/service/blocklist instance swaps on account
/// switch). Blocklist-version changes do NOT recreate the cubit (that would
/// drop optimistic state); instead they are forwarded as a
/// [ProfileFeedFiltersChanged] event so the feed re-filters in place (#4782).
///
/// Reused at every profile-feed entry point — including off-shell pushed routes
/// — so each subtree provides its own cubit and continuity comes from the
/// repository author cache, not a shared provider (avoids the cross-route
/// `ProviderNotFoundException` hazard).
class ProfileFeedScope extends ConsumerWidget {
  const ProfileFeedScope({
    required this.userIdHex,
    required this.child,
    super.key,
  });

  /// The author's hex pubkey.
  final String userIdHex;

  /// The subtree that consumes the provided [ProfileFeedCubit].
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentFilterVersion = ref.watch(contentFilterVersionProvider);
    final divineHostFilterVersion = ref.watch(divineHostFilterVersionProvider);
    final blocklistVersion = ref.watch(blocklistVersionProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final videoEventService = ref.watch(videoEventServiceProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final enrichmentAttemptTracker = NostrTagEnrichmentAttemptTracker();

    return BlocProvider<ProfileFeedCubit>(
      key: ValueKey((
        userIdHex,
        contentFilterVersion,
        divineHostFilterVersion,
        videosRepository,
        videoEventService,
        blocklistRepository,
      )),
      create: (_) => ProfileFeedCubit(
        authorPubkey: userIdHex,
        videosRepository: videosRepository,
        videoEventService: videoEventService,
        blocklistRepository: blocklistRepository,
        enrichVideos: (videos) => enrichVideosWithNostrTags(
          videos,
          nostrService: ref.read(nostrServiceProvider),
          callerName: 'ProfileFeedCubit',
          attemptTracker: enrichmentAttemptTracker,
        ),
      ),
      child: BlocListener<ProfileFeedCubit, ProfileFeedState>(
        listenWhen: (previous, current) =>
            !previous.hasLoadMoreError && current.hasLoadMoreError,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.profileFeedLoadMoreError,
              error: true,
            ),
          );
        },
        child: _BlocklistVersionForwarder(
          version: blocklistVersion,
          child: child,
        ),
      ),
    );
  }
}

/// Forwards blocklist-version changes into the ancestor [ProfileFeedCubit] as a
/// [ProfileFeedFiltersChanged] event (the cubit is intentionally NOT re-keyed
/// on blocklist version, so optimistic state survives a block/unblock).
class _BlocklistVersionForwarder extends StatefulWidget {
  const _BlocklistVersionForwarder({
    required this.version,
    required this.child,
  });

  final int version;
  final Widget child;

  @override
  State<_BlocklistVersionForwarder> createState() =>
      _BlocklistVersionForwarderState();
}

class _BlocklistVersionForwarderState
    extends State<_BlocklistVersionForwarder> {
  @override
  void didUpdateWidget(_BlocklistVersionForwarder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) {
      context.read<ProfileFeedCubit>().add(const ProfileFeedFiltersChanged());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
