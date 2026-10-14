// ABOUTME: Time budget for a single NIP-17 message send, as linked constants.
// ABOUTME: The publish backstop is derived from these, never hand-computed.

/// The time budget for one NIP-17 1:1 message send, expressed as its parts.
///
/// ## Why this exists
///
/// The send-level backstop used to be a hand-computed number written into a
/// doc comment. #6046 derived it from a Keycast per-RPC bound of 12s; #6075
/// raised that bound to 30s without re-deriving the backstop, and the comment
/// kept asserting the 12s arithmetic long after it was false (#6586). The cap
/// ended up *smaller* than the work it bounds, so it fired on sends that had
/// already been delivered.
///
/// Every sub-bound now lives here and the totals are computed from the same
/// private seconds constants, so the derivation cannot silently go stale
/// again. A guard test in the app layer (which can see both this package and
/// `keycast_flutter`) pins the relationship against the real transport bound.
///
/// The totals are built from `int` seconds rather than by adding [Duration]s
/// because `Duration.operator+` is not `const` — summing durations would force
/// these off `const` and let a hand-typed total creep back in.
///
/// ## The shape being bounded
///
/// A 1:1 kind-14 send costs **four** remote-signer round trips, measured
/// against the real send path (#6586):
///
/// * recipient wrap: `nip44Encrypt` (seal content) + `signEvent` (seal)
/// * self wrap: the same two, built lazily after the recipient publish confirms
///
/// The kind-1059 gift wrap itself is signed with a freshly generated ephemeral
/// key (NIP-59), so it never reaches the signer. Local-key signers build both
/// wraps in one isolate hop and spend no round trips at all — these bounds sit
/// far above that path and never bind it.
abstract final class DmSendBudget {
  /// The two seal round trips a wrap build spends, at the transport's own
  /// per-op bound (`KeycastRpc.defaultRequestTimeout`, 20s).
  ///
  /// Restated here because `dm_repository` cannot import `keycast_flutter`.
  /// [boundedSignerFloor] exposes the derived floor so the app-layer guard can
  /// assert the real relationship. That makes this going stale fail CI rather
  /// than silently under-sizing the bound — which is the #6586 failure mode
  /// itself.
  static const int _twoTransportBoundsSeconds = 40;

  /// Margin inside a wrap-build bound for the local work that runs alongside
  /// the two remote round trips: seal construction, the ephemeral keypair,
  /// the NIP-44 ECDH + ChaCha20 encryption of the seal, and the wrap's
  /// secp256k1 signature (`GiftWrapUtil.getGiftWrapEvent`).
  ///
  /// Without it the bound would sit at *exactly* two transport bounds, so two
  /// ops that each returned just under 20s would still blow it — failing a
  /// build the transport itself had completed. That is the same
  /// "sized at the worst case with no margin" shape #6586 was about, one step
  /// earlier in the chain.
  static const int _wrapBuildLocalCryptoSeconds = 5;

  /// What a wrap build costs against a signer that bounds its own operations,
  /// i.e. Keycast: two transport bounds plus the local crypto between them.
  ///
  /// This is the **floor** under [_recipientWrapBuildSeconds], not its value.
  /// Sizing the build bound below it would fail requests the transport itself
  /// would have allowed — the #6046 mistake #6075 had to revert — and the
  /// app-layer guard test pins that it stays a floor.
  static const int _boundedSignerFloorSeconds =
      _twoTransportBoundsSeconds + _wrapBuildLocalCryptoSeconds;

  /// Minimum wrap-build budget for signers that bound their own operations.
  ///
  /// Exposed only so the app-layer guard can compare this package's restated
  /// Keycast floor against `KeycastRpc.defaultRequestTimeout`, which
  /// `dm_repository` cannot import directly.
  static const Duration boundedSignerFloor = Duration(
    seconds: _boundedSignerFloorSeconds,
  );

  /// Room above [_boundedSignerFloorSeconds] for a signer whose per-op wait is
  /// **not** bounded by a transport at all: Amber's NIP-55 intent path puts a
  /// human approval prompt in front of each of the two round trips, and a
  /// bunker can be arbitrarily slow.
  ///
  /// Sized to hold [recipientWrapBuild] at the 65s it has shipped at.
  /// Re-deriving the transport bound in #7092 lowered the floor beneath this
  /// window; it said nothing about the window itself, and no observation says
  /// 65s is the wrong amount of time to let a person approve two prompts.
  /// Following the floor down to 45s would have spent a user-visible Amber
  /// regression to buy headroom the send path was not short of — the totals
  /// below already clear [messagePublishTimeout] with room.
  static const int _unboundedSignerHeadroomSeconds = 20;

  /// Seconds allowed for building the recipient gift wrap. See
  /// [recipientWrapBuild].
  static const int _recipientWrapBuildSeconds =
      _boundedSignerFloorSeconds + _unboundedSignerHeadroomSeconds;

  /// Seconds allowed for the recipient OK confirmation. See
  /// [recipientOkConfirm].
  static const int _recipientOkConfirmSeconds = 10;

