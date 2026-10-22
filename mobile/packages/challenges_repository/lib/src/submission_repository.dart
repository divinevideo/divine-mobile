part of '../challenges_repository.dart';

const int _signedActionByteLimit = 64 * 1024;

/// Participant state machine. Instantiate one writer per app account session.
final class ChallengeSubmissionRepository {
  /// Ports never own private keys; the app supplies its established signer.
  ChallengeSubmissionRepository({
    required this.reads,
    required this.store,
    required this.transport,
    required this.currentOwner,
    required this.currentVideoId,
    required this.canPublish,
    required this.sign,
    required this.writableRelays,
  });

  /// Verified known-coordinate read repository and current clock/policy.
  final ChallengesRepository reads;

  /// Owner-scoped durable context/outbox boundary.
  final ChallengeSubmissionStore store;

  /// Exact-event relay delivery boundary.
  final ChallengeRelayTransport transport;

  /// Current full owner identity; checked around asynchronous boundaries.
  final String? Function() currentOwner;

  /// Current published video revision for this reviewed video; null means
  /// unavailable or scheduled, and never authorizes entry.
  final String? Function(NostrEvent video) currentVideoId;

  /// Current actor/action permission, distinct from media visibility. Apply
  /// this to withdrawals too; hidden media alone must not deny withdrawal.
  final bool Function(SubmissionReview review) canPublish;

  /// Receives only frozen reviewed fields. Returns exact signed JSON bytes.
  final Future<String> Function(UnsignedChallengeAction fields) sign;

  /// Current configured writable relays; copied before publication.
  final List<String> Function() writableRelays;

