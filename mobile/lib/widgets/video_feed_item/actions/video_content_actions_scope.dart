// ABOUTME: Provides a sheet's VideoContentActionsBloc for one video, built
// ABOUTME: again whenever the bookmarks repository is replaced. Both sheets use it.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';

/// Provides the [VideoContentActionsBloc] for [video] to [child], and asks it
/// for the bookmark status straight away.
///
/// The bookmarks repository is rebuilt, and the old one disposed, when the
/// Nostr client is replaced, for instance when a restored session gains its
/// signer while a sheet is open. The bloc is keyed on the repository so it is
/// rebuilt with it rather than saving through a disposed client.
class VideoContentActionsScope extends ConsumerWidget {
  const VideoContentActionsScope({
    required this.video,
    required this.child,
    super.key,
  });

  final VideoEvent video;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksRepository = ref.watch(bookmarksRepositoryProvider);
    return BlocProvider<VideoContentActionsBloc>(
      key: ValueKey(bookmarksRepository),
      create: (_) => VideoContentActionsBloc(
        video: video,
        relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
        bookmarksRepository: bookmarksRepository,
        // Read, not watched: it rebuilds on every content-filter change,
        // which would reset the bloc mid-import.
        videoClipImportService: ref.read(videoClipImportServiceProvider),
      )..add(const VideoContentBookmarkStatusRequested()),
      child: child,
    );
  }
}
