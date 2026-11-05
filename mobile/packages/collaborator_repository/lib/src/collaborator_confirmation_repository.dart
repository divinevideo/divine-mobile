// ABOUTME: Derives per-video collaborator confirmation status on mobile.
// ABOUTME: Subscribes to kind-34238 acceptance events for every viewer.

import 'dart:async';
import 'dart:convert';

import 'package:collaborator_repository/src/local_state_reader.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Divine collaborator response event kind (NIP-33 addressable, replaceable
/// per `(collaborator pubkey, video address)`). Mirrors the constant in
/// `mobile/lib/constants/collaboration_event_kinds.dart`; duplicated here to
/// keep the repository free of app-layer imports.
const int _kindCollaboratorResponse = 34238;

/// Composes the kind-34238 relay subscription, the cross-check against
/// creator-side `'collaborator'`-role p-tags, and the current user's local
/// invite-store fast-path into a single per-video status snapshot stream.
///
/// The kind-34238 subscription opens for every viewer, not just the video's
/// author. Third-party viewers need confirmation data to distinguish an
/// accepted collaborator from someone the creator merely tagged; without it
/// the render surfaces credit both identically (#6907).
///
/// Snapshots carry [VideoCollaboratorStatus.isResolved] so callers can tell
/// "did not accept" from "have not heard back yet" — both leave a pubkey
/// [CollaboratorStatus.pending], but only the former is a real answer.
///
/// One subscription per video address, filtered by the latest watcher's
/// tagged pubkeys and ref-counted across that address's watchers; a watch with
/// a different list replaces it. The repository owns the explicit
/// Nostr subscription id so release/close can send `CLOSE` to relays instead
/// of only cancelling the local Dart listener.
class CollaboratorConfirmationRepository {
  CollaboratorConfirmationRepository({
    required NostrClient nostrClient,
    required CollaboratorInviteLocalStateReader localStateReader,
    required String currentUserPubkey,
  }) : _nostrClient = nostrClient,
       _localStateReader = localStateReader,
       _currentUserPubkey = currentUserPubkey;

  final NostrClient _nostrClient;
  final CollaboratorInviteLocalStateReader _localStateReader;
  final String _currentUserPubkey;

  /// Acceptance events observed from the relay, keyed by `videoAddress`.
  /// Each inner set contains collaborator pubkeys that have published a
  /// valid kind-34238 acceptance for that address.
  final Map<String, Set<String>> _relayAccepted = <String, Set<String>>{};

  /// Local fast-path overrides for the current user. Keyed by
  /// `videoAddress` → [CollaboratorStatus]. Only the current user's own
  /// pubkey is meaningful here.
  final Map<String, CollaboratorStatus> _currentUserOverride =
      <String, CollaboratorStatus>{};

  /// Per-video broadcast subjects. Created on first [watch], reused after.
  final Map<String, BehaviorSubject<VideoCollaboratorStatus>> _subjects =
      <String, BehaviorSubject<VideoCollaboratorStatus>>{};

  /// Per-video ref counts. Subscriptions close when count drops to zero.
  final Map<String, int> _refCount = <String, int>{};

  /// Per-video relay subscriptions. The active subscription's author filter is
  /// captured here because it changes when the creator edits collaborators.
  final Map<String, _RelaySubscription> _relaySubs =
      <String, _RelaySubscription>{};

  /// Video addresses whose acceptance query has reached relay EOSE. Until an
  /// address is in here, a `pending` entry means "not heard back yet" rather
  /// than "did not accept".
  final Set<String> _resolved = <String>{};

  /// Per-video cache of the most recent watch parameters. Lets
  /// [markLocal] re-emit a snapshot without callers having to thread the
  /// creator pubkey and tagged-pubkey list through every accept/ignore site.
  final Map<String, _WatchContext> _watchContext = <String, _WatchContext>{};

