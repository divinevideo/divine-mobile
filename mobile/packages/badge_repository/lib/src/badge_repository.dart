import 'dart:async';

import 'package:badge_repository/src/badge_coordinate.dart';
import 'package:badge_repository/src/nip58_badge_models.dart';
import 'package:badge_repository/src/nip58_badge_parser.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

typedef BadgeCurrentPubkeyReader = String? Function();

/// Whether [pubkey] is hidden for the current user — blocked, muted, or on
/// the platform blocklist.
///
/// A function rather than the blocklist repository itself: a repository does
/// not depend on another repository, and the app layer already owns the
/// canonical hide set.
typedef BadgeHiddenPubkeyReader = bool Function(String pubkey);

// Trust-safety bulk actions must stay bounded even when a public badge is
// claimed by a very large group. These limits keep relay/cache reads finite:
// first discover the newest claim events, then verify latest profile-badge
// state in author chunks instead of issuing per-claimant REQs.
const int _claimantCandidateEventLimit = 1000;
const int _claimantProfileAuthorChunkSize = 100;
const int _profileBadgeEventsPerAuthorLimit = 10;

typedef BadgeEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
    });

class BadgeDashboardData {
  const BadgeDashboardData({
    required this.awarded,
    required this.issued,
    required this.created,
    this.hidden = const [],
  });

  /// Awards addressed to the user that they have not dismissed.
  final List<BadgeAwardViewData> awarded;

  final List<IssuedBadgeViewData> issued;
  final List<CreatedBadgeViewData> created;

  /// Awards the user dismissed on this device.
  ///
  /// Kept alongside [awarded] rather than dropped, so a dismissal made by
  /// accident can be taken back.
  final List<BadgeAwardViewData> hidden;
}

/// The fields of a badge definition the current user is about to publish.
///
/// Creating and editing use the same shape: [identifier] is the `d` tag, so
/// reusing an existing identifier replaces that badge rather than adding one.
class BadgeDefinitionDraft {
  /// Creates a draft definition.
  const BadgeDefinitionDraft({
    required this.identifier,
    required this.name,
    required this.imageUrl,
    this.description = '',
    this.thumbnailUrl = '',
  });

  /// The `d` tag; stable across edits.
  final String identifier;

  /// Display name shown on the badge.
  final String name;

  /// Free-text description of what the badge means.
  final String description;

  /// Badge artwork URL, typically a Blossom blob. Required.
  final String imageUrl;

  /// Optional separate thumbnail URL.
  ///
  /// The mobile editor does not offer a separate thumbnail, but carries the
  /// existing one through an edit so a badge created on the web keeps it.
  final String thumbnailUrl;
}

/// A badge definition authored by the current user, with award totals.
class CreatedBadgeViewData {
  /// Creates created-badge view data.
  const CreatedBadgeViewData({
    required this.definition,
    this.awardCount = 0,
    this.recipientCount = 0,
  });

  final Nip58BadgeDefinition definition;

  /// Number of award events published for this badge.
  final int awardCount;

  /// Number of distinct pubkeys awarded this badge.
  final int recipientCount;

  String get coordinate => definition.coordinate;

  /// Badge name, falling back to the identifier when the definition carries
  /// no `name` tag.
  ///
  /// [Nip58BadgeDefinition.dTag] stays raw on the model because the badge
  /// editor republishes it as the event's `d` tag — rewriting a code unit
  /// there would address a different badge. Sanitizing on the way out keeps
  /// the rendered name well-formed without moving the address, the same split
  /// [_definitionNameFromCoordinate] uses.
  String get displayName => definition.name ?? sanitizeUtf16(definition.dTag);
  String? get imageUrl =>
      definition.imageUrl ??
      (definition.thumbnails.isNotEmpty ? definition.thumbnails.first : null);
}

/// One awardee of a badge, with whether they pinned it to their profile.
class BadgeRecipientViewData {
  /// Creates recipient view data.
  const BadgeRecipientViewData({
    required this.pubkey,
    required this.awardEventId,
    required this.isAccepted,
    this.isViewer = false,
  });

  final String pubkey;

  /// The award event that named this recipient.
  final String awardEventId;

  /// Whether this recipient is the current user.
  ///
  /// Revoking yourself also takes your own pin down, which the confirmation
  /// promises only in that case — for anyone else the pin is their event.
  /// Resolved here so the UI does not have to reach for the signed-in pubkey.
  final bool isViewer;

  /// Whether the recipient's profile badge list references this badge's
  /// coordinate.
  ///
  /// Null when acceptance was not resolved for this recipient, which happens
  /// past the recipient-check limit. Everyone awarded the badge is still
  /// listed; only the status is unknown.
  final bool? isAccepted;
}

/// Everything the badge detail screen renders for one badge coordinate.
class BadgeDetailData {
  /// Creates badge detail data.
  const BadgeDetailData({
    required this.coordinate,
    required this.definition,
    required this.recipients,
    required this.isOwner,
    this.viewerAward,
  });

  final BadgeCoordinate coordinate;

  /// Null when no definition event for [coordinate] could be found.
  final Nip58BadgeDefinition? definition;

  final List<BadgeRecipientViewData> recipients;

  /// Whether the current user issued this badge and may award or edit it.
  final bool isOwner;

  /// The award naming the current user, when they are an awardee.
  final BadgeAwardViewData? viewerAward;
}

class ProfileBadgeViewData {
  const ProfileBadgeViewData({
    required this.badge,
    this.definition,
    this.award,
  });

  final Nip58ProfileBadgeRef badge;
  final Nip58BadgeDefinition? definition;
  final Nip58BadgeAward? award;

  String get awardEventId => badge.awardEventId;
  String get definitionCoordinate => badge.definitionCoordinate;
  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(definitionCoordinate);
  String? get description => definition?.description;
  String? get imageUrl =>
      definition?.imageUrl ??
      (definition?.thumbnails.isNotEmpty == true
          ? definition!.thumbnails.first
          : null);
  String? get issuerPubkey => award?.event.pubkey;
  List<String> get recipientPubkeys => award?.recipientPubkeys ?? const [];
  List<String> get uniqueRecipientPubkeys {
    final seen = <String>{};
    return [
      for (final pubkey in recipientPubkeys)
        if (pubkey.isNotEmpty && seen.add(pubkey)) pubkey,
    ];
  }
}

class BadgeAwardViewData {
  /// A badge delivered by an award event addressed to the user.
  BadgeAwardViewData({
    required Nip58BadgeAward award,
    this.definition,
    this.isAccepted = false,
    this.isHidden = false,
  }) : award = award,
       definitionCoordinate = award.definitionCoordinate,
       awardEventId = award.event.id,
       awardedAt = award.event.createdAt;

  /// A badge pinned to the user's own profile whose award event could not
  /// be found.
  ///
  /// The award is the issuer's event, so it can disappear — a deletion
  /// request, a banned account, a relay that no longer carries it — while
  /// the pin, which is the user's own event, stays. Without this the badge
  /// renders on their profile with no row anywhere to take it down from.
  const BadgeAwardViewData.pinnedWithoutAward({
    required this.definitionCoordinate,
    required this.awardEventId,
    required this.awardedAt,
    this.definition,
  }) : award = null,
       isAccepted = true,
       // A pin cannot be dismissed: hiding the row is what stranded the
       // badge in the first place.
       isHidden = false;

  /// Null when the award event backing this badge could not be found.
  final Nip58BadgeAward? award;

  final Nip58BadgeDefinition? definition;
  final bool isAccepted;
  final bool isHidden;

  /// Address of the badge, which survives the award event going missing.
  final String definitionCoordinate;

  final String awardEventId;

  /// When the badge arrived — the award's timestamp, or the pin's when the
  /// award is gone. Orders the awarded list.
  final int awardedAt;

  /// Whether the award event behind this badge was found.
  ///
  /// False means the only action that makes sense is removing it: it is
  /// already pinned, and dismissing the row would hide it while leaving it
  /// on the profile.
  bool get hasAwardEvent => award != null;

  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(definitionCoordinate);
  String? get imageUrl => definition?.imageUrl;
}

/// One badge the current user has awarded, with everyone who received it.
///
/// Grouped by badge rather than by award event: awarding the same badge to
/// someone a second time is a normal thing to do (their first award may have
/// been dismissed), and listing both would leave a row that can never resolve.
class IssuedBadgeViewData {
  /// Creates issued-badge view data.
  const IssuedBadgeViewData({
    required this.coordinate,
    this.definition,
    this.recipients = const [],
    this.latestAwardedAt = 0,
  });

