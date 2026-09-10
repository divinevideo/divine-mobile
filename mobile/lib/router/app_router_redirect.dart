// ABOUTME: Top-level GoRouter redirect + its auth/minor-review helpers and flags
// ABOUTME: `part of` app_router.dart so it shares the library-private navigation flags

part of 'app_router.dart';

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;
bool _suppressNextAuthenticatedAuthRouteRedirect = false;

/// Sends profile routes to the wrapper that owns their action surface.
@visibleForTesting
String? profileOwnerRedirectTarget({
  required String location,
  required String? currentPublicKeyHex,
}) {
  if (currentPublicKeyHex == null || currentPublicKeyHex.isEmpty) return null;

  final route = parseKnownRoute(location);
  final npub = route?.npub;
  if (npub == null || npub.isEmpty) return null;
  final targetHex = npubToHexOrNull(npub);
  if (npub != 'me' && (targetHex == null || targetHex.length != 64)) {
    return null;
  }

  final isOwnProfile = routeIdentifiesUser(npub, currentPublicKeyHex);
  return switch (route?.type) {
    RouteType.profile when !isOwnProfile => OtherProfileScreen.pathForNpub(
      npub,
    ),
    RouteType.profileView when isOwnProfile => ProfileScreenRouter.pathForNpub(
      npub,
    ),
    _ => null,
  };
}

@visibleForTesting
bool accountDeletionRecoveryGateActive(
  AsyncValue<AccountDeletionAttempt?>? attempt, {
  SubmittedAccountDeletionAttempt? submittedAttempt,
  AuthState? authState,
  String? currentPubkeyHex,
}) {
  if (attempt == null || !attempt.hasValue) return false;
  if (authState == AuthState.authenticated &&
      submittedAttempt != null &&
      submittedAttempt.pubkeyHex != currentPubkeyHex &&
      attempt.value?.id == submittedAttempt.attempt.id) {
    return false;
  }
  return attempt.value?.requiresRecoveryScreen ?? false;
}

/// Whether the deletion lookup is still in flight for cold-start routing.
///
/// The router fails open while this is true so it never paints the recovery
/// screen without evidence of an interrupted deletion. The native startup
/// splash uses [authenticatedDeletionLookupSettled] and only waits for this
/// lookup when a matching durable deletion receipt exists.
///
/// Any in-flight load counts as pending, including the first post-auth refetch:
/// that re-run retains the pre-auth `AsyncData(null)`, so it is `isLoading`
/// while `hasValue` is true. Excluding it would settle against the stale null
/// and release a receipt-backed splash early.
bool accountDeletionRecoveryLookupPending(
  AsyncValue<AccountDeletionAttempt?>? attempt,
) => attempt == null || attempt.isLoading;

bool authenticatedDeletionLookupSettled(
  AuthState authState,
  AsyncValue<AccountDeletionAttempt?>? attempt, {
  SubmittedAccountDeletionAttempt? submittedAttempt,
  String? currentPubkeyHex,
}) =>
    authState == AuthState.authenticated &&
    (submittedAttempt == null ||
        submittedAttempt.pubkeyHex != currentPubkeyHex ||
        !accountDeletionRecoveryLookupPending(attempt));

/// Prevents the next authenticated auth-route redirect from going home.
///
/// Used when a cold-start quick action already opened a protected route before
/// auth restoration finishes. In that case the route should remain visible
/// instead of being covered by the normal `/welcome` -> home redirect.
void suppressNextAuthenticatedAuthRouteRedirect() {
  _suppressNextAuthenticatedAuthRouteRedirect = true;
}

/// Clears a pending authenticated auth-route redirect suppression.
void clearAuthenticatedAuthRouteRedirectSuppression() {
  _suppressNextAuthenticatedAuthRouteRedirect = false;
}