  /// Seconds allowed for building the self-addressed gift wrap. See
  /// [selfWrapBuild].
  static const int _selfWrapBuildSeconds = 20;

  /// Seconds allowed for publishing the self-addressed gift wrap. See
  /// [selfWrapPublish].
  static const int _selfWrapPublishSeconds = 10;

  /// Bound on the injected connectivity probe.
  ///
  /// `connectivity_plus`' `checkConnectivity()` is a platform-channel round
  /// trip with no timeout of its own, and `_isOfflineSafely`'s `try/catch`
  /// cannot help: a wedged channel is a hang, not a throw. It runs INSIDE the
  /// publish backstop, so unbounded it spends the cap that exists for a wedged
  /// signer (#7091). A channel slower than this is wedged, not busy.
  static const int _connectivityProbeSeconds = 3;

  /// Bound on the injected send-policy check.
  ///
  /// Sized to the resolver's own Dio connect/receive bound, so this can only
  /// fire on a transport that has already given up.
  static const int _sendPolicyCheckSeconds = 5;

  /// Bound on `Nostr.refreshPublicKey()` before the wrap build.
  ///
  /// Deliberately tight. Every signer this app injects answers `getPublicKey`
  /// from a field: the send path receives a `NostrIdentity`
  /// (`nostr_client_provider.dart` builds the client from
  /// `authService.currentIdentity`), which returns `async => pubkey`.
  /// `KeycastRpc.getPublicKey` IS a real uncached RPC, but it sits behind that
  /// identity rather than on this path, and NIP-46's returns a local field.
  /// So this cannot fail work a shipped signer would have completed.
  static const int _signerPubkeyRefreshSeconds = 3;

  /// Serial worst case of the three pre-wrap steps inside the backstop.
  ///
  /// Public so `DmBatchSendBudget` folds in the same number rather than
  /// restating it — the drift #6586 was about.
  static const int preWrapSeconds =
      _connectivityProbeSeconds +
      _sendPolicyCheckSeconds +
      _signerPubkeyRefreshSeconds;

  /// Bound on the connectivity probe. See [_connectivityProbeSeconds].
  static const Duration connectivityProbe = Duration(
    seconds: _connectivityProbeSeconds,
  );

  /// Bound on the send-policy check. See [_sendPolicyCheckSeconds].
  static const Duration sendPolicyCheck = Duration(
    seconds: _sendPolicyCheckSeconds,
  );

  /// Bound on the pre-wrap pubkey refresh. See [_signerPubkeyRefreshSeconds].
  static const Duration signerPubkeyRefresh = Duration(
    seconds: _signerPubkeyRefreshSeconds,
  );

  /// End-to-end bound on one recipient kind-10050 inbox resolution.
  ///
  /// Unlike everything else here this sits OUTSIDE
  /// [messagePublishTimeout] — resolution runs before the publish is wrapped.
  /// It is declared here anyway because `OutgoingDmRetryService` derives its
  /// interrupted-send guard from the pair, and the whole point of #6586 was
  /// that a guard restating a number drifts away from the thing it bounds.
  ///
  /// Read by `DmRepository.inboxResolutionBudget`.
  static const Duration inboxResolution = Duration(
    seconds: _dmInboxQuerySeconds + _inboxAdmissionSeconds,
  );

  /// The relay read inside a resolution, restated from
  /// `DmRepository._dmInboxQueryTimeout`.
  static const int _dmInboxQuerySeconds = 5;

  /// Room inside [inboxResolution] for the work around that read: the tag
  /// scan, relay admission, and the event-loop hops between them.
  static const int _inboxAdmissionSeconds = 2;

  /// Slack between [chainWorstCase] and [messagePublishTimeout].
  ///
  /// Absorbs event-loop scheduling, isolate hops, and the DAO work interleaved
  /// with the publish. The backstop must sit strictly above the capped worst
  /// case or it fires mid-send and misclassifies it — the #6586 defect.
  ///
  /// Trimmed twice: once by [_wrapBuildLocalCryptoSeconds] when that margin
  /// moved into [_recipientWrapBuildSeconds], and again by [preWrapSeconds]
  /// when the three pre-wrap steps were bounded and folded into
  /// [chainWorstCase] (#7091). Both trims keep [messagePublishTimeout] at the
  /// value it has shipped at, so the guard downstream does not move.
  ///
  /// Note the live send path reads `DmBatchSendBudget`, not this class —
  /// `DmRepository._messagePublishTimeout` and
  /// `OutgoingDmRetryService.interruptedMinAge` both key off that one. This
  /// class still bounds the legacy non-batch build.
  static const int _headroomSeconds = 15 - preWrapSeconds;

