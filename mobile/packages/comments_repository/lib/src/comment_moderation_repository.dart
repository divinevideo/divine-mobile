// ABOUTME: Reads and publishes a video owner's comment moderation (NIP-78
// ABOUTME: kind 30078) so Divine clients leave comments the owner hid out.

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/comment.dart';
import 'package:comments_repository/src/models/comment_moderation.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Event kind of a video owner's comment moderation: NIP-78 app-specific
/// data, which clients outside Divine ignore. The comments themselves stay on
/// relays.
const commentModerationKind = 30078;

/// The `d` tag prefix of a video owner's decisions about the replies to one
/// of their videos; the video's address follows it.
///
/// Shared with `RepliesCuration` in `video_responses_repository`: one event
/// per video holds what the owner did with all its replies, video replies and
/// comments alike, and each writer keeps the tags the other wrote.
const videoRepliesModerationPrefix = 'divine:replies:';

/// The `d` tag of the commenters an owner hides on all of their videos.
const hiddenCommentersIdentifier = 'divine:hidden-commenters';

/// Reads and saves the moderation video owners publish for their comments.
///
/// Per video, an entry `["e", <comment id>, "", <marker>]` — or `["a",
/// <address>, …]` for an addressable video reply — is `hidden` or
/// `restored`; a restore keeps one comment from someone the owner otherwise
/// hides. Per account, `p` tags name those commenters.
///
/// Only an event signed by the owner named in a video's address counts for
/// that video, so nobody can moderate someone else's comments.
class CommentModerationRepository {
  /// Creates a repository that reads and publishes through [nostrClient].
  ///
  /// [latestEvents] holds the newest moderation events seen. Share it with
  /// the replies writer of `video_responses_repository`, which replaces the
  /// same per-video event, so neither builds on a version older than the
  /// other just published.
  CommentModerationRepository({
    required NostrClient nostrClient,
    LatestAddressableEvents? latestEvents,
  }) : _nostrClient = nostrClient,
       _latestEvents = latestEvents ?? LatestAddressableEvents();

  final NostrClient _nostrClient;

  /// How long [loadModeration] waits for relays before the thread is shown
  /// without the moderation it could not read.
  static const _loadTimeout = Duration(seconds: 3);

  /// How long a save waits for relays to accept the new moderation.
  static const _publishTimeout = Duration(seconds: 5);

  static const _hiddenMarker = 'hidden';
  static const _restoredMarker = 'restored';

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// The newest moderation events seen, including the ones published here
  /// or by a writer sharing the store, which relays may not serve back yet.
  final LatestAddressableEvents _latestEvents;

  /// The owner named in [rootAddressableId] (`kind:pubkey:d-tag`), or `null`
  /// when it names no valid pubkey.
  static String? ownerOf(String rootAddressableId) {
    final parts = rootAddressableId.split(':');
    if (parts.length < 3) return null;
    final pubkey = parts[1];
    return _hex64.hasMatch(pubkey) ? pubkey : null;
  }

  /// Loads the moderation the owner of [rootAddressableId] published for its
  /// comments.
  ///
  /// Never throws. A read that fails or runs out of time falls back to the
  /// moderation seen last, or to [CommentModeration.empty]: hiding is
  /// de-prominence, so an unreadable list shows the comments rather than
  /// withholding the thread.
  Future<CommentModeration> loadModeration({
    required String rootAddressableId,
  }) async {
    final owner = ownerOf(rootAddressableId);
    if (owner == null) return CommentModeration.empty;
    try {
      final result = await _nostrClient.queryEventsDetailed([
        Filter(
          kinds: const [commentModerationKind],
          authors: [owner],
          d: [
            _videoIdentifier(rootAddressableId),
            hiddenCommentersIdentifier,
          ],
        ),
      ], timeout: _loadTimeout);
      _remember(
        result.events.where(
          (event) =>
              _isModerationBy(
                event,
                owner,
                _videoIdentifier(rootAddressableId),
              ) ||
              _isModerationBy(event, owner, hiddenCommentersIdentifier),
        ),
      );
    } on Exception {
      // Fail open: the thread shows with what was seen last, see above.
    }
    return _moderationOf(owner, rootAddressableId);
  }