  /// Returns a stream of [VideoCollaboratorStatus] for [videoAddress].
  ///
  /// [creatorPubkey] is the author of the kind-34236 video event. Used to
  /// key the current user's local-store lookup.
  ///
  /// [taggedPubkeys] is the list of pubkeys tagged with the
  /// `'collaborator'` role on the latest creator-authored video event. Used
  /// to reject acceptance events from non-tagged pubkeys. Watchers of one
  /// [videoAddress] that are open together should pass the same list: state
  /// is keyed by the address alone, so a different list replaces the shared
  /// subscription and drops the acceptances the others already saw. That
  /// replacement is the intended path when the creator edits collaborators.
  ///
  /// Callers must call [release] with the same [videoAddress] when done to
  /// decrement the ref count and allow cleanup.
  Stream<VideoCollaboratorStatus> watch(
    String videoAddress, {
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    final normalizedTaggedPubkeys = _normalizePubkeys(taggedPubkeys);
    _refCount[videoAddress] = (_refCount[videoAddress] ?? 0) + 1;
    _watchContext[videoAddress] = _WatchContext(
      creatorPubkey: creatorPubkey,
      taggedPubkeys: List.unmodifiable(normalizedTaggedPubkeys),
    );

    final subject =
        _subjects.putIfAbsent(
            videoAddress,
            () => BehaviorSubject<VideoCollaboratorStatus>.seeded(
              _snapshot(
                videoAddress: videoAddress,
                creatorPubkey: creatorPubkey,
                taggedPubkeys: normalizedTaggedPubkeys,
              ),
            ),
          )
          // Always re-emit a fresh snapshot so callers that arrive after
          // acceptance events have landed see the cached state immediately.
          ..add(
            _snapshot(
              videoAddress: videoAddress,
              creatorPubkey: creatorPubkey,
              taggedPubkeys: normalizedTaggedPubkeys,
            ),
          );

    // Open the relay subscription on demand, for every viewer. Third-party
    // viewers need it too: without confirmation data they cannot tell an
    // accepted collaborator from someone the creator merely tagged, and the
    // render surfaces would credit both. The relay serves kind-34238 to
    // unauthenticated readers, so no signer or backend route is required.
    //
    // `authors` bounds the result set to pubkeys that could legitimately
    // confirm; only tagged pubkeys are meaningful, and the handler
    // re-checks membership anyway. Omitted when nothing is tagged, since an
    // empty authors array is not a meaningful filter.
    _ensureRelaySubscription(
      videoAddress: videoAddress,
      creatorPubkey: creatorPubkey,
      taggedPubkeys: normalizedTaggedPubkeys,
      subject: subject,
    );

    return subject.stream;
  }

  /// Decrements the ref count for [videoAddress]; closes the subject and
  /// the relay subscription when the count drops to zero.
  void release(String videoAddress) {
    final current = _refCount[videoAddress] ?? 0;
    if (current <= 1) {
      _refCount.remove(videoAddress);
      final relaySub = _relaySubs.remove(videoAddress);
      if (relaySub != null) {
        unawaited(_cancelRelaySubscription(relaySub));
      }
      unawaited(_subjects.remove(videoAddress)?.close());
      _relayAccepted.remove(videoAddress);
      _currentUserOverride.remove(videoAddress);
      _watchContext.remove(videoAddress);
      _resolved.remove(videoAddress);
      return;
    }
    _refCount[videoAddress] = current - 1;
  }

  /// Returns the current synchronous status snapshot for [videoAddress].
  /// Returns an empty snapshot if the video is not being watched.
  VideoCollaboratorStatus current(String videoAddress) {
    final subject = _subjects[videoAddress];
    if (subject != null && subject.hasValue) {
      return subject.value;
    }
    return VideoCollaboratorStatus(videoAddress: videoAddress);
  }

  /// Local fast-path: records the current user's accept/ignore decision
  /// for a video they were invited to. Emits an updated snapshot to any
  /// active subscriber.
  ///
  /// Quietly drops writes for pubkeys other than the current user; the
  /// local store is per-device and only tracks the current user's own
  /// decisions.
  void markLocal({
    required String videoAddress,
    required String collaboratorPubkey,
    required CollaboratorStatus status,
  }) {
    if (collaboratorPubkey != _currentUserPubkey) {
      Log.warning(
        'markLocal called for non-current-user pubkey '
        '${pubkeyForLogs(collaboratorPubkey)}; ignoring',
        name: 'CollaboratorConfirmationRepository',
        category: LogCategory.system,
      );
      return;
    }
    _currentUserOverride[videoAddress] = status;
    final subject = _subjects[videoAddress];
    final context = _watchContext[videoAddress];
    if (subject != null && context != null) {
      subject.add(
        _snapshot(
          videoAddress: videoAddress,
          creatorPubkey: context.creatorPubkey,
          taggedPubkeys: context.taggedPubkeys,
        ),
      );
    }
  }

  /// Disposes all subjects and subscriptions. Used on sign-out / shutdown.
  Future<void> close() async {
    for (final sub in _relaySubs.values) {
      await _cancelRelaySubscription(sub);
    }
    _relaySubs.clear();
    for (final subject in _subjects.values) {
      await subject.close();
    }
    _subjects.clear();
    _refCount.clear();
    _relayAccepted.clear();
    _currentUserOverride.clear();
    _watchContext.clear();
    _resolved.clear();
  }

  /// Marks [videoAddress] resolved on relay EOSE and re-emits so surfaces
  /// gated on [VideoCollaboratorStatus.isResolved] can render.
  void _markResolved(String videoAddress, {required String subscriptionId}) {
    final subject = _subjects[videoAddress];
    final context = _watchContext[videoAddress];
    final relaySub = _relaySubs[videoAddress];
    if (subject == null || context == null) return;
    if (relaySub?.subscriptionId != subscriptionId) return;
    if (!_resolved.add(videoAddress)) return;
    subject.add(
      _snapshot(
        videoAddress: videoAddress,
        creatorPubkey: context.creatorPubkey,
        taggedPubkeys: context.taggedPubkeys,
      ),
    );
  }

  void _handleAcceptanceEvent(
    Event event, {
    required String videoAddress,
    required String subscriptionId,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    if (event.kind != _kindCollaboratorResponse) return;
    if (_relaySubs[videoAddress]?.subscriptionId != subscriptionId) return;

    // NIP-33 'a' tag references another addressable event (the video). The
    // kind-34238 event's own 'd' tag identifies itself, not the video, so
    // only 'a' is semantically meaningful here.
    final addressMatches = event.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'a' && tag[1] == videoAddress,
    );
    if (!addressMatches) return;

    // A missing `status` tag means accepted. divine-web publishes acceptances
    // as `[['a', coord], ['d', uuid]]` with no `status`, and Funnelcake's
    // confirmed read model does not require one either — requiring it here
    // silently dropped every web-made acceptance. Only an explicit
    // non-accepted status rejects the event.
    final statusTag = event.tags.firstWhere(
      (tag) => tag.length >= 2 && tag[0] == 'status',
      orElse: () => const <String>[],
    );
    if (statusTag.length >= 2 && statusTag[1] != 'accepted') return;

    final normalizedEventPubkey = event.pubkey.toLowerCase();
    if (!taggedPubkeys.contains(normalizedEventPubkey)) {
      Log.info(
        'Ignoring kind-$_kindCollaboratorResponse from non-tagged pubkey '
        '${pubkeyForLogs(event.pubkey)} for $videoAddress',
        name: 'CollaboratorConfirmationRepository',
        category: LogCategory.system,
      );
      return;
    }

    final accepted = _relayAccepted.putIfAbsent(videoAddress, () => <String>{});
    if (accepted.add(normalizedEventPubkey)) {
      final subject = _subjects[videoAddress];
      subject?.add(
        _snapshot(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          taggedPubkeys: taggedPubkeys,
        ),
      );
    }
  }

  void _ensureRelaySubscription({
    required String videoAddress,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
    required BehaviorSubject<VideoCollaboratorStatus> subject,
  }) {
    final subscriptionId = _subscriptionIdFor(
      videoAddress: videoAddress,
      taggedPubkeys: taggedPubkeys,
    );
    final existing = _relaySubs[videoAddress];
    if (existing != null) {
      if (existing.subscriptionId == subscriptionId) return;

      _relaySubs.remove(videoAddress);
      unawaited(_cancelRelaySubscription(existing));
      _relayAccepted.remove(videoAddress);
      _resolved.remove(videoAddress);
      subject.add(
        _snapshot(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          taggedPubkeys: taggedPubkeys,
        ),
      );
    }

    // Owned by _RelaySubscription and cancelled from release/close.
    // ignore: cancel_subscriptions
    final relayStreamSub = _nostrClient
        .subscribe(
          [
            Filter(
              kinds: const [_kindCollaboratorResponse],
              a: [videoAddress],
              authors: taggedPubkeys.isEmpty
                  ? null
                  : List<String>.of(taggedPubkeys),
            ),
          ],
          subscriptionId: subscriptionId,
          onEose: () =>
              _markResolved(videoAddress, subscriptionId: subscriptionId),
        )
        .listen(
          (event) => _handleAcceptanceEvent(
            event,
            videoAddress: videoAddress,
            subscriptionId: subscriptionId,
            creatorPubkey: creatorPubkey,
            taggedPubkeys: taggedPubkeys,
          ),
          onError: (Object error, StackTrace stackTrace) {
            Log.warning(
              'kind-$_kindCollaboratorResponse subscription error for '
              '$videoAddress: $error',
              name: 'CollaboratorConfirmationRepository',
              category: LogCategory.system,
            );
          },
        );
    _relaySubs[videoAddress] = _RelaySubscription(
      subscriptionId: subscriptionId,
      streamSubscription: relayStreamSub,
    );
  }

  Future<void> _cancelRelaySubscription(_RelaySubscription relaySub) async {
    await relaySub.streamSubscription.cancel();
    await _nostrClient.unsubscribe(relaySub.subscriptionId);
  }

  VideoCollaboratorStatus _snapshot({
    required String videoAddress,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    final statusByPubkey = <String, CollaboratorStatus>{};
    final accepted = _relayAccepted[videoAddress] ?? const <String>{};
    final override = _currentUserOverride[videoAddress];

    for (final pubkey in taggedPubkeys) {
      // The current user's own local decision is authoritative on this
      // device and outranks the relay echo. Ignore is local-only with no
      // protocol un-accept, so a kind-34238 from an earlier accept must not
      // resurrect an avatar the user has since hidden. Other pubkeys' local
      // states are unknown to this device.
      //
      // Order matters: before #6907 the subscription never opened for a
      // recipient viewing someone else's video, so `accepted` was always
      // empty here and checking the relay first was harmless. It opens for
      // every viewer now, which would let the echo overwrite the ignore.
      if (pubkey == _currentUserPubkey) {
        final local =
            override ??
            _localStateReader.readLocalState(
              videoAddress: videoAddress,
              creatorPubkey: creatorPubkey,
              collaboratorPubkey: pubkey,
            );
        if (local != null) {
          statusByPubkey[pubkey] = local;
          continue;
        }
      }

      // Relay-derived: kind-34238 acceptance event observed.
      if (accepted.contains(pubkey)) {
        statusByPubkey[pubkey] = CollaboratorStatus.confirmed;
        continue;
      }

      statusByPubkey[pubkey] = CollaboratorStatus.pending;
    }

    return VideoCollaboratorStatus(
      videoAddress: videoAddress,
      statusByPubkey: statusByPubkey,
      isResolved: _resolved.contains(videoAddress),
    );
  }
}

List<String> _normalizePubkeys(List<String> pubkeys) {
  final normalized = <String>[];
  for (final pubkey in pubkeys) {
    final lower = pubkey.toLowerCase();
    if (lower.isNotEmpty && !normalized.contains(lower)) {
      normalized.add(lower);
    }
  }
  return normalized;
}

String _subscriptionIdFor({
  required String videoAddress,
  required List<String> taggedPubkeys,
}) {
  final filterKey = jsonEncode([
    videoAddress,
    [...taggedPubkeys]..sort(),
  ]);
  return 'collab-confirmation-${_fnv1a64(filterKey).toRadixString(16)}';
}

BigInt _fnv1a64(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final codeUnit in value.codeUnits) {
    hash ^= BigInt.from(codeUnit);
    hash = (hash * prime) & mask;
  }
  return hash;
}

class _RelaySubscription {
  const _RelaySubscription({
    required this.subscriptionId,
    required this.streamSubscription,
  });

  final String subscriptionId;
  final StreamSubscription<Event> streamSubscription;
}

class _WatchContext {
  const _WatchContext({
    required this.creatorPubkey,
    required this.taggedPubkeys,
  });

  final String creatorPubkey;
  final List<String> taggedPubkeys;
}
