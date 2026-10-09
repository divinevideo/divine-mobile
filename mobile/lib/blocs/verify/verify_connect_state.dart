// ABOUTME: Immutable state for linking one platform — the inputs, the stage
// ABOUTME: of the round trip, and why the last attempt did not land.

part of 'verify_connect_cubit.dart';

/// Stage of a single link attempt.
enum VerifyConnectStatus {
  /// Waiting on the user.
  editing,

  /// The OAuth browser session is open.
  authorizing,

  /// The verifier is checking the proof.
  verifying,

  /// The confirmed claim is being published to relays.
  publishing,

  /// The claim is live on the identity event.
  linked,
}

/// Why a link attempt did not land.
enum VerifyConnectError {
  /// The verifier refused the proof for a reason this build cannot name.
  ///
  /// The fallback for every unmapped or absent code, so its copy has to stay
  /// true of any rejection.
  proofRejected,

  /// The proof post exists and is the right account's, but has no npub in it.
  ///
  /// Named for the reason rather than the platform: every verifier looks for
  /// the npub in the post, so this copy is true on all of them.
  proofMissingNpub,

  /// The link points at a direct message, which no bot can read.
  discordDmLink,

  /// The link points at the channel rather than at a message in it.
  discordChannelLink,

  /// Discord has no such message, or it has since been deleted.
  discordMessageNotFound,

  /// The bot cannot see the channel the message was posted in.
  discordBotNoAccess,

  /// The message exists but somebody else wrote it.
  discordAuthorMismatch,

  /// The message exists and its text came back empty, which is our own
  /// misconfiguration rather than anything the user did.
  discordContentUnavailable,

  /// The verifier was unreachable, or could not check the claim right now.
  verifierUnreachable,

  /// The OAuth round trip ended without a usable confirmation.
  oauthFailed,

  /// The Telegram link points at a private channel or an invite, neither of
  /// which the verifier can read.
  telegramNotPublic,

  /// This verifier deployment has no credentials for the platform's OAuth
  /// login, so only the proof post can link it.
  oauthUnavailable,

  /// Bluesky needs the handle before its OAuth flow can start.
  handleRequired,

  /// The claim verified, but no relay accepted the identity event.
  publishFailed,

  /// The claims already on the identity event could not be read, so writing
  /// would have dropped them.
  linksUnreadable,
}

/// State of a single platform link attempt.
class VerifyConnectState extends Equatable {
  /// Creates a [VerifyConnectState] for [platform].
  const VerifyConnectState({
    required this.platform,
    this.status = VerifyConnectStatus.editing,
    this.identity = '',
    this.proof = '',
    this.error,
    this.errorAttempt = 0,
    this.linkedClaim,
  });

  /// The platform being linked.
  final VerifierPlatform platform;

  /// Stage of the current attempt.
  final VerifyConnectStatus status;

  /// Account handle or id the user is claiming.
  final String identity;

  /// Proof URL or id backing a proof-post claim.
  final String proof;

  /// Paired with [errorAttempt] so repeated identical errors stay observable.
  final VerifyConnectError? error;

  /// Bumped on every error emission.
  final int errorAttempt;

  /// The claim that landed, once [status] is [VerifyConnectStatus.linked].
  ///
  /// Handed back to the dashboard so the new row is drawn from what was
  /// actually published, rather than from a relay reread that may not serve
  /// the event back yet.
  final IdentityClaim? linkedClaim;

  /// Whether an attempt currently owns the flow.
  bool get isBusy =>
      status == VerifyConnectStatus.authorizing ||
      status == VerifyConnectStatus.verifying ||
      status == VerifyConnectStatus.publishing;

  /// Whether this platform offers an OAuth login.
  bool get supportsOAuth => platform.supportsOAuth;

  /// Platforms whose proof link never carries the account, so it has to be
  /// typed.
  ///
  /// A Discord message URL names a guild, a channel and a message but never
  /// the author; a YouTube URL names the video, not the channel. Bluesky is
  /// here for a different reason: its handle is needed before any post
  /// exists, both to start the OAuth flow and to check an identity-link
  /// record without a proof post.
  static const _typedIdentityPlatforms = {'discord', 'youtube', 'bluesky'};

  /// Whether to ask for the account separately.
  ///
  /// For everything else the handle is already in the link the user pastes —
  /// asking twice invites the mismatch that a channel link makes so easy
  /// (the channel is the author, not the person pasting). The field comes
  /// back if what they pasted turns out not to be a link we can read.
  bool get needsIdentityInput {
    if (_typedIdentityPlatforms.contains(platform.key.toLowerCase())) {
      return true;
    }
    return proof.isNotEmpty &&
        (identity.isNotEmpty || normalizedInput.identity.isEmpty);
  }

  /// The inputs as the verifier wants them — a pasted post link taken apart
  /// into a handle and a bare id.
  ///
  /// Computed rather than written back into the fields: rewriting what someone
  /// pasted while they are still looking at it is worse than accepting it.
  VerifyProofInput get normalizedInput => normalizeVerifyProof(
    platform: platform.key,
    identity: identity,
    proof: proof,
  );

  /// Whether the proof-post form has enough to submit.
  ///
  /// Judged on [normalizedInput], so pasting a link that already carries the
  /// handle is enough on its own.
  ///
  /// Bluesky is the exception the verifier itself makes: it can confirm a
  /// handle from an AT Protocol identity-link record, so an empty proof is a
  /// valid request there and nowhere else.
  bool get canSubmitProof {
    final input = normalizedInput;
    // A recognisably unusable link stays submittable on purpose: pressing it
    // is how the user hears what is wrong with it. A dead button explains
    // nothing.
    if (input.problem != null) return true;
    if (input.identity.isEmpty) return false;
    if (platform.key == 'bluesky') return true;
    return input.proof.isNotEmpty;
  }

  /// Copy of this state with the given fields replaced.
  VerifyConnectState copyWith({
    VerifyConnectStatus? status,
    String? identity,
    String? proof,
    VerifyConnectError? error,
    int? errorAttempt,
    IdentityClaim? linkedClaim,
    bool clearError = false,
  }) {
    return VerifyConnectState(
      platform: platform,
      status: status ?? this.status,
      identity: identity ?? this.identity,
      proof: proof ?? this.proof,
      error: clearError ? null : (error ?? this.error),
      errorAttempt: errorAttempt ?? this.errorAttempt,
      linkedClaim: linkedClaim ?? this.linkedClaim,
    );
  }

  @override
  List<Object?> get props => [
    platform,
    status,
    identity,
    proof,
    error,
    errorAttempt,
    linkedClaim,
  ];
}
