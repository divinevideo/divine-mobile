import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// What a creator did with the video replies to one of their videos: the one
/// they pinned to the front, and the ones they hid.
///
/// Published as a NIP-78 `kind:30078` event of the creator's, whose `d` tag
/// is `divine:replies:<video address>`, with the video's address in an `a`
/// tag and each reply marked `pinned` or `hidden`: in an `a` tag by its
/// address when it is addressable, so the mark outlives an edit of the reply,
/// and otherwise in an `e` tag by its event id. A later one replaces the one
/// before.
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
      if (tag.length < 4) continue;
      final String id;
      if (tag[0] == 'e' && NostrHexUtils.isValidEventId(tag[1].toLowerCase())) {
        id = tag[1].toLowerCase();
      } else if (tag[0] == 'a' && isAddress(tag[1])) {
        id = tag[1];
      } else {
        continue;
      }
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

  /// How a curation names [reply]: its address when it is addressable, so a
  /// pin or a hide still applies after the reply is edited, and otherwise
  /// its event id.
  static String keyOf(VideoEvent reply) => reply.addressableId ?? reply.id;

  /// Whether [value] is an address, `<kind>:<pubkey>:<d>`.
  static bool isAddress(String value) {
    final parts = value.split(':');
    return parts.length >= 3 &&
        int.tryParse(parts[0]) != null &&
        NostrHexUtils.isValidPubkey(parts[1]) &&
        parts.skip(2).join(':').isNotEmpty;
  }

  /// The [keyOf] the reply pinned to the front, or `null` for none.
  final String? pinnedId;

  /// The [keyOf] each hidden reply.
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
        if (!hiddenIds.contains(keyOf(reply)) && !hiddenIds.contains(reply.id))
          reply,
    ];
    final pinnedIndex = shown.indexWhere(
      (reply) => keyOf(reply) == pinnedId || reply.id == pinnedId,
    );
    if (pinnedIndex <= 0) return shown;
    return [shown.removeAt(pinnedIndex), ...shown];
  }

  /// The tags this curation is published with for the replies to the video
  /// at [videoAddress].
  List<List<String>> toTags(String videoAddress) => [
    ['d', dTagFor(videoAddress)],
    ['a', videoAddress],
    if (pinnedId case final id?) _replyTag(id, _pinnedMarker),
    for (final id in hiddenIds) _replyTag(id, _hiddenMarker),
  ];

  static List<String> _replyTag(String key, String marker) =>
      isAddress(key) ? ['a', key, '', marker] : ['e', key, '', marker];

  @override
  List<Object?> get props => [pinnedId, hiddenIds];
}
