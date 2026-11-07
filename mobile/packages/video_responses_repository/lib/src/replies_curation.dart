import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, legacyVideoCoordinateFor;

/// What a creator did with the video replies to one of their videos: the one
/// they pinned to the front, the ones they hid, and the accounts whose
/// replies they hide on all their videos.
///
/// Published as a NIP-78 `kind:30078` event of the creator's, whose `d` tag
/// is `divine:replies:<video address>`, with the video's address in an `a`
/// tag and each reply marked `pinned`, `hidden` or `restored`: in an `a` tag
/// by its address when it is addressable, so the mark outlives an edit of the
/// reply, and otherwise in an `e` tag by its event id. A later one replaces
/// the one before. `restored` keeps a reply shown although its author is
/// among [hiddenAuthors], which a separate event of the creator's names, the
/// one whose `d` tag is [hiddenAuthorsDTag]. The comments sheet reads and
/// writes the same marks for the comments on the video.
class RepliesCuration extends Equatable {
  /// Creates a curation.
  const RepliesCuration({
    this.pinnedId,
    this.hiddenIds = const {},
    this.restoredIds = const {},
    this.hiddenAuthors = const {},
  });

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
    final restoredIds = <String>{};
    for (final tag in event.tags) {
      final id = _keyIn(tag);
      if (id == null) continue;
      switch (tag[3]) {
        case _pinnedMarker:
          pinnedId ??= id;
        case _hiddenMarker:
          hiddenIds.add(id);
        case _restoredMarker:
          restoredIds.add(id);
      }
    }
    // A reply marked both ways shows, as the comments sheet reads it.
    hiddenIds.removeAll(restoredIds);
    return RepliesCuration(
      pinnedId: hiddenIds.contains(pinnedId) ? null : pinnedId,
      hiddenIds: hiddenIds,
      restoredIds: restoredIds,
    );
  }

  /// The accounts the creator's [event] of [hiddenAuthorsDTag] names, or
  /// none when it is not that event.
  static Set<String> hiddenAuthorsIn(Event event) {
    if (event.kind != kind) return const {};
    final named = event.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'd' && tag[1] == hiddenAuthorsDTag,
    );
    if (!named) return const {};
    return {
      for (final tag in event.tags)
        if (tag.length >= 2 &&
            tag[0] == 'p' &&
            _pubkey.hasMatch(tag[1]) &&
            tag[1] != event.pubkey)
          tag[1],
    };
  }

  /// The event kind a curation is published as, NIP-78's.
  static const int kind = 30078;

  /// The `d` tag of the creator's event naming the accounts whose replies
  /// and comments they hide on all their videos.
  static const String hiddenAuthorsDTag = 'divine:hidden-commenters';

  static const String _dTagPrefix = 'divine:replies:';
  static const String _pinnedMarker = 'pinned';
  static const String _hiddenMarker = 'hidden';
  static const String _restoredMarker = 'restored';
  static final RegExp _pubkey = RegExp(r'^[0-9a-f]{64}$');

  /// The `d` tag of the curation of the replies to the video at
  /// [videoAddress], under the 34236 key Divine always gave a Kind 34235
  /// video ([VideoEvent.divineAddress]).
  static String dTagFor(String videoAddress) =>
      '$_dTagPrefix${legacyVideoCoordinateFor(videoAddress) ?? videoAddress}';

  /// How a curation names [reply]: its [VideoEvent.divineAddress] when it is
  /// addressable, so a pin or a hide still applies after the reply is edited,
  /// and otherwise its event id.
  static String keyOf(VideoEvent reply) => reply.divineAddress ?? reply.id;

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

  /// The event id of each reply shown although its author is among
  /// [hiddenAuthors].
  ///
  /// By event id, unlike a pin or a hide: showing a reply approves that
  /// version, so one its author replaces under the same address is hidden
  /// again until the creator shows it.
  final Set<String> restoredIds;

  /// The accounts whose replies the creator hides on all their videos: those
  /// they blocked. Read from a separate event, and never published with
  /// [toTags].
  final Set<String> hiddenAuthors;

  /// Whether viewers do not see [reply]: the creator hid it, or hid its
  /// author and did not show it again.
  bool hides(VideoEvent reply) {
    if (restoredIds.contains(reply.id)) return false;
    return hiddenIds.contains(keyOf(reply)) ||
        hiddenIds.contains(reply.id) ||
        hiddenAuthors.contains(reply.pubkey);
  }

  /// This curation with [replyId] pinned to the front instead, shown again
  /// when it was hidden; `null` pins none. [restoredEventId], the version the
  /// creator approves, is marked `restored` when the reply's author is among
  /// [hiddenAuthors].
  RepliesCuration pinned(String? replyId, {String? restoredEventId}) =>
      RepliesCuration(
        pinnedId: replyId,
        hiddenIds: {...hiddenIds}..remove(replyId),
        restoredIds: {...restoredIds, ?restoredEventId},
        hiddenAuthors: hiddenAuthors,
      );

  /// This curation with [replyId] hidden, no longer pinned, and the version
  /// [eventId] names no longer restored.
  RepliesCuration hidden(String replyId, {String? eventId}) => RepliesCuration(
    pinnedId: pinnedId == replyId ? null : pinnedId,
    hiddenIds: {...hiddenIds, replyId},
    restoredIds: {...restoredIds}
      ..remove(replyId)
      ..remove(eventId),
    hiddenAuthors: hiddenAuthors,
  );

  /// This curation with [replyId] shown again. [restoredEventId], the
  /// version the creator approves, is marked `restored` when the reply's
  /// author is among [hiddenAuthors].
  RepliesCuration shown(String replyId, {String? restoredEventId}) =>
      RepliesCuration(
        pinnedId: pinnedId,
        hiddenIds: {...hiddenIds}..remove(replyId),
        restoredIds: {...restoredIds, ?restoredEventId},
        hiddenAuthors: hiddenAuthors,
      );

  /// This curation hiding the replies of [authors] on all the creator's
  /// videos.
  RepliesCuration withHiddenAuthors(Set<String> authors) => RepliesCuration(
    pinnedId: pinnedId,
    hiddenIds: hiddenIds,
    restoredIds: restoredIds,
    hiddenAuthors: authors,
  );

  /// [replies] as viewers see them: the pinned one first, the hidden ones
  /// left out.
  List<VideoEvent> apply(List<VideoEvent> replies) {
    final shown = [
      for (final reply in replies)
        if (!hides(reply)) reply,
    ];
    final pinnedIndex = shown.indexWhere(
      (reply) => keyOf(reply) == pinnedId || reply.id == pinnedId,
    );
    if (pinnedIndex <= 0) return shown;
    return [shown.removeAt(pinnedIndex), ...shown];
  }

  /// The tags this curation is published with for the replies to the video
  /// at [videoAddress].
  ///
  /// The first tag is the canonical `d` for [videoAddress], with a video
  /// association alongside it; an existing association keeps its hints.
  /// Other [sourceTags] are kept, including relay hints and extra elements,
  /// except source `d` tags and pinned, hidden or restored marks no longer
  /// made. Newly added marks follow the preserved tags.
  List<List<String>> toTags(
    String videoAddress, {
    List<List<String>>? sourceTags,
  }) {
    if (sourceTags == null) {
      return [
        ['d', dTagFor(videoAddress)],
        ['a', videoAddress],
        if (pinnedId case final id?) _replyTag(id, _pinnedMarker),
        for (final id in hiddenIds) _replyTag(id, _hiddenMarker),
        for (final id in restoredIds) _replyTag(id, _restoredMarker),
      ];
    }
    final videoTag = sourceTags
        .where(
          (tag) => _isVideoAssociation(tag, videoAddress),
        )
        .firstOrNull;
    final tags = <List<String>>[
      ['d', dTagFor(videoAddress)],
      List.of(videoTag ?? ['a', videoAddress]),
    ];
    final sourcedHidden = <String>{};
    final sourcedRestored = <String>{};
    var sourcedPin = false;
    for (final tag in sourceTags) {
      if ((tag.isNotEmpty && tag[0] == 'd') ||
          _isVideoAssociation(tag, videoAddress)) {
        continue;
      }
      final key = _keyIn(tag);
      final marker = key == null ? null : tag[3];
      switch (marker) {
        case _pinnedMarker:
          if (key != pinnedId) continue;
          sourcedPin = true;
        case _hiddenMarker:
          if (!hiddenIds.contains(key)) continue;
          sourcedHidden.add(key!);
        case _restoredMarker:
          if (!restoredIds.contains(key)) continue;
          sourcedRestored.add(key!);
      }
      tags.add(List.of(tag));
    }
    if (pinnedId case final id? when !sourcedPin) {
      tags.add(_replyTag(id, _pinnedMarker));
    }
    for (final id in hiddenIds.difference(sourcedHidden)) {
      tags.add(_replyTag(id, _hiddenMarker));
    }
    for (final id in restoredIds.difference(sourcedRestored)) {
      tags.add(_replyTag(id, _restoredMarker));
    }
    return tags;
  }

  static bool _isVideoAssociation(List<String> tag, String videoAddress) =>
      tag.length >= 2 &&
      tag[0] == 'a' &&
      tag[1] == videoAddress &&
      (tag.length < 4 || tag[3].isEmpty);

  static String? _keyIn(List<String> tag) {
    if (tag.length < 4) return null;
    if (tag[0] == 'e' && NostrHexUtils.isValidEventId(tag[1].toLowerCase())) {
      return tag[1].toLowerCase();
    }
    if (tag[0] == 'a' && isAddress(tag[1])) return tag[1];
    return null;
  }

  static List<String> _replyTag(String key, String marker) =>
      isAddress(key) ? ['a', key, '', marker] : ['e', key, '', marker];

  @override
  List<Object?> get props => [pinnedId, hiddenIds, restoredIds, hiddenAuthors];
}