  /// Address of the awarded badge.
  final String coordinate;

  final Nip58BadgeDefinition? definition;

  /// Every distinct recipient, each against their newest award.
  final List<IssuedBadgeRecipientViewData> recipients;

  /// Timestamp of the newest award for this badge, used for ordering.
  final int latestAwardedAt;

  /// Badge name, falling back to the identifier when no definition loaded.
  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(coordinate);
}

class IssuedBadgeRecipientViewData {
  const IssuedBadgeRecipientViewData({
    required this.pubkey,
    required this.isAccepted,
  });

  final String pubkey;

  /// Null when acceptance was not resolved for this recipient — see
  /// [BadgeRecipientViewData.isAccepted].
  final bool? isAccepted;
}

/// Failure to publish profile badges to at least one relay.
///
/// Carries the relay-level [outcome] for logging and triage.
class BadgePublishException implements Exception {
  const BadgePublishException(
    this.message, {
    required this.outcome,
    this.eventKind,
  });

  final String message;
  final PublishOutcome outcome;

  /// The kind of event whose publish failed, when known.
  final int? eventKind;

  @override
  String toString() => 'BadgePublishException: $message';
}

class BadgeRepository {
  BadgeRepository({
    required NostrClient nostrClient,
    required SharedPreferences sharedPreferences,
    required BadgeCurrentPubkeyReader currentPubkey,
    required BadgeEventSigner signEvent,
    BadgeHiddenPubkeyReader? isHiddenPubkey,
    String? definitionRelayUrl,
  }) : _nostrClient = nostrClient,
       _sharedPreferences = sharedPreferences,
       _currentPubkey = currentPubkey,
       _signEvent = signEvent,
       _isHiddenPubkey = isHiddenPubkey,
       _definitionRelayUrl = definitionRelayUrl;

  final NostrClient _nostrClient;
  final SharedPreferences _sharedPreferences;
  final BadgeCurrentPubkeyReader _currentPubkey;
  final BadgeEventSigner _signEvent;

  /// Null leaves awards unfiltered, which is what an anonymous or test
  /// repository wants — there is no blocklist to consult.
  final BadgeHiddenPubkeyReader? _isHiddenPubkey;

  /// Relay used for public definitions when no account has initialized relays.
  final String? _definitionRelayUrl;

  /// The profile badge list this repository last published, and whose it is.
  ///
  /// `kind:10008` is replaceable, and [NostrClient] deliberately does not
  /// optimistically cache replaceable events — a stale copy would shadow the
  /// real newest one. That leaves a window right after publishing where the
  /// relay has acknowledged the event but does not serve it yet, so a reload
  /// reads back the *previous* list and an accepted badge still renders as
  /// unaccepted until the user refreshes by hand.
  ///
  /// Holding the published list here closes that window. It is not a cache
  /// with a lifetime: a relay event that is genuinely newer still wins, so it
  /// stops mattering as soon as the relay catches up.
  ({String pubkey, Nip58ProfileBadges badges})? _publishedProfileBadges;

  /// Badge definitions this repository published, keyed by coordinate.
  ///
  /// Same window as [_publishedProfileBadges], for the same reason:
  /// `kind:30009` is parameterized-replaceable, so it is not optimistically
  /// cached either, and an edit would read the previous definition straight
  /// back — the badge would keep its old name until a manual refresh.
  final Map<String, Nip58BadgeDefinition> _publishedDefinitions = {};

  /// A just-published subscription event may take a moment to appear in relay
  /// queries. Keep it until the relay supplies the same or a newer event.
  Event? _publishedSubscriptions;
  final StreamController<void> _subscriptionChanges =
      StreamController<void>.broadcast();

  static const _subscriptionsIdentifier = 'divine.badge_subscriptions';

  /// Definitions from the issuers selected for Explore.
  Future<List<Nip58BadgeDefinition>> loadDefinitionsByIssuers(
    Iterable<String> issuerPubkeys,
  ) async {
    final definitions = <String, Nip58BadgeDefinition>{};
    for (final issuer in issuerPubkeys.toSet()) {
      if (!isBadgePubkey(issuer)) continue;
      final result = await _nostrClient.readAllEvents(
        Filter(authors: [issuer], kinds: [EventKind.badgeDefinition]),
        tempRelays: _definitionRelayUrl == null ? null : [_definitionRelayUrl],
      );
      if (!result.isComplete) {
        throw StateError('Badge definitions could not be fully loaded');
      }
      // The relay filters on authors; only the issuer's own signature counts.
      final signed = result.events
          .where((event) => event.pubkey == issuer)
          .toList();
      for (final definition in _newestDefinitionPerIdentifier(signed)) {
        definitions[definition.coordinate] = definition;
      }
    }
    return definitions.values.toList(growable: false)
      ..sort((a, b) => (a.name ?? a.dTag).compareTo(b.name ?? b.dTag));
  }

  /// Every currently accepted holder with an issuer-signed award.
  ///
  /// An incomplete relay walk is an error: returning the partial set would
  /// misrepresent a large badge as having no further holders.
  Future<Set<String>> loadAcceptedHolders(BadgeCoordinate coordinate) async {
    final awardsPage = await _nostrClient.readAllEvents(
      Filter(
        authors: [coordinate.pubkey],
        kinds: [EventKind.badgeAward],
        a: [coordinate.value],
      ),
    );
    if (!awardsPage.isComplete) {
      throw StateError('Badge holders could not be fully loaded');
    }
    final awardIds = awardsPage.events.map((event) => event.id).toList();
    final revokedIds = <String>{};
    for (var i = 0; i < awardIds.length; i += 100) {
      final deletions = await _nostrClient.readAllEvents(
        Filter(
          authors: [coordinate.pubkey],
          kinds: [EventKind.eventDeletion],
          e: awardIds.skip(i).take(100).toList(),
        ),
      );
      if (!deletions.isComplete) {
        throw StateError('Badge revocations could not be fully loaded');
      }
      // NIP-09 honors a deletion only from the original author.
      for (final deletion in deletions.events) {
        if (deletion.pubkey != coordinate.pubkey) continue;
        for (final tag in deletion.tags) {
          if (tag.length >= 2 && tag[0] == 'e') revokedIds.add(tag[1]);
        }
      }
    }
    final awarded = <String>{};
    for (final event in awardsPage.events) {
      // An award counts only when the badge's own issuer signed it.
      if (event.pubkey != coordinate.pubkey) continue;
      if (revokedIds.contains(event.id)) continue;
      final award = Nip58BadgeParser.parseAward(event);
      if (award?.definitionCoordinate == coordinate.value) {
        awarded.addAll(award!.recipientPubkeys);
      }
    }
    // Blocked, muted and platform-blocklisted accounts stay out of the public
    // holder list and of subscribers' Following, as in other user lists.
    final isHiddenPubkey = _isHiddenPubkey;
    if (isHiddenPubkey != null) awarded.removeWhere(isHiddenPubkey);
    if (awarded.isEmpty) return const {};
    final profiles = await _completeProfileBadgesByPubkeyChunked(awarded);
    return Set.unmodifiable({
      for (final entry in profiles.entries)
        if (_containsBadgeCoordinateValue(entry.value, coordinate.value))
          entry.key,
    });
  }

  /// [pubkeys] without the accounts this viewer hides, in their given order.
  ///
  /// Applies the same filter as [loadAcceptedHolders], for holder sets that
  /// come from somewhere other than a relay walk.
  List<String> withoutHiddenPubkeys(Iterable<String> pubkeys) {
    final isHiddenPubkey = _isHiddenPubkey;
    return [
      for (final pubkey in pubkeys)
        if (isHiddenPubkey == null || !isHiddenPubkey(pubkey)) pubkey,
    ];
  }

  /// Every accepted holder of the badges the current account subscribes to.
  ///
  /// Empty when signed out or subscribed to nothing. Throws when the
  /// subscription list or a holder set cannot be fully loaded.
  Future<Set<String>> loadSubscribedHolders() async {
    final pubkey = _currentPubkey();
    if (pubkey == null || pubkey.isEmpty) return const {};
    // A timed-out read must throw, not read as "subscribed to nothing", so
    // Following falls back with a warning instead of quietly losing badges.
    final subscriptions = await loadSubscriptions(requireComplete: true);
    final holderSets = await Future.wait(
      subscriptions.map(loadAcceptedHolders),
    );
    return Set.unmodifiable({for (final holders in holderSets) ...holders});
  }