/// Where a `divine://` location resolves, and whether [appRouterRedirect]'s
/// gates still apply to it.
///
/// `gated: false` is reserved for the live NIP-46 pairing return.
/// `/nostr-connect` is an auth route, so running it through the
/// authenticated-auth-route bounce would pull a signed-in user straight out of
/// the pairing they just approved. Every other outcome is an ordinary
/// destination and must be gated like any other location.
typedef DivineSchemeTarget = ({String path, bool gated});

/// Where a `divine://` location has to go. Returns null for every other scheme.
///
/// This must never return null for a `divine://` URI. GoRouter matches a
/// location by `uri.path` alone — scheme and host are never consulted — so
/// falling through here does not mean "nothing happens", it means every one of
/// the app's registered routes becomes openable by any app on the device.
/// `divine:///developer-options` reaching the relay environment switcher is the
/// worked example (#7074).
///
/// Resolving to a path is not the same as being allowed to reach it: the
/// returned [DivineSchemeTarget.path] is a *destination*, which
/// [appRouterRedirect] then runs through the auth and minor-account-review
/// gates unless [DivineSchemeTarget.gated] is false.
@visibleForTesting
DivineSchemeTarget? divineSchemeRedirectTarget(
  Uri uri,
  AuthService authService,
) {
  if (uri.scheme != 'divine') {
    return null;
  }

  // Allow-listed app routes first, so the reported location stays clean
  // (/saved-videos, not divine:///saved-videos) for analytics, route
  // normalization, and the deep-link listener's currentLocation comparison.
  final appRoute = customSchemeToRouterPath(uri);
  if (appRoute != null) {
    return (path: appRoute, gated: true);
  }

  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  if (deepLink.type == DeepLinkType.signerCallback) {
    // The app-links stream handles this too, but GoRouter may see Android
    // custom-scheme callbacks first. Keep this idempotent: it only preserves
    // an already-listening NIP-46 session while routing back to its screen.
    authService.onSignerCallbackReceived(
      relayUrl: deepLink.signerCallbackRelay,
    );
    if (authService.nostrConnectUrl != null) {
      return (path: NostrConnectScreen.path, gated: false);
    }
  }

  // Either a stray callback (stale signer return, expired session, another app
  // probing the scheme) or a URI naming a route that is not allow-listed.
  //
  // Send a signed-in user home rather than to /welcome, which would leave them
  // on the account picker and read as a lost session. This is a destination
  // like any other, so the gates below still get to move them off it.
  return (
    path: authService.authState == AuthState.authenticated
        ? VideoFeedPage.pathForIndex(0)
        : WelcomeScreen.path,
    gated: true,
  );
}

/// Reset navigation state for testing purposes
@visibleForTesting
void resetNavigationState() {
  _hasNavigated = false;
  _suppressNextAuthenticatedAuthRouteRedirect = false;
}

String _minorAccountReviewLoadingPath(String fromLocation) {
  return Uri(
    path: MinorAccountReviewLoadingScreen.path,
    queryParameters: <String, String>{'from': fromLocation},
  ).toString();
}

@visibleForTesting
String minorAccountReviewReturnLocationForTest(Uri uri) {
  final from = uri.queryParameters['from'];
  if (from == null || from.isEmpty) {
    return VideoFeedPage.pathForIndex(0);
  }

  final fromLocation = Uri.parse(from).path;
  if (_isAuthEntryLocation(fromLocation) ||
      fromLocation == MinorAccountReviewLoadingScreen.path) {
    return VideoFeedPage.pathForIndex(0);
  }

  return from;
}

String _minorAccountReviewReturnLocation(GoRouterState state) {
  return minorAccountReviewReturnLocationForTest(state.uri);
}

String? _moderationConversationId(
  AuthService authService,
  MinorReviewCase? reviewCase,
) {
  if (reviewCase == null) return null;
  if (reviewCase.moderationConversationId != null &&
      reviewCase.moderationConversationId!.isNotEmpty) {
    return reviewCase.moderationConversationId;
  }

  final currentPubkey = authService.currentPublicKeyHex;
  final moderationPubkey = reviewCase.moderationConversationPubkey;
  if (currentPubkey == null ||
      currentPubkey.isEmpty ||
      moderationPubkey == null ||
      moderationPubkey.isEmpty) {
    return null;
  }

  return DmRepository.computeConversationId([currentPubkey, moderationPubkey]);
}