  /// The latest authenticated cached state and its scoped change version.
  /// Reading this snapshot does not query relays or emit a new change.
  ({CommentModeration moderation, int revision}) knownModeration({
    required String rootAddressableId,
  }) {
    final owner = ownerOf(rootAddressableId);
    if (owner == null) {
      return const (moderation: CommentModeration.empty, revision: 0);
    }
    return (
      moderation: _moderationOf(owner, rootAddressableId),
      revision: _latestEvents.revisionFor(
        pubkey: owner,
        kind: commentModerationKind,
        dTags: [
          _videoIdentifier(rootAddressableId),
          hiddenCommentersIdentifier,
        ],
      ),
    );
  }

  /// Observes only this video's moderation and its owner's hidden commenters.
  Stream<int> watchModeration({required String rootAddressableId}) {
    final owner = ownerOf(rootAddressableId);
    if (owner == null) return Stream.value(0);
    return _latestEvents.revisionsFor(
      pubkey: owner,
      kind: commentModerationKind,
      dTags: [_videoIdentifier(rootAddressableId), hiddenCommentersIdentifier],
    );
  }

  /// Hides [comment] on the signed-in owner's video [rootAddressableId].
  ///
  /// Throws [CommentModerationFailedException] when the signed-in account
  /// does not own the video, when its current moderation cannot be read in
  /// full, or when no relay accepts the new one.
  Future<void> hideComment({
    required String rootAddressableId,
    required Comment comment,
  }) => _replaceVideoEntry(
    rootAddressableId: rootAddressableId,
    comment: comment,
    marker: _hiddenMarker,
  );

  /// Shows [comment] on the signed-in owner's video [rootAddressableId]
  /// again.
  ///
  /// [authorAutoHidden] says whether the comment's author is auto-hidden; the
  /// comment is then marked restored, which wins over the auto-hide.
  /// Otherwise it only loses its hide.
  ///
  /// Throws [CommentModerationFailedException] in the same cases as
  /// [hideComment].
  Future<void> restoreComment({
    required String rootAddressableId,
    required Comment comment,
    required bool authorAutoHidden,
  }) => _replaceVideoEntry(
    rootAddressableId: rootAddressableId,
    comment: comment,
    marker: authorAutoHidden ? _restoredMarker : null,
  );

  /// Adds [add] to and removes [remove] from the commenters hidden on all of
  /// the signed-in account's videos.
  ///
  /// Publishes nothing when that changes nothing. Never lists the account
  /// itself.
  ///
  /// Throws [CommentModerationFailedException] when no account is signed in,
  /// when the current list cannot be read in full, or when no relay accepts
  /// the new one.
  Future<void> updateAutoHiddenAuthors({
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
  }) async {
    final owner = _nostrClient.publicKey;
    if (!_hex64.hasMatch(owner)) {
      throw const CommentModerationFailedException('No signed-in account');
    }
    return _latestEvents.run(
      pubkey: owner,
      kind: commentModerationKind,
      dTag: hiddenCommentersIdentifier,
      operation: () =>
          _updateAutoHiddenAuthors(owner, add: add, remove: remove),
    );
  }

  Future<void> _updateAutoHiddenAuthors(
    String owner, {
    required Iterable<String> add,
    required Iterable<String> remove,
  }) async {
    final current = await _readLatestOwn(owner, hiddenCommentersIdentifier);
    final currentAuthors = _autoHiddenAuthorsOf(current);
    final authors = <String>{
      ...currentAuthors,
      ...add.where((pubkey) => pubkey.isNotEmpty && pubkey != owner),
    }..removeAll(remove);
    if (authors.length == currentAuthors.length &&
        authors.containsAll(currentAuthors)) {
      return;
    }
    await _publish(owner, current, [
      ['d', hiddenCommentersIdentifier],
      // The signing path re-derives Divine's `client` tag from the user's
      // current choice, so the old one is not carried forward.
      for (final tag in Nip89ClientTag.withoutClientTag(
        current?.tags ?? const [],
      ))
        if (tag.isNotEmpty && tag[0] != 'd' && tag[0] != 'p') tag,
      for (final author in authors) ['p', author],
    ]);
  }

