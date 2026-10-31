import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// What a creator did with the video replies to one of their videos: the one
/// they pinned to the front, and the ones they hid.
///
/// Published as a NIP-78 `kind:30078` event of the creator's, whose `d` tag
/// is `divine:replies:<video address>`, with the video's address in an `a`
/// tag and each reply in an `e` tag marked `pinned` or `hidden`. A later one
/// replaces the one before.
class RepliesCuration extends Equatable {
  /// Creates a curation.
  const RepliesCuration({this.pinnedId, this.hiddenIds = const {}});

  /// The curation a creator's [event] publishes, or `null` when it is none.
  static RepliesCuration? fromEvent(Event event) {
    if (event.kind != kind) return null;
    final hasDTag = event.tags.any(
      (tag) =>
          tag.length >= 2 && tag[0] == 'd' && tag[1].startsWith(_dTagPrefix),
    );
    if (!hasDTag) return null;
    String? pinnedId;
    final hiddenIds = <String>{};
    for (final tag in event.tags) {
      if (tag.length < 4 || tag[0] != 'e') continue;
      final id = tag[1].toLowerCase();
      if (!NostrHexUtils.isValidEventId(id)) continue;
      switch (tag[3]) {
        case _pinnedMarker:
          pinnedId ??= id;
        case _hiddenMarker:
          hiddenIds.add(id);
      }
    }
    return RepliesCuration(
      pinnedId: hiddenIds.contains(pinnedId) ? null : pinnedId,
      hiddenIds: hiddenIds,
    );
  }

  /// The event kind a curation is published as, NIP-78's.
  static const int kind = 30078;

  static const String _dTagPrefix = 'divine:replies:';
  static const String _pinnedMarker = 'pinned';
  static const String _hiddenMarker = 'hidden';

  /// The `d` tag of the curation of the replies to the video at
  /// [videoAddress].
  static String dTagFor(String videoAddress) => '$_dTagPrefix$videoAddress';

  /// The event id of the reply pinned to the front, or `null` for none.
  final String? pinnedId;

  /// The event ids of the hidden replies.
  final Set<String> hiddenIds;

  /// This curation with [replyId] pinned to the front instead, shown again
  /// when it was hidden; `null` pins none.
  RepliesCuration pinned(String? replyId) => RepliesCuration(
    pinnedId: replyId,
    hiddenIds: {...hiddenIds}..remove(replyId),
  );

  /// This curation with [replyId] hidden, and no longer pinned.
  RepliesCuration hidden(String replyId) => RepliesCuration(
    pinnedId: pinnedId == replyId ? null : pinnedId,
    hiddenIds: {...hiddenIds, replyId},
  );

  /// This curation with [replyId] shown again.
  RepliesCuration shown(String replyId) => RepliesCuration(
    pinnedId: pinnedId,
    hiddenIds: {...hiddenIds}..remove(replyId),
  );

  /// [replies] as viewers see them: the pinned one first, the hidden ones
  /// left out.
  List<VideoEvent> apply(List<VideoEvent> replies) {
    final shown = [
      for (final reply in replies)
        if (!hiddenIds.contains(reply.id)) reply,
    ];
    final pinnedIndex = shown.indexWhere((reply) => reply.id == pinnedId);
    if (pinnedIndex <= 0) return shown;
    return [shown.removeAt(pinnedIndex), ...shown];
  }

  /// The tags this curation is published with for the replies to the video
  /// at [videoAddress].
  List<List<String>> toTags(String videoAddress) => [
    ['d', dTagFor(videoAddress)],
    ['a', videoAddress],
    if (pinnedId case final id?) ['e', id, '', _pinnedMarker],
    for (final id in hiddenIds) ['e', id, '', _hiddenMarker],
  ];

  @override
  List<Object?> get props => [pinnedId, hiddenIds];
}
