// ABOUTME: Resolves the preview thumbnails of many curated lists together,
// ABOUTME: with one relay read for all of them and a bounded backfill.

import 'dart:async';
import 'dart:math';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

/// How long a thumbnail read waits for every relay to answer on the shared
/// connections before it asks again, on connections of its own, for the
/// videos still missing.
const kListThumbnailRelayReadTimeout = Duration(seconds: 3);

/// How long the second thumbnail read, on connections of its own, may take.
const kListThumbnailFreshRelayReadTimeout = Duration(seconds: 5);

/// The most filters relay.divine.video accepts in one REQ; it closes a REQ
/// carrying more without answering it.
const kMaxFiltersPerRelayRequest = 10;

/// How many coordinates share a filter while the REQ has room to spare.
const _coordinatesPerFilter = 50;

/// Matches a 64-character lowercase hex Nostr event ID. Every other
/// reference is read as an addressable coordinate.
final _eventIdPattern = RegExp(r'^[0-9a-f]{64}$');

bool _isEventId(String ref) => _eventIdPattern.hasMatch(ref);

/// Resolves list-card preview thumbnails for a batch of lists at once.
///
/// Hex event IDs are asked of FunnelCake first. Coordinates, and the IDs
/// FunnelCake could not illustrate, are asked of the relays in one read for
/// every list. One read per list let dozens of lists race for the client's
/// query-pool slots and queue behind each other on the relay's connection,
/// so most of them ran out of time and their slots stayed empty.
///
/// A reference that is gone, unusable or hidden gives its slot to the next
/// reference of the list, looking at no more than twice as many references as
/// the fan has slots. A reference the relays did not answer for keeps its slot
/// empty instead, so the preview shows the same videos in the same order on
/// every load, whatever was missing on this one.
class CuratedListThumbnailResolver {
  /// Creates a resolver that hides every video [hidesPreview] rejects.
  CuratedListThumbnailResolver({
    required NostrClient nostrClient,
    required FunnelcakeApiClient funnelcakeApiClient,
    required bool Function(VideoEvent video) hidesPreview,
  }) : _nostrClient = nostrClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _hidesPreview = hidesPreview;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient _funnelcakeApiClient;
  final bool Function(VideoEvent video) _hidesPreview;

  /// Returns [lists] in order, each with up to [maxThumbnails] thumbnail URLs
  /// from its [CuratedList.videoEventIds], in list order.
  ///
  /// The author and video policy is applied when the result is put together,
  /// so a policy change during the reads still hides a video.
  Future<List<CuratedList>> resolve(
    List<CuratedList> lists, {
    required int maxThumbnails,
  }) async {
    final windows = [
      for (final list in lists)
        list.videoEventIds.take(maxThumbnails * 2).toList(),
    ];
    final outcomes = <String, _Outcome>{};
    await _lookUp({
      for (final window in windows) ...window.take(maxThumbnails),
    }, outcomes);
    // Only lists left short by references that are gone or hidden read on.
    await _lookUp({
      for (final window in windows)
        if (_preview(window, outcomes, maxThumbnails).needsMore)
          for (final ref in window)
            if (!outcomes.containsKey(ref)) ref,
    }, outcomes);
    return [
      for (var i = 0; i < lists.length; i++)
        lists[i].copyWith(
          thumbnailUrls: _preview(windows[i], outcomes, maxThumbnails).urls,
        ),
    ];
  }

  /// The thumbnails [window] shows with the [outcomes] known so far, and
  /// whether a reference not yet looked up could fill a remaining slot.
  ({List<String> urls, bool needsMore}) _preview(
    List<String> window,
    Map<String, _Outcome> outcomes,
    int maxThumbnails,
  ) {
    final urls = <String>[];
    var unanswered = 0;
    for (final ref in window) {
      if (urls.length + unanswered >= maxThumbnails) break;
      final outcome = outcomes[ref];
      if (outcome == null) return (urls: urls, needsMore: true);
      if (outcome is _Unanswered) {
        unanswered++;
      } else if (outcome case _Found(
        :final video,
        :final thumbnailUrl,
      ) when !_hidesPreview(video)) {
        urls.add(thumbnailUrl);
      }
      // Otherwise gone, unusable or hidden: the next reference takes the slot.
    }
    return (urls: urls, needsMore: false);
  }