  /// Public, account-synced badge subscriptions stored in a NIP-78 event.
  Future<Set<BadgeCoordinate>> loadSubscriptions({
    bool requireComplete = false,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final filters = [
      Filter(
        authors: [pubkey],
        kinds: [EventKind.appSpecificData],
        d: [_subscriptionsIdentifier],
        limit: 10,
      ),
    ];
    final List<Event> events;
    if (requireComplete) {
      final result = await _nostrClient.queryEventsDetailed(
        filters,
        requireAllRelaysSettled: true,
      );
      if (result.timedOut || result.noRelays) {
        throw StateError('Badge subscriptions could not be fully loaded');
      }
      events = result.events;
    } else {
      events = await _nostrClient.queryEvents(filters);
    }
    final matching =
        events
            .where(
              (event) =>
                  event.pubkey == pubkey &&
                  event.tags.any(
                    (tag) =>
                        tag.length >= 2 &&
                        tag[0] == 'd' &&
                        tag[1] == _subscriptionsIdentifier,
                  ),
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    final published = _publishedSubscriptions;
    final latest = matching.isEmpty ? null : matching.first;
    final event =
        published != null &&
            published.pubkey == pubkey &&
            (latest == null ||
                published.createdAt > latest.createdAt ||
                (published.createdAt == latest.createdAt &&
                    published.id.compareTo(latest.id) < 0))
        ? published
        : latest;
    if (event == null) return const {};
    final coordinates = <BadgeCoordinate>{};
    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'a') continue;
      final coordinate = BadgeCoordinate.parse(tag[1]);
      if (coordinate != null) coordinates.add(coordinate);
    }
    return Set.unmodifiable(coordinates);
  }

  /// Add or remove one badge subscription without following its holders.
  Future<Set<BadgeCoordinate>> setSubscription(
    BadgeCoordinate coordinate, {
    required bool subscribed,
  }) async {
    final current = {...await loadSubscriptions(requireComplete: true)};
    if (subscribed) {
      current.add(coordinate);
    } else {
      current.remove(coordinate);
    }
    final tags = [
      ['d', _subscriptionsIdentifier],
      for (final item
          in current.toList()..sort((a, b) => a.value.compareTo(b.value)))
        ['a', item.value],
    ];
    _publishedSubscriptions = await _signAndPublish(
      kind: EventKind.appSpecificData,
      label: 'badge subscriptions',
      tags: tags,
    );
    _subscriptionChanges.add(null);
    return Set.unmodifiable(current);
  }

  /// Emits after this account saves a badge subscription change, so Following
  /// can reload its merged authors without rebuilding other feeds.
  Stream<void> get subscriptionChanges => _subscriptionChanges.stream;

  /// Closes [subscriptionChanges].
  Future<void> dispose() => _subscriptionChanges.close();

  Future<BadgeDashboardData> loadDashboard() async {
    final memo = _DashboardLookupMemo();
    final awardedFuture = _loadAwardedBadges(memo);
    final issuedFuture = _loadIssuedBadges(memo);
    final createdFuture = _loadCreatedBadges(memo);
    await Future.wait<void>([awardedFuture, issuedFuture, createdFuture]);
    final awarded = await awardedFuture;
    return BadgeDashboardData(
      awarded: [
        for (final award in awarded)
          if (!award.isHidden) award,
      ],
      hidden: [
        for (final award in awarded)
          if (award.isHidden) award,
      ],
      issued: await issuedFuture,
      created: await createdFuture,
    );
  }

  /// Every award addressed to the current user, dismissed ones included.
  ///
  /// Dismissed awards come back with [BadgeAwardViewData.isHidden] set rather
  /// than being dropped — the dashboard needs them to offer a way back.
  Future<List<BadgeAwardViewData>> loadAwardedBadges() =>
      _loadAwardedBadges(_DashboardLookupMemo());

  Future<List<BadgeAwardViewData>> _loadAwardedBadges(
    _DashboardLookupMemo memo,
  ) async {
    final pubkey = _requireCurrentPubkey();
    final awardsFuture = _queryAwardsForRecipient(pubkey);
    final profileBadgesFuture = memo.profileBadges(
      pubkey,
      () => _latestProfileBadges(pubkey),
    );
    // Future.wait (not sequential awaits) so a failure in one query cannot
    // leave the other as an unawaited error.
    final results = await Future.wait<Object?>([
      awardsFuture,
      profileBadgesFuture,
    ]);
    final awards = results[0]! as List<Nip58BadgeAward>;
    final profileBadges = results[1] as Nip58ProfileBadges?;

    // Newest award per badge, the same rule the issued list uses: being
    // awarded a badge twice is normal, and listing both leaves one row that
    // can never resolve.
    final newestPerCoordinate = <String, Nip58BadgeAward>{};
    for (final award in awards) {
      final existing = newestPerCoordinate[award.definitionCoordinate];
      if (existing == null ||
          award.event.createdAt > existing.event.createdAt) {
        newestPerCoordinate[award.definitionCoordinate] = award;
      }
    }

    final pinnedWithoutAward = _pinnedWithoutAward(
      profileBadges,
      newestPerCoordinate.keys.toSet(),
    );

    final dismissedCoordinates = await _dismissedCoordinates(pubkey, awards);
    final definitions = await _definitionsByCoordinate(memo, [
      for (final award in awards) award.definitionCoordinate,
      for (final ref in pinnedWithoutAward) ref.definitionCoordinate,
    ]);

    final isHiddenPubkey = _isHiddenPubkey;
    final viewData = <BadgeAwardViewData>[];
    for (final award in newestPerCoordinate.values) {
      final isAccepted = _containsBadgeCoordinate(profileBadges, award);
      // An award lands on you without your consent, so an account you
      // blocked can keep handing you badges. Dropping them is what makes
      // blocking the account the answer to unwanted badges, instead of
      // dismissing each one by hand forever. An accepted award stays: it is
      // pinned to the user's own profile, and hiding the row would strand it
      // there with no way to take it down.
      if (!isAccepted && (isHiddenPubkey?.call(award.event.pubkey) ?? false)) {
        continue;
      }
      viewData.add(
        BadgeAwardViewData(
          award: award,
          definition: definitions[award.definitionCoordinate],
          isAccepted: isAccepted,
          // A pinned badge is never hidden, the same rule
          // [BadgeAwardViewData.pinnedWithoutAward] hardcodes: the hidden
          // section only offers a way back, so hiding a pinned badge leaves
          // it on the profile with no row that can take it down. Rejecting
          // unpins first, so this only bites on a dismissal made before it
          // did — a legacy per-award one migrating onto a badge accepted
          // since, or one carried over from another device.
          isHidden:
              !isAccepted &&
              dismissedCoordinates.contains(award.definitionCoordinate),
        ),
      );
    }
    for (final ref in pinnedWithoutAward) {
      viewData.add(
        BadgeAwardViewData.pinnedWithoutAward(
          definitionCoordinate: ref.definitionCoordinate,
          awardEventId: ref.awardEventId,
          // The pin is the only event left to date this by.
          awardedAt: profileBadges?.event.createdAt ?? 0,
          definition: definitions[ref.definitionCoordinate],
        ),
      );
    }

    viewData.sort((left, right) {
      final byRecency = right.awardedAt.compareTo(left.awardedAt);
      if (byRecency != 0) return byRecency;
      // Pinned-without-award rows all carry the profile list's timestamp,
      // so tie-break on the coordinate to keep the order stable across
      // loads rather than leaving equal timestamps to a non-stable sort.
      return left.definitionCoordinate.compareTo(right.definitionCoordinate);
    });
    return List<BadgeAwardViewData>.unmodifiable(viewData);
  }

  /// The badges pinned to [profileBadges] that no award in
  /// [coordinatesWithAward] backs.
  ///
  /// Deduplicated by coordinate: the list is another client's event and can
  /// name the same badge twice, which would render two rows that both
  /// remove the same pin.
  static List<Nip58ProfileBadgeRef> _pinnedWithoutAward(
    Nip58ProfileBadges? profileBadges,
    Set<String> coordinatesWithAward,
  ) {
    final seen = <String>{};
    return [
      for (final ref in profileBadges?.badges ?? const <Nip58ProfileBadgeRef>[])
        if (ref.definitionCoordinate.isNotEmpty &&
            !coordinatesWithAward.contains(ref.definitionCoordinate) &&
            seen.add(ref.definitionCoordinate))
          ref,
    ];
  }

