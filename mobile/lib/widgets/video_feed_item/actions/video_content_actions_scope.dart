// ABOUTME: Provides a sheet's VideoContentActionsBloc for one video, built again
// ABOUTME: when a repository it captures is replaced. Both sheets use it.

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
/// signer while a sheet is open. The remix consent repository is rebuilt with
/// the profile reader it wraps. The bloc is keyed on both repositories so it
/// is rebuilt with them rather than saving or checking consent through a
/// replaced client.
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
    final remixConsentRepository = ref.watch(remixConsentRepositoryProvider);
    return BlocProvider<VideoContentActionsBloc>(
      key: ValueKey((bookmarksRepository, remixConsentRepository)),
      create: (_) => VideoContentActionsBloc(
        video: video,
        relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
        bookmarksRepository: bookmarksRepository,
        // Read, not watched: it rebuilds on every content-filter change,
        // which would reset the bloc mid-import.
        videoClipImportService: ref.read(videoClipImportServiceProvider),
        remixConsentRepository: remixConsentRepository,
        viewerPubkey: ref.read(authServiceProvider).currentPublicKeyHex,
      )..add(const VideoContentBookmarkStatusRequested()),
      child: child,
    );
  }
}