  /// Adds an outcome for every reference in [refs] to [outcomes].
  ///
  /// Coordinates go to the relays at once, while FunnelCake answers the event
  /// IDs, so a slow FunnelCake does not hold up the videos it cannot answer.
  Future<void> _lookUp(Set<String> refs, Map<String, _Outcome> outcomes) async {
    if (refs.isEmpty) return;
    final (fromEventIds, fromCoordinates) = await (
      _lookUpEventIds([
        for (final ref in refs)
          if (_isEventId(ref)) ref,
      ]),
      _readRelays([
        for (final ref in refs)
          if (!_isEventId(ref)) ref,
      ]),
    ).wait;
    outcomes
      ..addAll(fromEventIds)
      ..addAll(fromCoordinates);
  }

  /// Outcomes for hex event [ids]: FunnelCake's, and the relays' for those
  /// FunnelCake had no thumbnail for.
  ///
  /// A video FunnelCake's metadata hides stays hidden: the relays' metadata
  /// is less complete and must not override the denial.
  Future<Map<String, _Outcome>> _lookUpEventIds(List<String> ids) async {
    final videos = await Future.wait(ids.map(_tryFunnelcake));
    final outcomes = <String, _Outcome>{};
    final fromRelays = <String>[];
    for (var i = 0; i < ids.length; i++) {
      final video = videos[i];
      if (video != null && _hidesPreview(video)) {
        outcomes[ids[i]] = const _Skipped();
      } else if (video case VideoEvent(:final effectiveThumbnailUrl?)) {
        outcomes[ids[i]] = _Found(video, effectiveThumbnailUrl);
      } else {
        fromRelays.add(ids[i]);
      }
    }
    return outcomes..addAll(await _readRelays(fromRelays));
  }

  /// FunnelCake's metadata for the video with hex [eventId], or `null` when
  /// it has none or could not be asked.
  Future<VideoEvent?> _tryFunnelcake(String eventId) async {
    try {
      return (await _funnelcakeApiClient.getVideoStats(
        eventId,
      ))?.toVideoEvent();
    } on Exception {
      return null;
    }
  }

  /// Outcomes for [refs] read from the relays in one REQ.
  ///
  /// The read waits for every relay. When one did not answer in time, the
  /// references still without an event are asked again on connections of
  /// their own: Divine's relay serves one connection's requests in order, so
  /// a read queued behind slow ones is answered at once on a new connection.
  /// A reference no relay held is gone only when every relay answered.
  Future<Map<String, _Outcome>> _readRelays(List<String> refs) async {
    final query = _RelayVideoQuery(refs);
    final outcomes = <String, _Outcome>{
      for (final ref in query.unparseable) ref: const _Skipped(),
    };
    if (query.refs.isEmpty) return outcomes;

    final events = <Event>[];
    var settled = false;
    var retry = true;
    try {
      final read = await _nostrClient.queryEventsDetailed(
        query.filtersFor(query.refs),
        timeout: kListThumbnailRelayReadTimeout,
        requireAllRelaysSettled: true,
      );
      events.addAll(read.events);
      settled = !read.timedOut && !read.noRelays;
      // Without a relay to ask, new connections would find none either.
      retry = !read.noRelays;
    } on Exception {
      // Asked again on new connections below.
    }

    var selected = query.select(events);
    final missing = [
      for (final ref in query.refs)
        if (!selected.containsKey(ref)) ref,
    ];
    if (!settled && retry && missing.isNotEmpty) {
      try {
        final fresh = await _nostrClient.queryEventsOnFreshConnections(
          query.filtersFor(missing),
          timeout: kListThumbnailFreshRelayReadTimeout,
        );
        events.addAll(fresh.events);
        settled = !fresh.timedOut && !fresh.noRelays;
      } on Exception {
        // The missing references stay unanswered.
      }
      selected = query.select(events);
    }

    for (final ref in query.refs) {
      outcomes[ref] = switch (selected[ref]) {
        final event? => query.outcomeOf(ref, event),
        null when settled => const _Skipped(),
        null => const _Unanswered(),
      };
    }
    return outcomes;
  }
}

/// What a lookup found for one video reference.
sealed class _Outcome {
  const _Outcome();
}

/// A video with a thumbnail, still subject to the current policy.
final class _Found extends _Outcome {
  const _Found(this.video, this.thumbnailUrl);

  final VideoEvent video;
  final String thumbnailUrl;
}

/// A reference with nothing to show: gone, without a usable thumbnail, or
/// hidden by FunnelCake's metadata.
final class _Skipped extends _Outcome {
  const _Skipped();
}

/// A reference the relays did not answer for.
final class _Unanswered extends _Outcome {
  const _Unanswered();
}

/// A `kind:pubkey:d-tag` coordinate. The d-tag may contain colons.
typedef _Coordinate = ({int kind, String pubkey, String dTag});