  Future<List<ProfileBadgeViewData>> loadAcceptedBadgesForProfile(
    String pubkey,
  ) async {
    if (pubkey.isEmpty) return const [];

    final profileBadges = await _latestProfileBadges(pubkey);
    final refs = profileBadges?.badges ?? const <Nip58ProfileBadgeRef>[];
    if (refs.isEmpty) return const [];

    final viewData = await Future.wait(
      refs.map((ref) async {
        final definitionFuture = _loadDefinition(ref.definitionCoordinate);
        final awardFuture = _loadAward(ref.awardEventId);

        return ProfileBadgeViewData(
          badge: ref,
          definition: await definitionFuture,
          award: await awardFuture,
        );
      }),
    );

    // A profile badge list is its owner's event, so it can reference an award
    // nobody but its own publisher stands behind. When the award event is
    // available, render only awards the badge's issuer actually signed. Missing
    // award events are kept because they may be unavailable on the queried
    // relay while still existing elsewhere.
    return List<ProfileBadgeViewData>.unmodifiable([
      for (final badge in viewData)
        if (badge.award == null || _isIssuedByBadgeOwner(badge.award!)) badge,
    ]);
  }

  Future<List<IssuedBadgeViewData>> loadIssuedBadges({
    int recipientCheckLimit = 50,
  }) => _loadIssuedBadges(
    _DashboardLookupMemo(),
    recipientCheckLimit: recipientCheckLimit,
  );

