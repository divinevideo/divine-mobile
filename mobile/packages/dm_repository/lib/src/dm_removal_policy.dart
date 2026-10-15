// ABOUTME: Injectable conversation-removal policy for DmRepository (#8391). The
// ABOUTME: DM package can't reach app config, so "which peers hold a thread the
// ABOUTME: user may not delete" is injected as a predicate the removal
// ABOUTME: primitives consult.

/// What `DmRepository.removeConversation` did to one conversation.
///
/// Two-valued rather than a `bool`, and returned rather than thrown, because a
/// refusal is not a failure: per `.claude/rules/error_handling.md` a policy
/// refusal must not reach the error path, and the caller must be able to say
/// "this one is protected" without reporting that something went wrong. Drift
/// failures still throw.
enum ConversationRemovalOutcome {
  /// The conversation was removed (or was already absent — see the fail-open
  /// note on `DmRepository.removeConversation`).
  removed,

  /// The policy protects this conversation. Nothing was deleted.
  refused,
}

/// Whether a conversation with [peerPubkeyHex] is one the user may not remove.
///
/// Injected rather than imported so this package never learns Divine's own
/// pubkeys: `official_accounts.dart` is app config and this package is reusable
/// without it. Same reasoning as `DmSendPolicy` alongside it, and as the
/// `supportPubkey` parameter on `DmRepository.extractPinnedSupport`.
///
/// Synchronous, unlike `DmSendPolicy`: removal protection is pure set
/// membership over shipped identities, with no account state to await.
///
/// The predicate answers about a *peer*. `DmRepository` owns excluding self and
/// applying it to one-to-ones only, so no caller can get either wrong: a room's
/// members are whoever its author named, so a room is never protected.
typedef DmConversationRemovalPolicy = bool Function(String peerPubkeyHex);

/// Default policy: nothing is protected. Preserves existing behaviour wherever
/// no policy is injected, so a fixture that wires nothing behaves exactly as it
/// did before the policy existed.
bool allowAllConversationRemoval(String peerPubkeyHex) => false;
