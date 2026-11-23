// ABOUTME: Reactive badge clip previews using the shared thumbnail policy.
import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';

/// Converts indexed metadata only when the clips or shared policy change.
final ProviderFamily<List<BadgeVideoPreview>, List<BadgeVideoPreview>>
visibleBadgeClipsProvider = Provider.autoDispose
    .family<List<BadgeVideoPreview>, List<BadgeVideoPreview>>((ref, clips) {
      if (clips.isEmpty) return const [];
      final hide = ref.watch(curatedListThumbnailFilterProvider);
      return [
        for (final clip in clips)
          if (!ref.watch(profileVanishedProvider(clip.pubkey)) &&
              NIP71VideoKinds.isAcceptableVideoKind(clip.kind) &&
              !hide(
                VideoEvent.fromNostrEvent(
                  Event.fromJson({
                    'id': clip.id,
                    'pubkey': clip.pubkey,
                    'created_at': clip.createdAt,
                    'kind': clip.kind,
                    'tags': clip.tags,
                    'content': '',
                  }),
                  permissive: true,
                ).copyWith(
                  moderationLabels: clip.moderationLabels,
                  isVerifiedArchive: clip.verifiedArchive,
                  isArchiveVerificationUnknown:
                      !clip.verifiedArchive && !clip.archiveProvenanceAvailable,
                ),
              ))
            clip,
      ];
    });