  /// Hard bound on building the recipient gift wrap.
  ///
  /// It bounds the *chain*, not the transport, and the chain's slowest signer
  /// sets its size. Two constants say so: [_boundedSignerFloorSeconds] is what
  /// Keycast can cost — two transport bounds plus the local crypto between
  /// them, so two ops that each returned inside the transport's limit cannot
  /// together trip this — and [_unboundedSignerHeadroomSeconds] is the room
  /// above that for signers with no transport bound at all. On the Amber
  /// NIP-55 intent path the `nip44Encrypt` and `signEvent` approval waits are
  /// human-gated and unbounded; timing out here leaves the recipient publish
  /// unsent, so durable callers classify the row as retryable-pending rather
  /// than red-failed.
  ///
  /// Tightening it below the floor is the specific mistake #6046 made and
  /// #6075 reverted — it fails sends the transport itself would have allowed.
  /// The app-layer guard test pins the floor because `dm_repository` cannot
  /// import `keycast_flutter` to check it here.
  ///
  /// #7092 re-derived the floor after Keycast's per-op bound dropped to 20s
  /// (keycast#351 bounds its own handler at 8s, so the ~20-30s single-op
  /// latency of keycast#291 that #6075 sized against is no longer reachable).
  /// The floor fell from 65s to 45s; this bound deliberately did not follow it
  /// down. See [_unboundedSignerHeadroomSeconds].
  static const Duration recipientWrapBuild = Duration(
    seconds: _recipientWrapBuildSeconds,
  );

  /// OK-confirmation window for the recipient wrap.
  ///
  /// The wait for that leg, reconnect included: with no relay connected and
  /// none named, `NostrClient.publishEventAwaitOk` spends it on the reconnect
  /// in front of the send first (#8451).
  ///
  /// Read by `NIP17MessageService._recipientOkConfirmTimeout`.
  static const Duration recipientOkConfirm = Duration(
    seconds: _recipientOkConfirmSeconds,
  );

  /// Hard bound on building the self-addressed gift wrap.
  ///
  /// Deliberately tighter than [recipientWrapBuild]. By the time this runs the
  /// recipient already has the message, and a missing self-wrap is an
  /// explicitly supported outcome: the send returns success with
  /// `selfWrapPublished: false`, the durable row survives, and the retry
  /// sweep's `recoverSelfWrap` arm finishes it out of band (#4124). Spending
  /// the recipient-sized budget here to avoid a *recovery step* would be the
  /// wrong trade — it would push the send past the backstop and misclassify a
  /// delivered message as unconfirmed, which is the #6586 failure itself.
  ///
  /// Applies only when the caller has an outer cap. Uncapped callers use
  /// [selfWrapUncappedBuild], which is sized differently for the reason
  /// documented there.
  static const Duration selfWrapBuild = Duration(
    seconds: _selfWrapBuildSeconds,
  );

  /// Hard bound on building the self-addressed gift wrap when the caller has no
  /// outer cap.
  ///
  /// Sized like [recipientWrapBuild], not like [selfWrapBuild]. The tightness
  /// of [selfWrapBuild] buys headroom inside [messagePublishTimeout]; uncapped
  /// callers have no outer budget to protect, so there a tight bound can only
  /// fail a build the transport itself would have completed.
  ///
  /// This covers out-of-band recovery (`NIP17MessageService.publishSelfWrap`,
  /// driven by `DmRepository.recoverSelfWrap`) and
  /// `NIP17MessageService.publishSelfApplicationMarker`. The build is the same
  /// two round trips, so at [selfWrapBuild] it could never finish against a
  /// signer running near its own 20s-per-op bound.
  ///
  /// It deliberately does **not** cover `sendPrivateMessage`, which builds its
  /// self wrap uncapped. A bound only makes sense where a timed-out build can
  /// still be finished later; that caller owns no `outgoing_dms` row, which
  /// `DmRepository.recoverSelfWrap` requires, so for it even this wide bound
  /// would drop the sender's cross-device copy permanently.
  ///
  /// Deliberately NOT part of [chainWorstCase]: callers that use this bound do
  /// not use the send-level [messagePublishTimeout] chain budget.
  static const Duration selfWrapUncappedBuild = Duration(
    seconds: _recipientWrapBuildSeconds,
  );

  /// Hard bound on publishing the self-addressed gift wrap.
  ///
  /// Read by `NIP17MessageService._selfWrapPublishTimeout`.
  static const Duration selfWrapPublish = Duration(
    seconds: _selfWrapPublishSeconds,
  );

  /// Serial worst case for the bounded portion of a send.
  ///
  /// Every step above runs in sequence on the remote-signer path, so the worst
  /// case is their sum.
  static const Duration chainWorstCase = Duration(
    seconds:
        preWrapSeconds +
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds,
  );

  /// Hard backstop on a single NIP-17 message publish.
  ///
  /// Derived, never hand-written. Callers that need to outlive an in-flight
  /// send must key off a backstop rather than restating a number — though the
  /// one they key off is `DmBatchSendBudget.messagePublishTimeout`, since that
  /// is what the send path actually uses. See
  /// `OutgoingDmRetryService.interruptedMinAge`.
  static const Duration messagePublishTimeout = Duration(
    seconds:
        preWrapSeconds +
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds +
        _headroomSeconds,
  );
}
