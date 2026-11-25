// ABOUTME: Observes locally known video-reply curation from either owner tool.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

/// The latest locally known curation for a video's replies. Manage Replies and
/// the comments panel both use the store to record their accepted edits.
final videoRepliesCurationProvider = StreamProvider.autoDispose
    .family<RepliesCuration?, ({String pubkey, String address})>((ref, video) {
      final events = ref.watch(latestAddressableEventsProvider);
      final dTag = RepliesCuration.dTagFor(video.address);
      const kind = RepliesCuration.kind;
      const hiddenAuthorsDTag = RepliesCuration.hiddenAuthorsDTag;
      return events
          .revisionsFor(
            pubkey: video.pubkey,
            kind: kind,
            dTags: [dTag, hiddenAuthorsDTag],
          )
          .map((_) {
            final curation = events.latest(
              pubkey: video.pubkey,
              kind: kind,
              dTag: dTag,
            );
            final hiddenAuthors = events.latest(
              pubkey: video.pubkey,
              kind: kind,
              dTag: hiddenAuthorsDTag,
            );
            if (curation == null && hiddenAuthors == null) return null;
            final replies = curation == null
                ? const RepliesCuration()
                : RepliesCuration.fromEvent(curation) ??
                      const RepliesCuration();
            return replies.withHiddenAuthors(
              hiddenAuthors == null
                  ? const {}
                  : RepliesCuration.hiddenAuthorsIn(hiddenAuthors),
            );
          })
          .distinct();
    });
