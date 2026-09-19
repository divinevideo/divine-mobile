// ABOUTME: Why a kind-22236 view event was not published to the relay.
// ABOUTME: Separates expected skips from defects so only defects alarm.

/// Why a kind-22236 view event was not published.
///
/// `publishViewEvent` returning `false` on its own cannot distinguish a view
/// that was correctly skipped from one the client failed to build. Both are
/// silent, but only the second is a bug — so the two must be told apart at
/// the point of the drop rather than inferred from log volume later.
enum ViewEventDropReason {
  /// No usable watched range: it ended before it started, or no usable
  /// segment was supplied.
  invalidWatchRange,

  /// No signed-in identity, so nothing could sign the event.
  notAuthenticated,

  /// An identity is signed in but cannot sign yet.
  ///
  /// A Keycast identity with no local key reaches `AuthState.authenticated`
  /// before its signer is usable, so [notAuthenticated] never fires for the
  /// cold-start window between the two.
  signerNotReady,

  /// The video carried no addressable `d` tag, so no `a` tag could be built.
  missingAddressableDTag,

  /// The video kind is not addressable, so it cannot be cited by an `a` tag.
  nonAddressableVideoKind,

  /// The signer reported it was ready but produced no event.
  ///
  /// `SignerFactory.createAndSignEvent` answers null for three things: an
  /// invariant it has already reported itself (account mismatch, an event
  /// that fails post-signing validation, an `Error`), a remote signer whose
  /// network call failed (a Keycast RPC timeout or 5xx, no connection), or a
  /// NIP-55 prompt the user declined. A local key signer never returns null.
  /// None of those is a view-event defect, and the durable queue keeps the
  /// row for a later sweep (#9340).
  signingFailed,

  /// An unexpected exception interrupted event construction or publishing.
  unexpectedError,

  /// The event was built and signed but the relay publish did not succeed.
  relayRejected;

  /// Whether this drop indicates a defect rather than an expected skip.
  ///
  /// Structural drops should never occur: by the time they are reached the
  /// caller has already decided this view is worth publishing, so failing to
  /// build or sign the event means the client is broken. They are reported.
  ///
  /// Expected skips are high-volume and routine. Reporting them would bury
  /// the defects, so they stay silent — see `.claude/rules/error_handling.md`.
  /// [relayRejected] is deliberately not structural: the event was well
  /// formed and the failure is a network or relay condition, which the
  /// durable queue already retries.
  ///
  /// [invalidWatchRange] is structural. Since view = playback start there is
  /// no minimum watch time left to fall below, so reaching it means the
  /// caller supplied a range that ends before it starts, or no segment it
  /// could use at all.
  ///
  /// [signerNotReady] is not structural: identity known is not signer ready
  /// (see `.claude/rules/state_management.md`), and the gap resolves itself
  /// once the signer warms up.
  ///
  /// [signingFailed] is not structural either. The signer factory reports
  /// the genuine invariants behind a null itself, so filing the drop here
  /// only added the expected remote-signer failures — once per queued row
  /// per retry sweep, which made it the top non-fatal on both platforms
  /// (#9340).
  bool get isStructural => switch (this) {
    ViewEventDropReason.invalidWatchRange => true,
    ViewEventDropReason.notAuthenticated => false,
    ViewEventDropReason.signerNotReady => false,
    ViewEventDropReason.missingAddressableDTag => true,
    ViewEventDropReason.nonAddressableVideoKind => false,
    ViewEventDropReason.signingFailed => false,
    ViewEventDropReason.unexpectedError => true,
    ViewEventDropReason.relayRejected => false,
  };
}

/// A view event the client decided to publish but could not construct.
///
/// Wrap with `Reportable` at the call site so Crashlytics groups on this type
/// and the identifier sanitiser runs.
class ViewEventInvariantException implements Exception {
  /// Creates an invariant violation for [reason].
  const ViewEventInvariantException(this.reason);

  /// The structural reason the event could not be published.
  final ViewEventDropReason reason;

  @override
  String toString() => 'ViewEventInvariantException(${reason.name})';
}