  Future<List<IssuedBadgeViewData>> _loadIssuedBadges(
    _DashboardLookupMemo memo, {
    int recipientCheckLimit = 50,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final awards = await memo.issuedAwards(
      pubkey,
      () => _queryAwardsByAuthor(pubkey),
    );

    // Newest award per (badge, recipient): a re-award supersedes the earlier
    // one rather than adding a second, permanently pending row. Everyone
    // named is kept — the limit below bounds relay lookups, not the list.
    final awardByBadgeAndRecipient = <String, Map<String, Nip58BadgeAward>>{};
    final latestAwardedAt = <String, int>{};
    for (final award in awards) {
      final byRecipient = awardByBadgeAndRecipient.putIfAbsent(
        award.definitionCoordinate,
        () => {},
      );
      latestAwardedAt.update(
        award.definitionCoordinate,
        (current) =>
            current > award.event.createdAt ? current : award.event.createdAt,
        ifAbsent: () => award.event.createdAt,
      );
      for (final recipient in award.recipientPubkeys) {
        final existing = byRecipient[recipient];
        if (existing == null ||
            award.event.createdAt > existing.event.createdAt) {
          byRecipient[recipient] = award;
        }
      }
    }

    final checked = <String>{
      for (final byRecipient in awardByBadgeAndRecipient.values)
        ...byRecipient.keys.take(recipientCheckLimit),
    };

    final results = await Future.wait<Object?>([
      _definitionsByCoordinate(memo, [
        for (final award in awards) award.definitionCoordinate,
      ]),
      _profileBadgesByPubkey(memo, checked),
    ]);
    final definitions = results[0]! as Map<String, Nip58BadgeDefinition?>;
    final profileBadges = results[1]! as Map<String, Nip58ProfileBadges?>;

    final issued =
        [
          for (final entry in awardByBadgeAndRecipient.entries)
            IssuedBadgeViewData(
              coordinate: entry.key,
              definition: definitions[entry.key],
              latestAwardedAt: latestAwardedAt[entry.key]!,
              recipients: List<IssuedBadgeRecipientViewData>.unmodifiable([
                for (final recipient in entry.value.entries)
                  IssuedBadgeRecipientViewData(
                    pubkey: recipient.key,
                    isAccepted: checked.contains(recipient.key)
                        ? _containsBadgeCoordinate(
                            profileBadges[recipient.key],
                            recipient.value,
                          )
                        : null,
                  ),
              ]),
            ),
        ]..sort(
          (left, right) =>
              right.latestAwardedAt.compareTo(left.latestAwardedAt),
        );
    return List<IssuedBadgeViewData>.unmodifiable(issued);
  }

  /// Loads the badge definitions authored by the current user.
  ///
  /// Definitions are addressable, so only the newest event per identifier is
  /// returned, newest first. Award totals count every award the user
  /// published for each definition.
  ///
  /// Throws [StateError] if there is no current pubkey.
  Future<List<CreatedBadgeViewData>> loadCreatedBadges({int limit = 100}) =>
      _loadCreatedBadges(_DashboardLookupMemo(), limit: limit);

  Future<List<CreatedBadgeViewData>> _loadCreatedBadges(
    _DashboardLookupMemo memo, {
    int limit = 100,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final results = await Future.wait<Object?>([
      _ownDefinitions(pubkey, limit: limit),
      memo.issuedAwards(pubkey, () => _queryAwardsByAuthor(pubkey)),
    ]);
    final definitions = results[0]! as List<Nip58BadgeDefinition>;
    final awards = results[1]! as List<Nip58BadgeAward>;

    final awardsByCoordinate = <String, List<Nip58BadgeAward>>{};
    for (final award in awards) {
      awardsByCoordinate
          .putIfAbsent(award.definitionCoordinate, () => [])
          .add(award);
    }

    final created =
        [
          for (final definition in definitions)
            CreatedBadgeViewData(
              definition: definition,
              awardCount:
                  awardsByCoordinate[definition.coordinate]?.length ?? 0,
              recipientCount: <String>{
                for (final award
                    in awardsByCoordinate[definition.coordinate] ??
                        const <Nip58BadgeAward>[])
                  ...award.recipientPubkeys,
              }.length,
            ),
        ]..sort(
          (left, right) => right.definition.event.createdAt.compareTo(
            left.definition.event.createdAt,
          ),
        );
    return List<CreatedBadgeViewData>.unmodifiable(created);
  }

  /// Loads one badge's definition, its awardees, and the viewer's relation
  /// to it.
  ///
  /// Only awards published by the badge's own issuer count, so a third party
  /// cannot inject awardees into someone else's badge. Every awardee is
  /// listed; when more than [recipientCheckLimit] people hold the badge,
  /// acceptance is resolved for that many and left null for the rest, so a
  /// long list costs a bounded number of relay lookups. The viewer's own
  /// status is always resolved.
  Future<BadgeDetailData> loadBadgeDetail(
    BadgeCoordinate coordinate, {
    int recipientCheckLimit = 50,
  }) async {
    final viewerPubkey = _currentPubkey();
    final memo = _DashboardLookupMemo();
    final results = await Future.wait<Object?>([
      memo.definition(
        coordinate.value,
        () => _loadDefinition(coordinate.value),
      ),
      _queryAwardsForCoordinate(coordinate),
    ]);
    final definition = results[0] as Nip58BadgeDefinition?;
    final awards = results[1]! as List<Nip58BadgeAward>;

    // A recipient can be named by more than one award event; the profile
    // badge list references exactly one, so the newest award wins.
    final awardByRecipient = <String, Nip58BadgeAward>{};
    for (final award in awards) {
      for (final recipient in award.recipientPubkeys) {
        final existing = awardByRecipient[recipient];
        if (existing == null ||
            award.event.createdAt > existing.event.createdAt) {
          awardByRecipient[recipient] = award;
        }
      }
    }

    final checked = <String>{
      ...awardByRecipient.keys.take(recipientCheckLimit),
      if (viewerPubkey != null && awardByRecipient.containsKey(viewerPubkey))
        viewerPubkey,
    };
    final profileBadges = await _profileBadgesByPubkey(memo, checked);

    final recipients = [
      for (final entry in awardByRecipient.entries)
        BadgeRecipientViewData(
          pubkey: entry.key,
          awardEventId: entry.value.event.id,
          isAccepted: checked.contains(entry.key)
              ? _containsBadgeCoordinate(profileBadges[entry.key], entry.value)
              : null,
          isViewer: entry.key == viewerPubkey,
        ),
    ];

    final viewerAward = viewerPubkey == null
        ? null
        : awardByRecipient[viewerPubkey];
    return BadgeDetailData(
      coordinate: coordinate,
      definition: definition,
      recipients: List<BadgeRecipientViewData>.unmodifiable(recipients),
      isOwner: viewerPubkey != null && viewerPubkey == coordinate.pubkey,
      viewerAward: viewerAward == null
          ? null
          : BadgeAwardViewData(
              award: viewerAward,
              definition: definition,
              isAccepted: _containsBadgeCoordinate(
                profileBadges[viewerPubkey],
                viewerAward,
              ),
            ),
    );
  }

  /// Loads pubkeys whose latest profile-badge list claims [coordinate].
  ///
  /// NIP-58 profile badges are currently published as kind 10008 and, for
  /// older clients, legacy kind 30008 with `d=profile_badges`. The initial
  /// reverse `#a` query finds candidate claimants without walking every award
  /// recipient; each candidate is then checked against their latest profile
  /// badge list so an older claim does not survive after a newer removal.
  Future<Set<String>> loadClaimantPubkeys(BadgeCoordinate coordinate) async {
    final viewerPubkey = _currentPubkey();
    final candidateEvents = await _queryProfileBadgeClaimsForCoordinate(
      coordinate,
    );
    final candidatePubkeys = {
      for (final event in candidateEvents)
        if (event.pubkey != viewerPubkey) event.pubkey,
    };
    if (candidatePubkeys.isEmpty) return const {};

    final memo = _DashboardLookupMemo();
    final latestByPubkey = await _profileBadgesByPubkeyChunked(
      memo,
      candidatePubkeys,
    );

    return Set.unmodifiable({
      for (final entry in latestByPubkey.entries)
        if (_containsBadgeCoordinateValue(entry.value, coordinate.value))
          entry.key,
    });
  }

  /// Publishes a badge definition (`kind:30009`) authored by the current user.
  ///
  /// Badge definitions are addressable, so publishing a draft whose
  /// identifier already exists edits that badge in place instead of adding a
  /// second one.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if the draft has no identifier, no name, or no
  ///   artwork.
  /// * [StateError] if there is no current pubkey or the event cannot be
  ///   signed into a valid definition.
  /// * [BadgePublishException] when no relay accepts the definition.
  Future<Nip58BadgeDefinition> saveDefinition(
    BadgeDefinitionDraft draft,
  ) async {
    _requireCurrentPubkey();

    final identifier = draft.identifier.trim();
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        draft.identifier,
        'identifier',
        'Badge identifier must not be empty',
      );
    }
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        draft.name,
        'name',
        'Badge name must not be empty',
      );
    }

    final imageUrl = draft.imageUrl.trim();
    if (imageUrl.isEmpty) {
      throw ArgumentError.value(
        draft.imageUrl,
        'imageUrl',
        'Badge artwork must not be empty',
      );
    }

    final description = draft.description.trim();
    final thumbnailUrl = draft.thumbnailUrl.trim();
    final event = await _signAndPublish(
      kind: EventKind.badgeDefinition,
      label: 'badge definition',
      tags: [
        ['d', identifier],
        ['name', name],
        // Omitted rather than written empty: an empty tag parses back as ''
        // rather than null, which reads as "has a description" downstream.
        if (description.isNotEmpty) ['description', description],
        ['image', imageUrl],
        if (thumbnailUrl.isNotEmpty) ['thumb', thumbnailUrl],
      ],
    );

    final definition = Nip58BadgeParser.parseDefinition(event);
    if (definition == null) {
      throw StateError('Signed badge definition event is not parseable');
    }
    _publishedDefinitions[definition.coordinate] = definition;
    return definition;
  }

  /// Awards the badge at [coordinate] to [recipientPubkeys] (`kind:8`).
  ///
  /// Duplicate and malformed pubkeys are dropped before publishing.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if no valid recipient remains.
  /// * [StateError] if there is no current pubkey, the badge belongs to
  ///   someone else, or the event cannot be signed into a valid award.
  /// * [BadgePublishException] when no relay accepts the award.
  Future<Nip58BadgeAward> awardBadge({
    required BadgeCoordinate coordinate,
    required List<String> recipientPubkeys,
  }) async {
    final pubkey = _requireCurrentPubkey();
    // Readers resolve awards through the badge's own issuer, so an award
    // signed by anyone else is an event nothing will ever honour.
    if (coordinate.pubkey != pubkey) {
      throw StateError('Cannot award a badge issued by someone else');
    }

    final recipients = <String>{
      for (final recipientPubkey in recipientPubkeys)
        if (isBadgePubkey(recipientPubkey)) recipientPubkey,
    }.toList(growable: false);
    if (recipients.isEmpty) {
      throw ArgumentError.value(
        recipientPubkeys,
        'recipientPubkeys',
        'Badge award needs at least one valid recipient',
      );
    }

    final event = await _signAndPublish(
      kind: EventKind.badgeAward,
      label: 'badge award',
      tags: [
        ['a', coordinate.value],
        for (final recipient in recipients) ['p', recipient],
      ],
    );

    final award = Nip58BadgeParser.parseAward(event);
    if (award == null) {
      throw StateError('Signed badge award event is not parseable');
    }
    return award;
  }

  /// Takes the badge at [coordinate] back from [recipientPubkey], leaving
  /// every other holder untouched.
  ///
  /// Every award naming them is revoked, not just their newest: the recipient
  /// list resolves someone through their newest award, so an older one left
  /// behind puts them straight back on it.
  ///
  /// NIP-58 has no per-recipient revoke and NIP-09 deletes whole events, so
  /// an award that also names other people is replaced rather than merely
  /// deleted — a fresh award for the remaining recipients goes out first, and
  /// only then does the deletion request. That order matters: a refused
  /// deletion strips the badge off nobody, where the reverse order would take
  /// it off the bystanders too.
  ///
  /// Acceptance is coordinate-based, so replacing a shared award does not
  /// require the remaining recipients to accept the badge again. Nobody is
  /// notified: a `kind:5` from the issuer reaches no notification path.
  ///
  /// Publishes no award or deletion when nothing names [recipientPubkey],
  /// but still takes down the current user's own pin.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if [recipientPubkey] is not a hex pubkey.
  /// * [StateError] if there is no current pubkey, the badge belongs to
  ///   someone else, or an event cannot be signed.
  /// * [BadgePublishException] when no relay accepts one of the events.
  Future<void> revokeAward({
    required BadgeCoordinate coordinate,
    required String recipientPubkey,
  }) async {
    final pubkey = _requireCurrentPubkey();
    if (coordinate.pubkey != pubkey) {
      throw StateError('Cannot revoke a badge issued by someone else');
    }
    if (!isBadgePubkey(recipientPubkey)) {
      throw ArgumentError.value(
        recipientPubkey,
        'recipientPubkey',
        'Badge recipient must be a hex pubkey',
      );
    }

    final awards = await _queryAwardsForCoordinate(coordinate);
    final revoked = [
      for (final award in awards)
        if (award.recipientPubkeys.contains(recipientPubkey)) award,
    ];

    if (revoked.isNotEmpty) {
      final remaining = <String>{
        for (final award in revoked)
          for (final recipient in award.recipientPubkeys)
            if (recipient != recipientPubkey && isBadgePubkey(recipient))
              recipient,
      }.toList(growable: false);
      final hasReplacement = awards.any((award) {
        final recipients = {
          for (final recipient in award.recipientPubkeys)
            if (isBadgePubkey(recipient)) recipient,
        };
        // A deletion retry can read the replacement published by its first
        // attempt alongside the still-present original. Reuse that award
        // instead of minting another identical event on every retry.
        return recipients.length == remaining.length &&
            recipients.containsAll(remaining);
      });
      if (remaining.isNotEmpty && !hasReplacement) {
        await awardBadge(coordinate: coordinate, recipientPubkeys: remaining);
      }

      // No `a` tag here, unlike [deleteBadge]: that one addresses the
      // definition, and a revoke must leave the badge itself standing.
      await _signAndPublish(
        kind: EventKind.eventDeletion,
        label: 'badge award revocation',
        tags: [
          for (final award in revoked) ['e', award.event.id],
          ['k', '${EventKind.badgeAward}'],
        ],
      );
    }

    // Taking a badge back from yourself is the one case where the pin is
    // ours to take down too. For anyone else the profile badge list is their
    // event and can only be asked about; leaving your own behind shows the
    // badge on your profile with the award already gone. Outside the block
    // above so a retry still reaches it once the awards are already deleted.
    if (recipientPubkey == pubkey) {
      await _unpinCoordinate(coordinate.value);
    }
  }

  /// Requests deletion of the badge at [coordinate] and every award the
  /// current user issued for it.
  ///
  /// Publishes one NIP-09 deletion request (`kind:5`) naming the addressable
  /// definition plus each award event, because an award that outlives its
  /// definition renders as a nameless badge. Two caveats the UI must be
  /// honest about: relays are free to ignore a deletion request, and a
  /// recipient's profile badge list is *their* event — an accepted badge can
  /// keep showing on their profile until they remove it.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey, the badge belongs to
  ///   someone else, or the request cannot be signed.
  /// * [BadgePublishException] when no relay accepts the request.
  Future<void> deleteBadge(BadgeCoordinate coordinate) async {
    final pubkey = _requireCurrentPubkey();
    if (coordinate.pubkey != pubkey) {
      throw StateError('Cannot delete a badge issued by someone else');
    }

    final memo = _DashboardLookupMemo();
    final results = await Future.wait<Object?>([
      memo.definition(
        coordinate.value,
        () => _loadDefinition(coordinate.value),
      ),
      _queryAwardsForCoordinate(coordinate),
    ]);
    final definition = results[0] as Nip58BadgeDefinition?;
    final awards = results[1]! as List<Nip58BadgeAward>;

    await _signAndPublish(
      kind: EventKind.eventDeletion,
      label: 'badge deletion',
      tags: [
        ['a', coordinate.value],
        if (definition != null) ['e', definition.event.id],
        for (final award in awards) ['e', award.event.id],
        ['k', '${EventKind.badgeDefinition}'],
        if (awards.isNotEmpty) ['k', '${EventKind.badgeAward}'],
      ],
    );

    // Only once the request is out: a relay can refuse a deletion, and
    // dropping the badge here first would make a freshly created badge — the
    // case a relay is most likely to refuse — vanish from the dashboard while
    // it still exists and the relay is not serving it yet.
    _publishedDefinitions.remove(coordinate.value);
  }

  /// The `d` identifiers of every badge the current user has published.
  ///
  /// Badge definitions are addressable, so publishing a new one under an
  /// identifier that is already in use replaces that badge rather than adding
  /// a second — including for everyone already holding an award for it. The
  /// editor uses this to refuse that by accident.
  ///
  /// Throws [StateError] if there is no current pubkey.
  Future<Set<String>> loadCreatedIdentifiers({int limit = 100}) async {
    final pubkey = _requireCurrentPubkey();
    return {
      for (final definition in await _ownDefinitions(pubkey, limit: limit))
        definition.dTag,
    };
  }

  Future<List<Event>> _queryDefinitionsByAuthor(
    String pubkey, {
    int limit = 100,
  }) {
    return _nostrClient.queryEvents([
      Filter(
        authors: [pubkey],
        kinds: [EventKind.badgeDefinition],
        limit: limit,
      ),
    ]);
  }

  Future<List<Nip58BadgeAward>> _queryAwardsByAuthor(
    String pubkey, {
    int limit = 100,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: [EventKind.badgeAward], limit: limit),
    ]);
    return events
        .map(Nip58BadgeParser.parseAward)
        .whereType<Nip58BadgeAward>()
        .toList(growable: false);
  }

  Future<List<Nip58BadgeAward>> _queryAwardsForCoordinate(
    BadgeCoordinate coordinate, {
    int limit = 200,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [coordinate.pubkey],
        kinds: [EventKind.badgeAward],
        a: [coordinate.value],
        limit: limit,
      ),
    ]);

    final awards =
        events
            .map(Nip58BadgeParser.parseAward)
            .whereType<Nip58BadgeAward>()
            .where((award) => award.definitionCoordinate == coordinate.value)
            .toList()
          ..sort(
            (left, right) =>
                right.event.createdAt.compareTo(left.event.createdAt),
          );
    return awards;
  }

  Future<List<Event>> _queryProfileBadgeClaimsForCoordinate(
    BadgeCoordinate coordinate, {
    int limit = _claimantCandidateEventLimit,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: [EventKind.profileBadges, EventKind.badgeSet],
        a: [coordinate.value],
        limit: limit,
      ),
    ]);

    return events
        .where(Nip58BadgeParser.isProfileBadgesEvent)
        .where(
          (event) =>
              Nip58BadgeParser.parseProfileBadges(event)?.badges.any(
                (ref) => ref.definitionCoordinate == coordinate.value,
              ) ??
              false,
        )
        .toList(growable: false);
  }

  static List<Nip58BadgeDefinition> _newestDefinitionPerIdentifier(
    List<Event> events,
  ) {
    final byIdentifier = <String, Nip58BadgeDefinition>{};
    for (final event in events) {
      final definition = Nip58BadgeParser.parseDefinition(event);
      if (definition == null) continue;
      final existing = byIdentifier[definition.dTag];
      if (existing == null ||
          definition.event.createdAt > existing.event.createdAt) {
        byIdentifier[definition.dTag] = definition;
      }
    }
    return byIdentifier.values.toList(growable: false);
  }

  Future<Map<String, Nip58BadgeDefinition?>> _definitionsByCoordinate(
    _DashboardLookupMemo memo,
    Iterable<String> coordinates,
  ) async {
    final unique = coordinates.toSet().toList(growable: false);
    final loaded = await Future.wait([
      for (final coordinate in unique)
        memo.definition(coordinate, () => _loadDefinition(coordinate)),
    ]);
    return {for (var i = 0; i < unique.length; i++) unique[i]: loaded[i]};
  }

  Future<Map<String, Nip58ProfileBadges?>> _profileBadgesByPubkeyChunked(
    _DashboardLookupMemo memo,
    Iterable<String> pubkeys,
  ) async {
    final unique = pubkeys.toSet().toList(growable: false);
    final result = <String, Nip58ProfileBadges?>{};
    for (
      var start = 0;
      start < unique.length;
      start += _claimantProfileAuthorChunkSize
    ) {
      final chunkEnd = start + _claimantProfileAuthorChunkSize;
      final end = chunkEnd > unique.length ? unique.length : chunkEnd;
      final chunk = unique.sublist(start, end);
      final badgesByPubkey = await memo.profileBadgeChunk(
        chunk,
        () => _latestProfileBadgesForAuthors(chunk),
      );
      for (final pubkey in chunk) {
        result[pubkey] = badgesByPubkey[pubkey];
      }
    }
    return result;
  }

  Future<Map<String, Nip58ProfileBadges?>>
  _completeProfileBadgesByPubkeyChunked(Iterable<String> pubkeys) async {
    final unique = pubkeys.toSet().toList(growable: false);
    final profiles = <String, Nip58ProfileBadges?>{};
    for (var start = 0; start < unique.length; start += 100) {
      final chunk = unique.skip(start).take(100).toList(growable: false);
      final current = await _nostrClient.readAllEvents(
        Filter(authors: chunk, kinds: [EventKind.profileBadges]),
      );
      final legacy = await _nostrClient.readAllEvents(
        Filter(
          authors: chunk,
          kinds: [EventKind.badgeSet],
          d: ['profile_badges'],
        ),
      );
      if (!current.isComplete || !legacy.isComplete) {
        throw StateError('Badge holder profiles could not be fully loaded');
      }
      final byPubkey = <String, List<Event>>{};
      for (final event in [...current.events, ...legacy.events]) {
        if (!chunk.contains(event.pubkey)) continue;
        byPubkey.putIfAbsent(event.pubkey, () => []).add(event);
      }
      for (final pubkey in chunk) {
        profiles[pubkey] = _preferPublishedProfileBadges(
          pubkey,
          _newestParsedProfileBadges(byPubkey[pubkey] ?? const <Event>[]),
        );
      }
    }
    return profiles;
  }

  Future<Map<String, Nip58ProfileBadges?>> _profileBadgesByPubkey(
    _DashboardLookupMemo memo,
    Iterable<String> pubkeys,
  ) async {
    final unique = pubkeys.toSet().toList(growable: false);
    final loaded = await Future.wait([
      for (final pubkey in unique)
        memo.profileBadges(pubkey, () => _latestProfileBadges(pubkey)),
    ]);
    return {for (var i = 0; i < unique.length; i++) unique[i]: loaded[i]};
  }

  /// Accepts [award] by publishing the current user's profile badge list.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey or the profile badge event
  ///   cannot be signed.
  /// * [BadgePublishException] when no relay confirms the published list.
  Future<void> acceptAward(BadgeAwardViewData award) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final coordinate = award.definitionCoordinate;
    final awardEventId = award.awardEventId;
    final current =
        currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[];

    // Accepting the award that is already pinned changes nothing, and
    // rebuilding the ref would throw away its relay hint.
    final alreadyAccepted = current.any(
      (ref) =>
          ref.definitionCoordinate == coordinate &&
          ref.awardEventId == awardEventId,
    );

    // Otherwise one entry per badge, not per award: being awarded the same
    // badge twice is normal, and appending a second a/e pair for the same
    // coordinate renders the badge twice on the profile.
    final refs = alreadyAccepted
        ? current.toList(growable: false)
        : [
            for (final ref in current)
              if (ref.definitionCoordinate != coordinate) ref,
            Nip58ProfileBadgeRef(
              definitionCoordinate: coordinate,
              awardEventId: awardEventId,
            ),
          ];

    await _publishProfileBadges(refs);
  }

  /// Removes [award] from the current user's profile badge list.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey or the profile badge event
  ///   cannot be signed.
  /// * [BadgePublishException] when no relay confirms the published list.
  Future<void> removeAward(BadgeAwardViewData award) =>
      _unpinCoordinate(award.definitionCoordinate);

  /// Drops the badge at [coordinate] from the current user's profile badge
  /// list, publishing nothing when it was not pinned in the first place.
  Future<void> _unpinCoordinate(String coordinate) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final refs = currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[];
    final remaining = [
      for (final ref in refs)
        if (ref.definitionCoordinate != coordinate) ref,
    ];
    if (remaining.length == refs.length) return;

    await _publishProfileBadges(remaining);
  }

  /// Brings the dismissed badge at [definitionCoordinate] back into the
  /// awarded list.
  Future<void> unhideAward(String definitionCoordinate) async {
    final pubkey = _requireCurrentPubkey();
    final dismissed = _storedDismissedCoordinates(pubkey);
    if (dismissed.remove(definitionCoordinate)) {
      await _writeDismissedCoordinates(pubkey, dismissed);
    }
  }

  /// Dismisses the badge at [definitionCoordinate] for the current user.
  ///
  /// Keyed on the badge, not on the award event that delivered it: the
  /// awarded list shows one row per badge — the newest award wins — so a
  /// dismissal keyed on an event id died the moment the same badge was
  /// awarded again, which is exactly what an account handing out unwanted
  /// badges does.
  Future<void> hideAward(String definitionCoordinate) async {
    final pubkey = _requireCurrentPubkey();
    final dismissed = _storedDismissedCoordinates(pubkey);
    if (dismissed.add(definitionCoordinate)) {
      await _writeDismissedCoordinates(pubkey, dismissed);
    }
  }

  Future<List<Nip58BadgeAward>> _queryAwardsForRecipient(String pubkey) async {
    final events = await _nostrClient.queryEvents([
      Filter(kinds: [EventKind.badgeAward], p: [pubkey], limit: 100),
    ]);

    return events
        .map(Nip58BadgeParser.parseAward)
        .whereType<Nip58BadgeAward>()
        .where((award) => award.recipientPubkeys.contains(pubkey))
        .where(_isIssuedByBadgeOwner)
        .toList(growable: false);
  }

  /// Whether [award] was signed by the issuer of the badge it points at.
  ///
  /// A kind 8 naming you is not proof the badge's owner awarded it: this
  /// query filters on `p`, not on the author, so anyone could publish an
  /// award for someone else's coordinate and have it land in the awarded
  /// list carrying that badge's real name and artwork. The coordinate
  /// already encodes the issuer, so this costs no extra relay round trip.
  static bool _isIssuedByBadgeOwner(Nip58BadgeAward award) {
    final coordinate = BadgeCoordinate.parse(award.definitionCoordinate);
    return coordinate != null && coordinate.pubkey == award.event.pubkey;
  }

  Future<Nip58ProfileBadges?> _latestProfileBadges(String pubkey) async {
    final results = await Future.wait([
      _nostrClient.queryEvents([
        Filter(authors: [pubkey], kinds: [EventKind.profileBadges], limit: 10),
      ]),
      _nostrClient.queryEvents([
        Filter(
          authors: [pubkey],
          kinds: [EventKind.badgeSet],
          d: ['profile_badges'],
          limit: 10,
        ),
      ]),
    ]);
    // NIP-58 treats legacy 30008/d=profile_badges as equivalent to 10008,
    // so resolve both encodings as one newest-wins profile badge list.
    final fromRelays = _newestParsedProfileBadges([
      ...results[0],
      ...results[1],
    ]);

    return _preferPublishedProfileBadges(pubkey, fromRelays);
  }

  Future<Map<String, Nip58ProfileBadges?>> _latestProfileBadgesForAuthors(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return const {};
    final pubkeySet = pubkeys.toSet();
    final results = await _nostrClient.queryEvents([
      Filter(
        authors: pubkeys,
        kinds: [EventKind.profileBadges],
        limit: pubkeys.length * _profileBadgeEventsPerAuthorLimit,
      ),
      Filter(
        authors: pubkeys,
        kinds: [EventKind.badgeSet],
        d: ['profile_badges'],
        limit: pubkeys.length * _profileBadgeEventsPerAuthorLimit,
      ),
    ]);

    final byPubkey = <String, List<Event>>{};
    for (final event in results) {
      if (!pubkeySet.contains(event.pubkey)) continue;
      byPubkey.putIfAbsent(event.pubkey, () => []).add(event);
    }

    return {
      for (final pubkey in pubkeys)
        pubkey: _preferPublishedProfileBadges(
          pubkey,
          _newestParsedProfileBadges(byPubkey[pubkey] ?? const <Event>[]),
        ),
    };
  }

  Nip58ProfileBadges? _preferPublishedProfileBadges(
    String pubkey,
    Nip58ProfileBadges? fromRelays,
  ) {
    final published = _publishedProfileBadges;
    if (published == null || published.pubkey != pubkey) return fromRelays;
    // `>=` rather than `>`: `created_at` has one-second resolution, so an
    // accept and an undo in the same second tie, and the newest-wins sort
    // would fall through to comparing event ids — which would hand the
    // decision to a coin flip instead of to the write that just happened.
    if (fromRelays != null &&
        fromRelays.event.createdAt > published.badges.event.createdAt) {
      return fromRelays;
    }
    return published.badges;
  }

  Future<Nip58BadgeDefinition?> _loadDefinition(String coordinate) async {
    final parts = _parseCoordinate(coordinate);
    if (parts == null || parts.kind != EventKind.badgeDefinition) {
      return null;
    }

    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [parts.pubkey],
        kinds: [EventKind.badgeDefinition],
        d: [parts.dTag],
        limit: 1,
      ),
    ]);

    final sorted = events.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final fromRelay = sorted.isEmpty
        ? null
        : Nip58BadgeParser.parseDefinition(sorted.first);
    return _preferPublishedDefinition(coordinate, fromRelay);
  }

  /// Prefers a definition this repository published over a relay read that is
  /// not strictly newer.
  ///
  /// A genuinely newer definition — an edit made on another device — still
  /// wins, so this stops mattering as soon as the relay catches up.
  Nip58BadgeDefinition? _preferPublishedDefinition(
    String coordinate,
    Nip58BadgeDefinition? fromRelay,
  ) {
    final published = _publishedDefinitions[coordinate];
    if (published == null) return fromRelay;
    if (fromRelay != null &&
        fromRelay.event.createdAt > published.event.createdAt) {
      return fromRelay;
    }
    return published;
  }

  /// The current user's badge definitions, newest per identifier.
  ///
  /// Merges in anything this repository published that the relay is not
  /// serving yet, so a badge created or edited moments ago is already part
  /// of the list.
  Future<List<Nip58BadgeDefinition>> _ownDefinitions(
    String pubkey, {
    required int limit,
  }) async {
    final events = await _queryDefinitionsByAuthor(pubkey, limit: limit);
    final byCoordinate = {
      for (final definition in _newestDefinitionPerIdentifier(events))
        definition.coordinate: definition,
    };
    for (final published in _publishedDefinitions.values) {
      if (published.event.pubkey != pubkey) continue;
      byCoordinate[published.coordinate] = _preferPublishedDefinition(
        published.coordinate,
        byCoordinate[published.coordinate],
      )!;
    }
    return byCoordinate.values.toList(growable: false);
  }

  Future<Nip58BadgeAward?> _loadAward(String eventId) async {
    if (eventId.isEmpty) return null;

    final events = await _nostrClient.queryEvents([
      Filter(ids: [eventId], kinds: [EventKind.badgeAward], limit: 1),
    ]);
    if (events.isEmpty) return null;

    final sorted = events.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return Nip58BadgeParser.parseAward(sorted.first);
  }

  Future<void> _publishProfileBadges(List<Nip58ProfileBadgeRef> refs) async {
    final tags = <List<String>>[];
    for (final ref in refs) {
      tags
        ..add(['a', ref.definitionCoordinate])
        ..add([
          'e',
          ref.awardEventId,
          if (ref.awardRelay != null && ref.awardRelay!.isNotEmpty)
            ref.awardRelay!,
        ]);
    }

    final event = await _signAndPublish(
      kind: EventKind.profileBadges,
      label: 'profile badges',
      tags: tags,
    );

    final published = Nip58BadgeParser.parseProfileBadges(event);
    if (published != null) {
      _publishedProfileBadges = (pubkey: event.pubkey, badges: published);
    }
  }

  /// Signs and publishes an empty-content event, returning the signed event.
  ///
  /// Throws [StateError] when signing fails and [BadgePublishException] when
  /// no relay confirms the publish.
  Future<Event> _signAndPublish({
    required int kind,
    required String label,
    required List<List<String>> tags,
  }) async {
    final event = await _signEvent(kind: kind, content: '', tags: tags);
    if (event == null) {
      throw StateError('Could not sign $label event');
    }

    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw BadgePublishException(
        'Could not publish $label event: ${outcome.summary}',
        outcome: outcome,
        eventKind: kind,
      );
    }
    return event;
  }

  Set<String> _storedDismissedCoordinates(String pubkey) {
    return (_sharedPreferences.getStringList(
              _dismissedCoordinatesKey(pubkey),
            ) ??
            const <String>[])
        .toSet();
  }

  Future<void> _writeDismissedCoordinates(
    String pubkey,
    Set<String> coordinates,
  ) {
    return _sharedPreferences.setStringList(
      _dismissedCoordinatesKey(pubkey),
      coordinates.toList(growable: false),
    );
  }

  /// The dismissed badge coordinates, absorbing dismissals still stored
  /// under the older award-event key.
  ///
  /// Dismissals used to be keyed on the award event id. Rewriting them here
  /// rather than dropping them keeps a rejection the user already made, and
  /// each id is retired only once its award has actually been seen — an
  /// award missing from this relay pass is left for a later load instead of
  /// being discarded.
  Future<Set<String>> _dismissedCoordinates(
    String pubkey,
    List<Nip58BadgeAward> awards,
  ) async {
    final dismissed = _storedDismissedCoordinates(pubkey);
    final legacyIds =
        (_sharedPreferences.getStringList(_dismissedAwardsKey(pubkey)) ??
                const <String>[])
            .toSet();
    if (legacyIds.isEmpty) return dismissed;

    final retired = <String>{};
    for (final award in awards) {
      if (legacyIds.contains(award.event.id)) {
        retired.add(award.event.id);
        dismissed.add(award.definitionCoordinate);
      }
    }
    if (retired.isEmpty) return dismissed;

    legacyIds.removeAll(retired);
    await _writeDismissedCoordinates(pubkey, dismissed);
    await (legacyIds.isEmpty
        ? _sharedPreferences.remove(_dismissedAwardsKey(pubkey))
        : _sharedPreferences.setStringList(
            _dismissedAwardsKey(pubkey),
            legacyIds.toList(growable: false),
          ));
    return dismissed;
  }

  String _requireCurrentPubkey() {
    final pubkey = _currentPubkey();
    if (pubkey == null || pubkey.isEmpty) {
      throw StateError('Cannot load badges without a current pubkey');
    }
    return pubkey;
  }

  static Nip58ProfileBadges? _newestParsedProfileBadges(List<Event> events) {
    final parsed = events
        .map(Nip58BadgeParser.parseProfileBadges)
        .whereType<Nip58ProfileBadges>()
        .toList(growable: false);
    if (parsed.isEmpty) return null;

    final sorted = parsed.toList()
      ..sort((left, right) {
        final byCreatedAt = right.event.createdAt.compareTo(
          left.event.createdAt,
        );
        if (byCreatedAt != 0) return byCreatedAt;

        final byKind = (right.isLegacyProfileBadges ? 0 : 1).compareTo(
          left.isLegacyProfileBadges ? 0 : 1,
        );
        if (byKind != 0) return byKind;

        return left.event.id.compareTo(right.event.id);
      });
    return sorted.first;
  }

  static bool _containsBadgeCoordinate(
    Nip58ProfileBadges? profileBadges,
    Nip58BadgeAward award,
  ) {
    return _containsBadgeCoordinateValue(
      profileBadges,
      award.definitionCoordinate,
    );
  }

  static bool _containsBadgeCoordinateValue(
    Nip58ProfileBadges? profileBadges,
    String coordinate,
  ) {
    return profileBadges?.badges.any(
          (ref) => ref.definitionCoordinate == coordinate,
        ) ??
        false;
  }

  static ({int kind, String pubkey, String dTag})? _parseCoordinate(
    String coordinate,
  ) {
    final parts = coordinate.split(':');
    if (parts.length < 3) return null;
    final kind = int.tryParse(parts[0]);
    if (kind == null || parts[1].isEmpty) return null;
    return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
  }

  static String _dismissedCoordinatesKey(String pubkey) {
    return 'dismissed_badge_coordinates_$pubkey';
  }

  /// Key of the retired per-award dismissal list, read only to migrate it.
  static String _dismissedAwardsKey(String pubkey) {
    return 'dismissed_badge_awards_$pubkey';
  }
}

