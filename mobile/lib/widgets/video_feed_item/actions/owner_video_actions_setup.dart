// ABOUTME: Viewer checks and the owner actions cubit shared by the share sheet
// ABOUTME: and the video info sheet, so both decide and build them the same way.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:unified_logger/unified_logger.dart';

/// The signed-in viewer's hex pubkey, or null when no one is signed in.
///
/// An auth state that cannot be read counts as signed out: viewer-only
/// actions are withheld rather than letting the failure escape the sheet
/// opening.
String? signedInViewerPubkey(ProviderContainer container) {
  try {
    final authService = container.read(authServiceProvider);
    if (!authService.isAuthenticated) return null;

    return authService.currentPublicKeyHex;
  } catch (e) {
    Log.error(
      'Error checking content ownership: $e',
      name: 'OwnerVideoActionsSetup',
      category: LogCategory.ui,
    );
    return null;
  }
}

/// Whether the signed-in viewer created [video].
///
/// An auth state that cannot be read counts as "not the owner": owner actions
/// are withheld rather than letting the failure escape the sheet opening.
bool isViewerOwnVideo(ProviderContainer container, VideoEvent video) =>
    isVideoByViewer(video, signedInViewerPubkey(container));

/// Whether [viewerPubkey], the signed-in viewer, created [video].
bool isVideoByViewer(VideoEvent video, String? viewerPubkey) =>
    viewerPubkey != null && pubkeysEqual(video.pubkey, viewerPubkey);

/// Whether [video], posted by someone else, credits a clip of one of the
/// videos of [viewerPubkey], the signed-in viewer.
bool isRemixOfViewersVideo(VideoEvent video, String? viewerPubkey) {
  if (viewerPubkey == null) return false;
  if (isVideoByViewer(video, viewerPubkey)) return false;
  return video.clipSourceCredits.any(
    (credit) => pubkeysEqual(credit.authorPubkey, viewerPubkey),
  );
}

/// Builds the [OwnerVideoActionsCubit] for a sheet acting on the viewer's own
/// video.
///
/// The services are read from [container] when an action runs, not now.
OwnerVideoActionsCubit createOwnerVideoActionsCubit(
  ProviderContainer container,
) {
  return OwnerVideoActionsCubit(
    contentDeletionService: () =>
        container.read(contentDeletionServiceProvider.future),
    videoEventService: () => container.read(videoEventServiceProvider),
    enforcementRepository: () =>
        container.read(creatorDeleteEnforcementRepositoryProvider),
  );
}