_Coordinate? _parseCoordinate(String ref) {
  final parts = ref.split(':');
  if (parts.length < 3) return null;
  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;
  return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
}

/// The relay read for a set of video references: event IDs by ID, and
/// coordinates sharing filters.
///
/// A filter per coordinate would put dozens of lists' coordinates past the
/// filters one REQ may carry. A shared filter also matches an author's
/// video under another coordinate's d-tag, which [select] leaves out.
class _RelayVideoQuery {
  _RelayVideoQuery(Iterable<String> refs) {
    for (final ref in refs) {
      if (_isEventId(ref)) {
        _eventIds.add(ref);
        this.refs.add(ref);
      } else if (_parseCoordinate(ref) case final coordinate?) {
        _coordinates[ref] = coordinate;
        _refsByCoordinate.putIfAbsent(coordinate, () => []).add(ref);
        this.refs.add(ref);
      } else {
        unparseable.add(ref);
      }
    }
  }

  /// The references this query asks for.
  final List<String> refs = [];

  /// References that are neither an event ID nor a coordinate.
  final List<String> unparseable = [];

  final Set<String> _eventIds = {};
  final Map<String, _Coordinate> _coordinates = {};
  final Map<_Coordinate, List<String>> _refsByCoordinate = {};

  /// The filters for one REQ asking for [wanted]: one by ID, and as few by
  /// coordinate as fit.
  List<Filter> filtersFor(Iterable<String> wanted) {
    final ids = <String>[];
    final coordinates = <_Coordinate>[];
    for (final ref in wanted) {
      if (_coordinates[ref] case final coordinate?) {
        coordinates.add(coordinate);
      } else {
        ids.add(ref);
      }
    }
    final slots = kMaxFiltersPerRelayRequest - (ids.isEmpty ? 0 : 1);
    final perFilter = max(
      _coordinatesPerFilter,
      (coordinates.length / slots).ceil(),
    );
    return [
      if (ids.isNotEmpty) Filter(ids: ids),
      for (var i = 0; i < coordinates.length; i += perFilter)
        _coordinateFilter(coordinates.skip(i).take(perFilter)),
    ];
  }

  // No limit: a relay may apply one limit to the whole filter, and each
  // coordinate has one current revision.
  static Filter _coordinateFilter(Iterable<_Coordinate> batch) => Filter(
    kinds: {for (final c in batch) c.kind}.toList(),
    authors: {for (final c in batch) c.pubkey}.toList(),
    d: {for (final c in batch) c.dTag}.toList(),
  );

  /// The event each reference resolves to among [events]: the exact event
  /// for an ID, the newest revision for a coordinate.
  ///
  /// Revisions are chosen before anything is parsed or discarded, so a
  /// current revision that is hidden, thumbnail-less or unparseable cannot
  /// let an older revision's thumbnail through.
  Map<String, Event> select(Iterable<Event> events) {
    final selected = <String, Event>{};
    for (final event in events) {
      // An immutable event ID stays independent of coordinate revisions.
      if (_eventIds.contains(event.id)) selected[event.id] = event;
      // NIP-01 coordinates use the first raw d-tag, including an empty one.
      final coordinate = (
        kind: event.kind,
        pubkey: event.pubkey,
        dTag: event.dTagValue,
      );
      for (final ref in _refsByCoordinate[coordinate] ?? const <String>[]) {
        final current = selected[ref];
        if (current == null || _isNewer(event, than: current)) {
          selected[ref] = event;
        }
      }
    }
    return selected;
  }

  /// The outcome of [ref] resolving to [event].
  _Outcome outcomeOf(String ref, Event event) {
    try {
      final video = VideoEvent.fromNostrEvent(event, permissive: true);
      // Policy lookups must use the identity the coordinate names.
      // Contradictory parsed metadata cannot revive an older image or point
      // the preview at another coordinate.
      if (_coordinates[ref] case final coordinate?
          when coordinate.kind != video.eventKind ||
              coordinate.pubkey != video.pubkey ||
              coordinate.dTag != video.addressableDTag) {
        return const _Skipped();
      }
      return switch (video.effectiveThumbnailUrl) {
        final url? => _Found(video, url),
        null => const _Skipped(),
      };
    } on Object {
      // Not a video: VideoEvent.fromNostrEvent throws for other kinds.
      return const _Skipped();
    }
  }

  /// Whether [event] replaces [than]: a later `created_at`, or of two signed
  /// in the same second the lower ID (NIP-01).
  static bool _isNewer(Event event, {required Event than}) =>
      event.createdAt != than.createdAt
      ? event.createdAt > than.createdAt
      : event.id.compareTo(than.id) < 0;
}