  Future<void> _replaceVideoEntry({
    required String rootAddressableId,
    required Comment comment,
    required String? marker,
  }) async {
    final owner = _nostrClient.publicKey;
    if (ownerOf(rootAddressableId) != owner) {
      throw const CommentModerationFailedException(
        'Only the video owner can moderate its comments',
      );
    }
    final identifier = _videoIdentifier(rootAddressableId);
    return _latestEvents.run(
      pubkey: owner,
      kind: commentModerationKind,
      dTag: identifier,
      operation: () => _saveVideoEntry(
        owner: owner,
        identifier: identifier,
        rootAddressableId: rootAddressableId,
        comment: comment,
        marker: marker,
      ),
    );
  }

  Future<void> _saveVideoEntry({
    required String owner,
    required String identifier,
    required String rootAddressableId,
    required Comment comment,
    required String? marker,
  }) async {
    final current = await _readLatestOwn(owner, identifier);
    final keys = {
      comment.id.toLowerCase(),
      ?comment.addressableId,
      CommentModeration.keyOf(comment),
    };
    await _publish(owner, current, [
      ['d', identifier],
      ['a', rootAddressableId],
      // Everything else stays, including the pins and hides of video replies
      // the replies sticker wrote; the `client` tag is re-derived.
      for (final tag in Nip89ClientTag.withoutClientTag(
        current?.tags ?? const [],
      ))
        if (!_isIdentifier(tag) &&
            !_isVideoAssociation(tag, rootAddressableId) &&
            !_isModerationOf(tag, keys))
          tag,
      if (marker == _restoredMarker)
        // One version only: a replacement under the same address is hidden
        // again.
        _entry(comment.id.toLowerCase(), _restoredMarker)
      else if (marker != null)
        _entry(CommentModeration.keyOf(comment), marker),
    ]);
  }

  /// Reads [owner]'s newest event for [identifier], requiring every relay to
  /// answer.
  ///
  /// A replacement built on a partial read would erase whatever only the
  /// unread event held, so a read that times out or reaches no relay throws.
  Future<Event?> _readLatestOwn(String owner, String identifier) async {
    _requireOwner(owner);
    final ({List<Event> events, bool noRelays, bool timedOut}) result;
    try {
      result = await _nostrClient.queryEventsDetailed([
        Filter(
          kinds: const [commentModerationKind],
          authors: [owner],
          d: [identifier],
        ),
      ], requireAllRelaysSettled: true);
    } on Exception catch (e) {
      throw CommentModerationFailedException('Moderation read failed: $e');
    }
    _requireOwner(owner);
    if (result.timedOut || result.noRelays) {
      throw const CommentModerationFailedException(
        'Moderation could not be read in full',
      );
    }
    _remember(
      result.events.where((event) => _isModerationBy(event, owner, identifier)),
    );
    return _latest(owner, identifier);
  }

  Future<void> _publish(
    String owner,
    Event? current,
    List<List<String>> tags,
  ) async {
    _requireOwner(owner);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // A replacement must be newer than the event it replaces, or relays keep
    // the old one.
    final createdAt = current != null && current.createdAt >= now
        ? current.createdAt + 1
        : now;
    final event = Event(
      owner,
      commentModerationKind,
      tags,
      current?.content ?? '',
      createdAt: createdAt,
    );
    final PublishOutcome outcome;
    try {
      outcome = await _nostrClient.publishEventAwaitOk(
        event,
        timeout: _publishTimeout,
      );
    } on Exception catch (e) {
      throw CommentModerationFailedException('Moderation publish failed: $e');
    }
    if (outcome.failed) {
      throw CommentModerationFailedException(
        'No relay accepted the moderation: ${outcome.summary}',
      );
    }
    _remember([event]);
  }

