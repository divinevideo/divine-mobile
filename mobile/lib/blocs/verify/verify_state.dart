// ABOUTME: Immutable state for the verify dashboard — links, verdicts,
// ABOUTME: available platforms and the in-flight unlink.

part of 'verify_cubit.dart';

/// Order the platforms on offer are shown in.
///
/// The ones that link with a single sign-in come first, then the ones that
/// need a proof post — the cheap route should be the one people see first.
/// Which side a platform is on follows the verifier's answer
/// ([VerifierPlatform.supportsOAuth]), so a platform whose sign-in is off
/// moves to the proof-post side; this list orders each side. The verifier
/// returns `/platforms` in its own registry order, which carries no such
/// meaning, so the order is decided here.
///
/// A platform missing from this list still shows, after the ones listed.
const verifyPlatformOrder = <String>[
  // Can link with a sign-in, where the verifier has it on.
  'twitter',
  'bluesky',
  'tiktok',
  'youtube',
  // Proof post only.
  'discord',
  'telegram',
  'mastodon',
  'github',
];

/// Load state of the verify dashboard.
enum VerifyStatus {
  /// Nothing has been read yet.
  initial,

  /// A read is in flight.
  loading,

  /// Links and platforms are available.
  ready,

  /// The links could not be read.
  failure,
}

/// Transient failure category surfaced by the dashboard.
enum VerifyError {
  /// The links could not be read.
  load,

  /// The unlink did not land.
  remove,

  /// The claims already on the identity event could not be read, so writing
  /// would have dropped them.
  linksUnreadable,
}

/// State of the verify dashboard.
class VerifyState extends Equatable {
  /// Creates a [VerifyState].
  VerifyState({
    this.status = VerifyStatus.initial,
    List<IdentityClaim> claims = const [],
    Set<String> verifiedKeys = const {},
    List<VerifierPlatform> platforms = const [],
    this.verifierReachable = true,
    Map<String, SignInLapse> signInCodes = const {},
    this.removingKey,
    this.error,
    this.errorAttempt = 0,
  }) : claims = List.unmodifiable(claims),
       verifiedKeys = Set.unmodifiable(verifiedKeys),
       signInCodes = Map.unmodifiable(signInCodes),
       platforms = List.unmodifiable(platforms);

  /// Load state of the dashboard.
  final VerifyStatus status;

  /// Every claim on the identity event, verified or not.
  final List<IdentityClaim> claims;

  /// Lowercased `platform:identity` keys the verifier confirmed.
  final Set<String> verifiedKeys;

  /// Platforms the verifier currently accepts links for.
  final List<VerifierPlatform> platforms;

  /// False when the verifier could not be reached, or could not check a claim
  /// that therefore shows without a verdict. An unverified row may then mean
  /// "could not check" rather than "did not verify".
  final bool verifierReachable;

  /// The sign-in reason codes the verifier gave, by the same key as
  /// [verifiedKeys]. Can include a proof-post link on a platform with
  /// sign-in; read it through [signInLapse], which drops those.
  final Map<String, SignInLapse> signInCodes;

  /// Key of the claim currently being unlinked, if any.
  final String? removingKey;

  /// Paired with [errorAttempt] so repeated identical errors stay observable.
  final VerifyError? error;

  /// Bumped on every error emission.
  final int errorAttempt;

  /// Normalized `platform:identity` key of [claim].
  static String keyOf(IdentityClaim claim) =>
      '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}';

  /// Whether [claim] carries a positive verdict.
  bool isVerified(IdentityClaim claim) => verifiedKeys.contains(keyOf(claim));

  /// Whether to tell the user some verdicts are unknown: the verifier could
  /// not check everything, and a link still reads as unverified.
  bool get showsUncheckedNote =>
      !verifierReachable && claims.any((claim) => !isVerified(claim));

  /// Why the verifier stopped counting [claim] as a sign-in, if it said.
  ///
  /// Null for a proof-post link: the verifier can send a sign-in code for one
  /// on a platform with sign-in, and it stays on Verified / Not verified.
  SignInLapse? signInLapse(IdentityClaim claim) =>
      claim.proof == IdentityClaim.oauthProof
      ? signInCodes[keyOf(claim)]
      : null;

  /// Whether [claim] is the one currently being unlinked.
  bool isRemoving(IdentityClaim claim) => removingKey == keyOf(claim);

  /// Whether [claim] is a sign-in link the verifier stopped counting, on a
  /// platform whose sign-in is still on, so it can be renewed without
  /// unlinking it.
  ///
  /// Keyed on the verifier's own reason, which answers for this link alone:
  /// another link the verifier could not check does not hide it, and a link
  /// unverified for any other reason does not get it.
  bool canSignInAgain(IdentityClaim claim) {
    if (signInLapse(claim) == null || isVerified(claim)) return false;
    final platform = claim.platform.toLowerCase();
    return platforms.any(
      (offered) =>
          offered.key.toLowerCase() == platform && offered.supportsOAuth,
    );
  }

  /// Platforms that have no link yet: the ones offering a sign-in first,
  /// each side in [verifyPlatformOrder].
  ///
  /// A platform already linked is filtered out: linking a second account on
  /// the same platform would replace the first, which reads as losing a link
  /// rather than adding one. Unlink first.
  List<VerifierPlatform> get linkablePlatforms {
    final linked = {for (final claim in claims) claim.platform.toLowerCase()};
    final offered = [
      for (final platform in platforms)
        if (!linked.contains(platform.key.toLowerCase())) platform,
    ];
    // Within each side, anything the order does not name sorts after
    // everything it does, keeping the verifier's own order among its peers.
    // That tie-break is the arrival index rather than a reliance on
    // `List.sort` being stable, which Dart does not promise. [proofSide] is
    // above every rank a sign-in platform can get, so that side comes first.
    final proofSide = verifyPlatformOrder.length + offered.length;
    int rank(int arrivalIndex) {
      final platform = offered[arrivalIndex];
      final index = verifyPlatformOrder.indexOf(platform.key.toLowerCase());
      final inSide = index == -1
          ? verifyPlatformOrder.length + arrivalIndex
          : index;
      return platform.supportsOAuth ? inSide : proofSide + inSide;
    }

    final indices = List.generate(offered.length, (index) => index)
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return [for (final index in indices) offered[index]];
  }

  /// Copy of this state with the given fields replaced.
  VerifyState copyWith({
    VerifyStatus? status,
    List<IdentityClaim>? claims,
    Set<String>? verifiedKeys,
    List<VerifierPlatform>? platforms,
    bool? verifierReachable,
    Map<String, SignInLapse>? signInCodes,
    String? removingKey,
    VerifyError? error,
    int? errorAttempt,
    bool clearRemoving = false,
    bool clearError = false,
  }) {
    return VerifyState(
      status: status ?? this.status,
      claims: claims ?? this.claims,
      verifiedKeys: verifiedKeys ?? this.verifiedKeys,
      platforms: platforms ?? this.platforms,
      verifierReachable: verifierReachable ?? this.verifierReachable,
      signInCodes: signInCodes ?? this.signInCodes,
      removingKey: clearRemoving ? null : (removingKey ?? this.removingKey),
      error: clearError ? null : (error ?? this.error),
      errorAttempt: errorAttempt ?? this.errorAttempt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    claims,
    verifiedKeys,
    platforms,
    verifierReachable,
    signInCodes,
    removingKey,
    error,
    errorAttempt,
  ];
}