  /// Prepares and durably records the exact handoff before draft cleanup.
  /// Throws [SubmissionException] or a storage exception on failure.
  Future<SubmissionReview> prepareEntry({
    required NostrEvent definition,
    required NostrEvent video,
    List<List<String>> clientTags = const [],
  }) async {
    final d = parseChallengeEvent(definition).value;
    if (d is! ChallengeDefinition) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final owner = currentOwner();
    if (owner == null || owner != video.pubkey) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    final template = buildEntry(d, video, reads.clock());
    final review = SubmissionReview(
      owner: owner,
      definition: d.event,
      video: NostrEvent.fromJson(video.toJson()),
      fields: _fields(template, clientTags),
    );
    await _checkCurrent(review);
    final existing = await store.loadAction(owner, review.id);
    _checkLocal(review);
    if (existing != null) {
      // Identical second-resolution fields name the same Nostr event. New
      // consent must not pretend that a withdrawn or pending event is reentry.
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    await store.saveReview(owner, review);
    _checkLocal(review);
    return review;
  }

  /// Prepares withdrawal of exactly one owned entry; never deletes a video.
  Future<SubmissionReview> prepareWithdrawal({
    required NostrEvent entry,
    List<List<String>> clientTags = const [],
  }) async {
    final parsed = parseChallengeEvent(entry).value;
    if (parsed is! ChallengeEntry) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final review = SubmissionReview(
      owner: parsed.event.pubkey,
      definition: parsed.definition.event,
      video: parsed.video,
      withdrawalEntry: parsed.event,
      fields: _fields(
        buildWithdrawal(parsed.definition, parsed, reads.clock()),
        clientTags,
      ),
    );
    _checkLocal(review);
    await store.saveReview(review.owner, review);
    _checkLocal(review);
    return review;
  }

  /// Restores owner-scoped review context without granting new consent.
  Future<SubmissionReview?> restoreReview(String reviewId) async {
    final owner = currentOwner();
    if (owner == null) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    final review = await store.loadReview(owner, reviewId);
    if (currentOwner() != owner || (review != null && review.owner != owner)) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    if (review != null) _validateReview(review);
    return review;
  }

  /// Lists durable work for the current owner after restart.
  Future<List<PendingChallengeAction>> pendingActions() async {
    final owner = currentOwner();
    if (owner == null) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    final actions = await store.listActions(owner);
    if (currentOwner() != owner ||
        actions.any((action) => action.review.owner != owner)) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    return List.unmodifiable(actions);
  }

  /// Rechecks current authority, persists exact signed bytes, then publishes.
  /// Once insertion completes, first delivery uses the same gates as [retry].
  /// Cancellation returns [SubmissionStatus.deliveryPaused] with retained work,
  /// never a request to sign replacement consent.
  Future<SubmissionResult> submit(SubmissionReview review) =>
      _singleFlight('submit:${review.id}', () => _submit(review));

  /// Restores exact durable bytes by review ID; never signs a retry.
  /// Later active rules, video metadata changes, or closing do not revoke the
  /// original signature. Cancellation, unavailable current rules, and current
  /// owner/policy restrictions pause publication without deleting the outbox.
  Future<SubmissionResult> retry(String reviewId) =>
      _singleFlight('retry:$reviewId', () async {
        final owner = currentOwner();
        if (owner == null) {
          return const SubmissionResult(SubmissionStatus.ownerChanged);
        }
        try {
          final action = await store.loadAction(owner, reviewId);
          if (currentOwner() != owner) {
            return SubmissionResult(SubmissionStatus.ownerChanged, action);
          }
          if (action == null) {
            return const SubmissionResult(SubmissionStatus.reviewRequired);
          }
          _validateSigned(action.review, action.signedBody);
          return await _deliver(action);
        } on SubmissionException catch (error) {
          return SubmissionResult(error.status);
        } on Exception {
          return const SubmissionResult(SubmissionStatus.persistenceFailed);
        }
      });

  /// Reconciles a signed exact-ID observation independently from indexing.
  Future<SubmissionResult> reconcile(
    String reviewId,
    String signedBody, {
    String? relay,
    bool indexed = false,
  }) => _singleFlight(
    'reconcile:$reviewId:$relay:$indexed:'
    '${sha256.convert(utf8.encode(signedBody))}',
    () async {
      final owner = currentOwner();
      if (owner == null) {
        return const SubmissionResult(SubmissionStatus.ownerChanged);
      }
      PendingChallengeAction? action;
      try {
        action = await store.loadAction(owner, reviewId);
        if (currentOwner() != owner) {
          return SubmissionResult(SubmissionStatus.ownerChanged, action);
        }
        if (action == null) {
          return const SubmissionResult(SubmissionStatus.reviewRequired);
        }
        final expected = _validateSigned(action.review, action.signedBody);
        final observed = _validateSigned(action.review, signedBody);
        if (observed.id != expected.id) {
          return SubmissionResult(SubmissionStatus.invalidSignedEvent, action);
        }
        final updated = PendingChallengeAction(
          review: action.review,
          signedBody: action.signedBody,
          challengeRelays: action.challengeRelays,
          targets: action.targets,
          outcomes: action.outcomes,
          echoed: action.echoed || action.challengeRelays.contains(relay),
          indexed: action.indexed || indexed,
        );
        await store.saveAction(owner, updated);
        if (currentOwner() != owner) {
          return SubmissionResult(SubmissionStatus.ownerChanged, updated);
        }
        return _result(updated);
      } on SubmissionException catch (error) {
        return SubmissionResult(error.status, action);
      } on Exception {
        return SubmissionResult(SubmissionStatus.persistenceFailed, action);
      }
    },
  );

  final _inFlight = <String, Future<SubmissionResult>>{};
  Future<void> _tail = Future<void>.value();

  Future<SubmissionResult> _singleFlight(
    String key,
    Future<SubmissionResult> Function() operation,
  ) {
    final scopedKey = '${currentOwner()}:$key';
    final existing = _inFlight[scopedKey];
    if (existing != null) return existing;
    final future = _tail.then((_) => operation());
    _inFlight[scopedKey] = future;
    _tail = future.then<void>(
      (_) {
        _inFlight.removeWhere((candidate, _) => candidate == scopedKey);
      },
      onError: (Object _, StackTrace _) {
        _inFlight.removeWhere((candidate, _) => candidate == scopedKey);
      },
    );
    return future;
  }

  UnsignedChallengeAction _fields(
    EventTemplate template,
    List<List<String>> clientTags,
  ) {
    if (clientTags.length > 1 ||
        clientTags.any((tag) => tag.isEmpty || tag.first != 'client')) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final fields = UnsignedChallengeAction(
      kind: template.kind,
      createdAt: template.createdAt,
      content: template.content,
      tags: [...template.tags, ...clientTags],
    );
    final projected = {
      ...fields.toJson(),
      'id': '0' * 64,
      'pubkey': '0' * 64,
      'sig': '0' * 128,
    };
    if (utf8.encode(jsonEncode(projected)).length > _signedActionByteLimit) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    return fields;
  }

  ChallengeDefinition _validateReview(SubmissionReview review) {
    final d = parseChallengeEvent(review.definition).value;
    if (d is! ChallengeDefinition || review.owner != review.video.pubkey) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    EventTemplate expected;
    final withdrawal = review.withdrawalEntry;
    if (withdrawal == null) {
      expected = buildEntry(d, review.video, review.fields.createdAt);
    } else {
      final entry = parseChallengeEvent(withdrawal).value;
      if (entry is! ChallengeEntry ||
          entry.event.pubkey != review.owner ||
          entry.video.id != review.video.id ||
          entry.definition.event.id != d.event.id) {
        throw const SubmissionException(SubmissionStatus.reviewRequired);
      }
      expected = buildWithdrawal(d, entry, review.fields.createdAt);
    }
    final tags = review.fields.tags;
    if (tags.length < expected.tags.length) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final approved = _fields(expected, tags.sublist(expected.tags.length));
    if (jsonEncode(approved.toJson()) != jsonEncode(review.fields.toJson())) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    return d;
  }

  void _checkOwnerAndPolicy(SubmissionReview review) {
    if (currentOwner() != review.owner) {
      throw const SubmissionException(SubmissionStatus.ownerChanged);
    }
    if (!canPublish(review)) {
      throw const SubmissionException(SubmissionStatus.blocked);
    }
    if (review.withdrawalEntry != null) return;
    if (!reads.isVisible(review.definition) || !reads.isVisible(review.video)) {
      throw const SubmissionException(SubmissionStatus.blocked);
    }
  }

  void _checkLocal(SubmissionReview review) {
    _checkOwnerAndPolicy(review);
    if (review.withdrawalEntry != null) return;
    if (currentVideoId(review.video) != review.video.id) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    final d = parseChallengeEvent(review.definition).value;
    if (d is! ChallengeDefinition ||
        reads.clock() < d.start ||
        reads.clock() >= d.end) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
  }

  Future<ChallengeDefinition> _checkCurrent(SubmissionReview review) async {
    _checkLocal(review);
    final d = _validateReview(review);
    if (review.withdrawalEntry != null) return d;
    final read = await reads.refresh(d.coordinate);
    _checkLocal(review);
    if (read.observation.completeness != ReadCompleteness.complete) {
      throw const SubmissionException(SubmissionStatus.readUnavailable);
    }
    if (read.view.state != 'open' ||
        read.view.definition?.event.id != d.event.id) {
      throw const SubmissionException(SubmissionStatus.reviewRequired);
    }
    return d;
  }

  NostrEvent _validateSigned(SubmissionReview review, String body) {
    try {
      if (body.length > _signedActionByteLimit ||
          utf8.encode(body).length > _signedActionByteLimit) {
        throw const SubmissionException(SubmissionStatus.invalidSignedEvent);
      }
      final event = NostrEvent.fromJson(
        jsonDecode(body) as Map<String, Object?>,
      );
      final fields = UnsignedChallengeAction(
        kind: event.kind,
        createdAt: event.createdAt,
        content: event.content,
        tags: event.tags,
      );
      final parsed = parseChallengeEvent(event).value;
      if (event.pubkey != review.owner ||
          jsonEncode(fields.toJson()) != jsonEncode(review.fields.toJson()) ||
          (review.withdrawalEntry == null
              ? parsed is! ChallengeEntry
              : parsed is! ChallengeWithdrawal)) {
        throw const SubmissionException(SubmissionStatus.invalidSignedEvent);
      }
      _validateReview(review);
      return event;
    } on Object {
      throw const SubmissionException(SubmissionStatus.invalidSignedEvent);
    }
  }

  Future<SubmissionResult> _submit(SubmissionReview review) async {
    PendingChallengeAction? action;
    try {
      _checkLocal(review);
      action = await store.loadAction(review.owner, review.id);
      _checkLocal(review);
      if (action != null) {
        _validateSigned(action.review, action.signedBody);
        return _result(action);
      }
      final definition = await _checkCurrent(review);
      String body;
      try {
        body = await sign(review.fields);
      } on Exception {
        return const SubmissionResult(SubmissionStatus.signerFailed);
      }
      _checkLocal(review);
      _validateSigned(review, body);
      await _checkCurrent(review);
      final relays = definition.relays;
      action = await store.insertAction(
        review.owner,
        PendingChallengeAction(
          review: review,
          signedBody: body,
          challengeRelays: relays,
          targets: {...relays, ...writableRelays()}.toList(),
        ),
      );
      _validateSigned(action.review, action.signedBody);
      return await _deliver(action);
    } on SubmissionException catch (error) {
      return SubmissionResult(error.status, action);
    } on ContractError {
      return SubmissionResult(SubmissionStatus.reviewRequired, action);
    } on Exception {
      return SubmissionResult(SubmissionStatus.persistenceFailed, action);
    }
  }

  Future<void> _checkRetry(PendingChallengeAction action) async {
    final review = action.review;
    _checkOwnerAndPolicy(review);
    final definition = _validateReview(review);
    if (review.withdrawalEntry != null) return;
    final current = await reads.refresh(definition.coordinate);
    _checkOwnerAndPolicy(review);
    if (!current.observation.revisionsComplete ||
        current.view.definition == null) {
      throw const SubmissionException(SubmissionStatus.readUnavailable);
    }
    if (current.view.definition!.status == 'cancelled') {
      throw const SubmissionException(SubmissionStatus.deliveryPaused);
    }
  }

  Future<SubmissionResult> _deliver(PendingChallengeAction action) async {
    final review = action.review;
    try {
      // Durable verified consent has identical delivery gates on its first
      // attempt and every retry; changes here must never request a new entry.
      await _checkRetry(action);
      final event = _validateSigned(review, action.signedBody);
      if (review.withdrawalEntry == null && !reads.isVisible(event)) {
        throw const SubmissionException(SubmissionStatus.blocked);
      }
      if (action.submitted) return _result(action);
      Map<String, RelayOutcome> outcomes;
      try {
        outcomes = await transport(action.signedBody, action.targets);
      } on Exception {
        outcomes = {
          for (final relay in action.targets) relay: RelayOutcome.silence,
        };
      }
      final updated = PendingChallengeAction(
        review: review,
        signedBody: action.signedBody,
        challengeRelays: action.challengeRelays,
        targets: action.targets,
        outcomes: {
          for (final relay in action.targets)
            relay: action.outcomes[relay] == RelayOutcome.accepted
                ? RelayOutcome.accepted
                : outcomes[relay] ?? RelayOutcome.silence,
        },
        echoed: action.echoed,
        indexed: action.indexed,
      );
      // A response after account switch belongs only in the original owner's
      // outbox. Persist that evidence; never publish another owner's action.
      await store.saveAction(review.owner, updated);
      _checkOwnerAndPolicy(review);
      return _result(updated);
    } on SubmissionException catch (error) {
      return SubmissionResult(error.status, action);
    } on Exception {
      return SubmissionResult(SubmissionStatus.persistenceFailed, action);
    }
  }

  SubmissionResult _result(PendingChallengeAction action) => SubmissionResult(
    action.submitted ? SubmissionStatus.submitted : SubmissionStatus.retryable,
    action,
  );
}