bool _isAuthEntryLocation(String location) {
  return location == WelcomeScreen.path ||
      location.startsWith('${WelcomeScreen.path}/') ||
      location.startsWith(KeyImportScreen.path) ||
      location.startsWith(NostrConnectScreen.path) ||
      location == WelcomeScreen.inviteGatePath ||
      location.startsWith(WelcomeScreen.resetPasswordPath) ||
      location.startsWith(ResetPasswordScreen.path) ||
      location.startsWith(EmailVerificationScreen.path) ||
      location == MinorAccountReviewScreen.welcomePath ||
      location == MinorAccountReviewParentConsentScreen.path ||
      location == MinorAccountReviewUnder13Screen.path;
}

bool _isPublicRecorderLocation(String location) =>
    location == VideoRecorderScreen.path ||
    location.startsWith('${VideoRecorderScreen.path}?');

/// The slice of [MinorAccountReviewStatus] (plus its async loading shape)
/// that [appRouterRedirect] actually branches on. Two emissions with an
/// equal signature always produce the same redirect decision.
///
/// Keep this in sync with the review-status reads in [appRouterRedirect]: if
/// the redirect starts branching on another field, add it here or the refresh
/// gate will swallow genuine changes to it. The coupling is guarded by
/// `test/router/router_refresh_gate_coupling_test.dart`.
typedef _MinorReviewRoutingSignature = ({
  bool loadingWithoutValue,
  bool isRestricted,
  bool hasCase,
  String? moderationConversationPubkey,
  String? moderationConversationId,
  bool allowsParentVideoOrEmail,
});

_MinorReviewRoutingSignature _minorReviewRoutingSignature(
  AsyncValue<MinorAccountReviewStatus>? status,
) {
  // `value` (not `asData?.value`) mirrors `appRouterRedirect`, which reads the
  // previous value that Riverpod carries through a background refetch.
  final review = status?.value;
  final reviewCase = review?.currentCase;
  return (
    loadingWithoutValue:
        (status?.isLoading ?? false) && !(status?.hasValue ?? false),
    isRestricted: review?.isRestricted ?? false,
    hasCase: reviewCase != null,
    moderationConversationPubkey: reviewCase?.moderationConversationPubkey,
    moderationConversationId: reviewCase?.moderationConversationId,
    allowsParentVideoOrEmail: reviewCase?.allowsParentVideoOrEmail ?? false,
  );
}

/// Whether a review-status emission can change the router's redirect outcome.
///
/// The router refreshes on every [currentMinorAccountReviewStatusProvider]
/// emission, but a background/resume refetch usually resolves to a routing-
/// identical value (active → active). Refreshing for those churns the whole
/// route pipeline while a video reel is pushed on top — reverting the reported
/// location to the shell branch and firing a spurious `didPushNext` that pauses
/// and tears down the reel's just-created player mid-initialization. Gating the
/// refresh on this predicate keeps genuine restriction flips reactive while
/// leaving an already-open reel untouched.
///
/// [previous] is nullable only for defensiveness and the first-emission tests;
/// the production `ref.listen` at [goRouterProvider] omits `fireImmediately`,
/// so Riverpod only ever invokes it with a real prior [AsyncValue].
@visibleForTesting
bool minorAccountReviewStatusAffectsRouting(
  AsyncValue<MinorAccountReviewStatus>? previous,
  AsyncValue<MinorAccountReviewStatus> next,
) {
  return _minorReviewRoutingSignature(previous) !=
      _minorReviewRoutingSignature(next);
}