  void _requireOwner(String owner) {
    if (_nostrClient.publicKey != owner) {
      throw const CommentModerationFailedException(
        'The signed-in account changed',
      );
    }
  }

  void _remember(Iterable<Event> events) {
    for (final event in events) {
      // Of two versions signed in the same second the store keeps the lower
      // id, as relays do (NIP-01).
      if (event.kind == commentModerationKind) _latestEvents.remember(event);
    }
  }

  Event? _latest(String owner, String identifier) => _latestEvents.latest(
    pubkey: owner,
    kind: commentModerationKind,
    dTag: identifier,
  );

  CommentModeration _moderationOf(String owner, String rootAddressableId) {
    final videoEvent = _latest(owner, _videoIdentifier(rootAddressableId));
    final accountEvent = _latest(owner, hiddenCommentersIdentifier);
    final hidden = <String>{};
    final restored = <String>{};
    for (final tag in videoEvent?.tags ?? const <List<String>>[]) {
      final key = _entryKeyOf(tag);
      if (key == null) continue;
      switch (tag[3]) {
        case _hiddenMarker:
          hidden.add(key);
        case _restoredMarker:
          restored.add(key);
      }
    }
    return CommentModeration(
      hiddenCommentIds: hidden,
      restoredCommentIds: restored,
      autoHiddenAuthors: _autoHiddenAuthorsOf(accountEvent),
    );
  }

  // The replies writer keeps historical Divine-format keys for horizontal
  // videos, even though native Nostr references now carry their real kind.
  static String _videoIdentifier(String rootAddressableId) =>
      '$videoRepliesModerationPrefix'
      '${legacyVideoCoordinateFor(rootAddressableId) ?? rootAddressableId}';

  static Set<String> _autoHiddenAuthorsOf(Event? event) => {
    for (final tag in event?.tags ?? const <List<String>>[])
      if (tag.length >= 2 && tag[0] == 'p' && _hex64.hasMatch(tag[1])) tag[1],
  };

  /// The comment a marked `e` or `a` entry names, or `null` for any other
  /// tag.
  static String? _entryKeyOf(List<String> tag) {
    if (tag.length < 4) return null;
    final value = tag[1];
    if (tag[0] == 'e' && _hex64.hasMatch(value.toLowerCase())) {
      return value.toLowerCase();
    }
    if (tag[0] == 'a' && _isAddress(value)) return value;
    return null;
  }

  /// Whether [tag] hides or restores one of [keys]; a pin of the same video
  /// reply is not moderation and stays.
  static bool _isModerationOf(List<String> tag, Set<String> keys) {
    final key = _entryKeyOf(tag);
    return key != null &&
        keys.contains(key) &&
        (tag[3] == _hiddenMarker || tag[3] == _restoredMarker);
  }

  static List<String> _entry(String key, String marker) =>
      _isAddress(key) ? ['a', key, '', marker] : ['e', key, '', marker];

  static bool _isAddress(String value) {
    final parts = value.split(':');
    return parts.length >= 3 &&
        int.tryParse(parts[0]) != null &&
        _hex64.hasMatch(parts[1]) &&
        parts.skip(2).join(':').isNotEmpty;
  }

  static bool _isIdentifier(List<String> tag) =>
      tag.isNotEmpty && tag[0] == 'd';

  static bool _isVideoAssociation(List<String> tag, String rootAddressableId) =>
      tag.length >= 2 &&
      tag[0] == 'a' &&
      (legacyVideoCoordinateFor(tag[1]) ?? tag[1]) ==
          (legacyVideoCoordinateFor(rootAddressableId) ?? rootAddressableId) &&
      (tag.length < 4 || tag[3].isEmpty);

  /// Whether a relay's [event] is [owner]'s signed moderation for
  /// [identifier]: only then may its tags count, or be signed again.
  static bool _isModerationBy(Event event, String owner, String identifier) =>
      event.pubkey == owner &&
      event.kind == commentModerationKind &&
      event.dTagValue == identifier &&
      event.isValid &&
      event.isSigned;
}