/// Deduplicates identical relay lookups within one dashboard load pass.
///
/// Memoizes futures so concurrent requests for the same definition
/// coordinate or pubkey share a single relay query. Created per public
/// load call — never stored on the repository — so a failed pass does not
/// poison a retry with cached errors.
class _DashboardLookupMemo {
  final Map<String, Future<Nip58BadgeDefinition?>> _definitions = {};
  final Map<String, Future<Nip58ProfileBadges?>> _profileBadges = {};
  final Map<String, Future<Map<String, Nip58ProfileBadges?>>>
  _profileBadgeChunks = {};
  final Map<String, Future<List<Nip58BadgeAward>>> _issuedAwards = {};

  Future<Nip58BadgeDefinition?> definition(
    String coordinate,
    Future<Nip58BadgeDefinition?> Function() load,
  ) => _definitions.putIfAbsent(coordinate, load);

  Future<Nip58ProfileBadges?> profileBadges(
    String pubkey,
    Future<Nip58ProfileBadges?> Function() load,
  ) => _profileBadges.putIfAbsent(pubkey, load);

  Future<Map<String, Nip58ProfileBadges?>> profileBadgeChunk(
    List<String> pubkeys,
    Future<Map<String, Nip58ProfileBadges?>> Function() load,
  ) {
    final key = pubkeys.join(',');
    return _profileBadgeChunks.putIfAbsent(key, load);
  }

  /// Awards authored by [pubkey]. Shared by the issued and created passes,
  /// which read the same `kind:8`-by-author query.
  Future<List<Nip58BadgeAward>> issuedAwards(
    String pubkey,
    Future<List<Nip58BadgeAward>> Function() load,
  ) => _issuedAwards.putIfAbsent(pubkey, load);
}

/// Badge label to fall back on when no kind-30009 definition loaded: the
/// d-tag half of the coordinate, or the whole coordinate when it has no
/// d-tag.
///
/// The coordinate comes from an `a` tag on someone else's award or profile
/// badges event, so it is remote text and it renders as a badge name.
/// [Nip58BadgeDefinition] sanitizes the definition-backed path; this covers
/// the one that bypasses it.
String _definitionNameFromCoordinate(String coordinate) {
  final parts = coordinate.split(':');
  if (parts.length < 3) return sanitizeUtf16(coordinate);
  return sanitizeUtf16(parts.sublist(2).join(':'));
}