/// Top-level GoRouter redirect: divine:// scheme → universal-link rewrite →
/// minor-account-review gating → auth-route gating → unauthenticated gating.
///
/// The order of these checks is load-bearing; reordering risks the
/// loading-screen ↔ review-screen loop (issue #5195) or feeding an
/// un-rewritten universal-link URL into the matcher (Page Not Found).
///
/// Both deep-link steps resolve a destination and then *keep going*, so the
/// gating below still applies to them. go_router calls this at most once per
/// navigation, so returning a destination early would put the caller past
/// every gate — see [divineSchemeRedirectTarget] and
/// [universalLinkToRouterPath].
String? appRouterRedirect(Ref ref, GoRouterState state) {
  final authService = ref.read(authServiceProvider);

  // Resolve a divine:// location to the internal path it addresses — but do
  // not return it here.
  //
  // go_router runs this top-level redirect at most once per navigation and
  // does not re-evaluate what it redirects to
  // (`RouteConfiguration.applyTopLegacyRedirect`). Returning a destination
  // from this point is therefore terminal, and terminal means every gate
  // below is skipped: a restricted-minor account reached the feed by opening
  // any divine:// URI, and a signed-out user reached /saved-videos and
  // /video/:id. Carry the destination down to the gates instead and let them
  // have the last word.
  final divineScheme = divineSchemeRedirectTarget(state.uri, authService);
  if (divineScheme != null) {
    Log.info(
      'Router redirect: divine scheme '
      '${redactUriStringForLogs(state.uri.toString())} -> '
      '${divineScheme.path}${divineScheme.gated ? '' : ' (ungated)'}',
      name: 'AppRouter',
      category: LogCategory.auth,
    );
    if (!divineScheme.gated) {
      return divineScheme.path;
    }
  }

  // Rewrite divine.video universal-link URLs to internal paths before the
  // auth/match logic runs. Android delivers the full intent URL (scheme +
  // host + path) to GoRouter, which only matches on path. Without this
  // step, paths that differ between the public URL contract and the
  // internal route table (notably `/search/*` → `/search-results/:query`)
  // would fall through to GoRouter's "Page Not Found" page.
  //
  // Resolved here but not returned, for the same reason as the divine://
  // step above. Returning it was terminal, and terminal meant a
  // restricted-minor account reached /profile, /hashtag, /search and /list by
  // opening the https link instead of navigating to the path (#7146).
  final universalRedirect = universalLinkToRouterPath(state.uri);
  if (universalRedirect != null) {
    Log.info(
      'Router redirect: universal link '
      '${redactUriStringForLogs(state.uri.toString())} → $universalRedirect',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
  }

  // Non-null only for a deep link whose destination still has to clear the
  // gates. The two resolvers are mutually exclusive — one matches `divine://`
  // and the other `http(s)://` — so at most one is ever set. Every
  // `return deepLinkRewrite` below is a plain `return null` for ordinary
  // in-app navigation, so nothing changes off the deep-link path.
  final deepLinkRewrite = divineScheme?.path ?? universalRedirect;

  final location = deepLinkRewrite ?? state.matchedLocation;
  final authState = authService.authState;

  // Screenshot capture runs drive each screen via an imperative
  // `router.go(screenshotRoute)`. Once authenticated, suppress all redirect
  // gating (minor-account-review interstitial, empty-following bounce) so
  // the router honors that route instead of resolving to the home feed.
  // Only bypass when a capture route is actually set — otherwise fall
  // through so an authenticated launch with no route still leaves /welcome
  // for the home feed. Compile-time false outside SCREENSHOT_MODE debug
  // builds.
  if (ScreenshotMode.enabled &&
      authState == AuthState.authenticated &&
      ScreenshotMode.initialRoute != null) {
    return deepLinkRewrite;
  }

  final reviewStatusAsync = ref.read(currentMinorAccountReviewStatusProvider);
  final deletionAttemptAsync = ref.read(currentAccountDeletionAttemptProvider);
  final submittedDeletion =
      authState == AuthState.authenticated &&
          deletionAttemptAsync.value?.requiresRecoveryScreen == true
      ? ref.read(submittedAccountDeletionAttemptProvider)
      : null;
  final deletionRecoveryGateActive = accountDeletionRecoveryGateActive(
    deletionAttemptAsync,
    submittedAttempt: submittedDeletion,
    authState: authState,
    currentPubkeyHex: authService.currentPublicKeyHex,
  );
  final reviewStatus = reviewStatusAsync.value;
  final moderationConversationId = _moderationConversationId(
    authService,
    reviewStatus?.currentCase,
  );

  final isReviewRoute = location == MinorAccountReviewScreen.path;
  final isDeletionRecoveryRoute =
      location == AccountDeletionRecoveryScreen.path;
  final isPublicReviewRoute = location == MinorAccountReviewScreen.welcomePath;
  final isReviewLoadingRoute = location == MinorAccountReviewLoadingScreen.path;
  final isPublicParentConsentRoute =
      location == MinorAccountReviewParentConsentScreen.path;
  final isParentContactRoute =
      location == MinorAccountReviewParentContactScreen.path;
  final isPublicUnder13Route = location == MinorAccountReviewUnder13Screen.path;
  final isUnder13SupportRoute =
      location == MinorAccountReviewUnder13SupportScreen.path;
  final isSupportRoute =
      location == SupportCenterScreen.path ||
      location == BugReportScreen.path ||
      location == FeatureRequestScreen.path;
  final isPublicSupportRoute = location == SupportCenterScreen.path;
  final isModerationConversationRoute =
      moderationConversationId != null &&
      location == ConversationPage.pathForId(moderationConversationId);

  Log.debug(
    'Router redirect: location=$location, '
    'authState=${authState.name}',
    name: 'AppRouter',
    category: LogCategory.auth,
  );

  // Auth routes don't require authentication — user is in the
  // process of logging in.
  final isAuthRoute = _isAuthEntryLocation(location);

  if (deletionRecoveryGateActive &&
      !isDeletionRecoveryRoute &&
      !isSupportRoute &&
      !(authState != AuthState.authenticated && isAuthRoute)) {
    return AccountDeletionRecoveryScreen.path;
  }
  if (!deletionRecoveryGateActive && isDeletionRecoveryRoute) {
    return authState == AuthState.authenticated
        ? VideoFeedPage.pathForIndex(0)
        : WelcomeScreen.path;
  }

  // Only bounce to the loading screen on a true cold load (no value yet).
  // Riverpod keeps the previous value during a background refetch
  // (isLoading == true while hasValue == true), e.g. when
  // currentAuthStateProvider re-invalidates on an authStateStream event.
  // Treating those transient refetches as "loading" would redirect away
  // from the current route to the review loading screen and back, which
  // tears down and rebuilds the video feed.
  if (authState == AuthState.authenticated &&
      reviewStatusAsync.isLoading &&
      !reviewStatusAsync.hasValue) {
    if (!isReviewLoadingRoute) {
      // Hand the loading screen the rewritten path, not the raw divine:// URI:
      // it round-trips through `from` and re-entering the scheme handling on
      // the way back would resolve it a second time.
      return _minorAccountReviewLoadingPath(
        deepLinkRewrite ?? state.uri.toString(),
      );
    }
    return deepLinkRewrite;
  }

  if (authState == AuthState.authenticated && isReviewLoadingRoute) {
    // Only route to the restricted-account screen once the backend has
    // *confirmed* a restriction. If the status could not be fetched
    // (a non-404/501 API failure surfaces here as AsyncError), fail open
    // and return the user to their destination instead of stranding them
    // on the review screen — an account whose restriction we cannot prove
    // must not be treated as restricted, and bouncing an errored status
    // through the review screen risks a loading-screen ↔ review-screen
    // loop (issue #5195).
    if (reviewStatus?.isRestricted == true) {
      return MinorAccountReviewScreen.path;
    }
    return _minorAccountReviewReturnLocation(state);
  }

  if (authState == AuthState.authenticated &&
      reviewStatus?.isRestricted != true &&
      (isReviewRoute || isParentContactRoute || isUnder13SupportRoute)) {
    return VideoFeedPage.pathForIndex(0);
  }

  if (authState == AuthState.authenticated &&
      reviewStatus?.isRestricted == true) {
    final reviewCase = reviewStatus?.currentCase;
    if (isParentContactRoute) {
      if (reviewCase == null) {
        return MinorAccountReviewScreen.path;
      }
      if (!reviewCase.allowsParentVideoOrEmail) {
        return MinorAccountReviewUnder13SupportScreen.path;
      }
    }

    if (!isReviewRoute &&
        !isParentContactRoute &&
        !isUnder13SupportRoute &&
        !isSupportRoute &&
        !isModerationConversationRoute &&
        !isPublicReviewRoute &&
        !isPublicParentConsentRoute &&
        !isPublicUnder13Route) {
      Log.info(
        'Router redirect: restricted account on $location — '
        'redirecting to ${MinorAccountReviewScreen.path}',
        name: 'AppRouter',
        category: LogCategory.auth,
      );
      return MinorAccountReviewScreen.path;
    }
  }

  // Handle authenticated users on auth routes
  // Note: resetPasswordPath and EmailVerificationScreen are intentionally
  // excluded — authenticated users may navigate there via deep links.
  if (authState == AuthState.authenticated &&
      (location == WelcomeScreen.path ||
          location == NostrConnectScreen.path ||
          location == WelcomeScreen.inviteGatePath ||
          location == WelcomeScreen.createAccountPath ||
          location == WelcomeScreen.loginOptionsPath)) {
    // Allow expired-session users through to login options
    // so they can re-authenticate instead of being bounced home
    if (authService.hasExpiredOAuthSession &&
        location == WelcomeScreen.loginOptionsPath) {
      return deepLinkRewrite;
    }
    // Allow an anonymously-authenticated user through to login options when
    // they arrive from the Secure account key-conflict recovery flow, which
    // deep-links here with a prefilled `email` param. Without this they would
    // be bounced to the feed and the "sign in to the existing account"
    // recovery affordance would dead-end.
    if (authService.isAnonymous &&
        location == WelcomeScreen.loginOptionsPath &&
        state.uri.queryParameters.containsKey('email')) {
      return deepLinkRewrite;
    }
    if (_suppressNextAuthenticatedAuthRouteRedirect) {
      _suppressNextAuthenticatedAuthRouteRedirect = false;
      Log.info(
        'Router redirect: authenticated on auth route — '
        'staying on quick-action route instead of redirecting home',
        name: 'AppRouter',
        category: LogCategory.auth,
      );
      return deepLinkRewrite;
    }
    // On first navigation, redirect to explore if user has no following
    if (!_hasNavigated) {
      _hasNavigated = true;
      final emptyFollowingRedirect = ref.read(
        checkEmptyFollowingRedirectProvider(location),
      );
      if (emptyFollowingRedirect != null) {
        Log.info(
          'Router redirect: authenticated on auth route — '
          'redirecting to $emptyFollowingRedirect (no following)',
          name: 'AppRouter',
          category: LogCategory.auth,
        );
        return emptyFollowingRedirect;
      }
    }
    return VideoFeedPage.pathForIndex(0);
  }

  // Non-authenticated users on protected routes → welcome.
  // awaitingTosAcceptance has no dedicated screen, so treat it like
  // unauthenticated.
  if (!isAuthRoute &&
      !isDeletionRecoveryRoute &&
      !isPublicSupportRoute &&
      !_isPublicRecorderLocation(location) &&
      (authState == AuthState.unauthenticated ||
          authState == AuthState.awaitingTosAcceptance)) {
    _hasNavigated = false;
    Log.info(
      'Router redirect: ${authState.name} on $location — '
      'redirecting to ${WelcomeScreen.path}',
      name: 'AppRouter',
      category: LogCategory.auth,
    );
    return WelcomeScreen.path;
  }

  if (authState == AuthState.authenticated) {
    final profileRedirect = profileOwnerRedirectTarget(
      location: location,
      currentPublicKeyHex: authService.currentPublicKeyHex,
    );
    if (profileRedirect != null) return profileRedirect;
  }

  return deepLinkRewrite;
}
