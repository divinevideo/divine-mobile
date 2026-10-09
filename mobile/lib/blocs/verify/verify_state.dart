// ABOUTME: Immutable state for the verify dashboard — links, verdicts,
// ABOUTME: available platforms and the in-flight unlink.

part of 'verify_cubit.dart';

/// Order the platforms on offer are shown in.
///
/// The ones that link with a single sign-in come first, then the ones that
/// need a proof post — the cheap route should be the one people see first.
/// The verifier returns `/platforms` in its own registry order, which carries
/// no such meaning, so the order is decided here.
///
/// A platform missing from this list still shows, after the ones listed.
const verifyPlatformOrder = <String>[
  // One tap.
  'twitter',
  'bluesky',
  'tiktok',
  'youtube',
  // Proof post.
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
    this.removingKey,
    this.error,
    this.errorAttempt = 0,
  }) : claims = List.unmodifiable(claims),
       verifiedKeys = Set.unmodifiable(verifiedKeys),
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

  /// Whether [claim] is the one currently being unlinked.
  bool isRemoving(IdentityClaim claim) => removingKey == keyOf(claim);

  /// Platforms that have no link yet, in [verifyPlatformOrder].
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
    // Anything the order does not name sorts after everything it does, keeping
    // the verifier's own order among its peers. That tie-break is the arrival
    // index rather than a reliance on `List.sort` being stable, which Dart
    // does not promise.
    int rank(int arrivalIndex) {
      final key = offered[arrivalIndex].key.toLowerCase();
      final index = verifyPlatformOrder.indexOf(key);
      return index == -1 ? verifyPlatformOrder.length + arrivalIndex : index;
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
    removingKey,
    error,
    errorAttempt,
  ];
}
