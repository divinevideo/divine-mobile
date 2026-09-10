// ABOUTME: Page widget for the video engagement (likers/reposters) list.
// ABOUTME: Bridges Riverpod-provided repositories into VideoEngagementBloc.
// ABOUTME: This is the canonical ConsumerWidget Page + BlocProvider pattern —
// ABOUTME: see docs/BLOC_UI_MIGRATION_PRD.md "Canonical Template Screens".

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_view.dart';

/// Page widget for the video engagement (likers / reposters) list.
///
/// This screen is the Page layer of the Page/View split:
/// - [VideoEngagementListScreen] is a [ConsumerWidget] that reads Riverpod
///   dependency providers and hands them into [VideoEngagementBloc] via
///   [BlocProvider].
/// - [VideoEngagementListView] (in `video_engagement_list_view.dart`) is the
///   pure [StatelessWidget] View that consumes only [VideoEngagementBloc] state.
///
/// The [ValueKey] on [BlocProvider] is a record of all captured Riverpod deps
/// plus the event-specific params. Flutter recreates the bloc subtree whenever
/// any captured dependency changes (e.g. on auth flip / account switch),
/// ensuring the bloc never holds a stale repository reference.
class VideoEngagementListScreen extends ConsumerWidget {
  const VideoEngagementListScreen({
    required this.eventId,
    required this.type,
    super.key,
    this.addressableId,
  });

  /// Path under the video route. Concrete child paths are
  /// `likers` and `reposters`.
  static const path = ':eventId';
  static const likersSubPath = 'likers';
  static const repostersSubPath = 'reposters';

  /// Route name used for the likers list.
  static const likersRouteName = 'videoLikers';

  /// Route name used for the reposters list.
  static const repostersRouteName = 'videoReposters';

  /// Hex id of the target video event.
  final String eventId;

  /// Whether to render the likers list or the reposters list.
  final VideoEngagementType type;

  /// Optional `kind:pubkey:d-tag` for addressable video events. The list is
  /// merged across the `e` and `a` tags when this is provided.
  final String? addressableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.watch(likesRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);

    return BlocProvider<VideoEngagementBloc>(
      key: ValueKey(
        (
          likesRepository,
          repostsRepository,
          profileRepository,
          eventId,
          type,
          addressableId,
        ),
      ),
      create: (_) => VideoEngagementBloc(
        eventId: eventId,
        type: type,
        likesRepository: likesRepository,
        repostsRepository: repostsRepository,
        profileRepository: profileRepository,
        addressableId: addressableId,
      )..add(const VideoEngagementLoadRequested()),
      child: const VideoEngagementListView(),
    );
  }
}
