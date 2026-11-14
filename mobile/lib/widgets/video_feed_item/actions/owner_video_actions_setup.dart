// ABOUTME: Ownership check and owner actions cubit shared by the share sheet
// ABOUTME: and the video info sheet, so both decide and build them the same way.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether the signed-in viewer created [video].
///
/// An auth state that cannot be read counts as "not the owner": owner actions
/// are withheld rather than letting the failure escape the sheet opening.
bool isViewerOwnVideo(ProviderContainer container, VideoEvent video) {
  try {
    final authService = container.read(authServiceProvider);
    if (!authService.isAuthenticated) return false;

    final userPubkey = authService.currentPublicKeyHex;
    if (userPubkey == null) return false;

    return video.pubkey == userPubkey;
  } catch (e) {
    Log.error(
      'Error checking content ownership: $e',
      name: 'OwnerVideoActionsSetup',
      category: LogCategory.ui,
    );
    return false;
  }
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
