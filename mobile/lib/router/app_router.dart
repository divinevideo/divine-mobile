// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes; routes split by feature

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/invite_availability_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/product_analytics_navigation_observer.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/providers/redirect_provider.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/router_refresh_listenable.dart';
import 'package:openvine/router/routes/account_deletion_recovery_routes.dart';
import 'package:openvine/router/routes/apps_routes.dart';
import 'package:openvine/router/routes/auth_routes.dart';
import 'package:openvine/router/routes/library_routes.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/router/routes/minor_account_review_routes.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:unified_logger/unified_logger.dart';

export 'routes/router_guards.dart'
    show
        homeInitialIndexFromPathParameters,
        pendingEmailVerificationLocation,
        pendingEmailVerificationRestoreLocation,
        pendingEmailVerificationStartupLocation,
        rewriteResetPasswordDeepLink;

part 'app_router_redirect.dart';

/// Global route observer for [RouteAware] subscribers (e.g. pausing video
/// when a new route is pushed on top of the feed).
final routeObserver = RouteObserver<ModalRoute<dynamic>>();

/// Optional first route for a newly-built account container.
///
/// Account switches use this to seed the target container's router with the
/// route the user was already viewing. Cold launch leaves it null so the normal
/// welcome-entry redirect flow remains unchanged.
final routerInitialLocationProvider = Provider<String?>((_) => null);

final goRouterProvider = Provider<GoRouter>((ref) {
  // Use ref.read to avoid recreating the router on auth state changes
  final authService = ref.read(authServiceProvider);

  // Keep one router instance alive; drive redirect reevaluation through a
  // dedicated listenable instead of rebuilding GoRouter when app state changes.
  final refreshListenable = RouterRefreshListenable(
    authService.authStateStream,
  );
  var lastInviteRedirectSignature = (false, true);
  StreamSubscription<InviteAvailabilityState>? inviteAvailabilitySub;

  void refreshForInviteAvailability(InviteAvailabilityState state) {
    final signature = (state.hasResolved, state.isEnabled);
    if (signature == lastInviteRedirectSignature) return;
    lastInviteRedirectSignature = signature;
    refreshListenable.refresh();
  }

  void subscribeToInviteAvailability(InviteAvailabilityCubit cubit) {
    unawaited(inviteAvailabilitySub?.cancel());
    lastInviteRedirectSignature = (
      cubit.state.hasResolved,
      cubit.state.isEnabled,
    );
    inviteAvailabilitySub = cubit.stream.listen(refreshForInviteAvailability);
  }

  subscribeToInviteAvailability(ref.read(inviteAvailabilityCubitProvider));
  ref.listen(inviteAvailabilityCubitProvider, (previous, next) {
    if (identical(previous, next)) return;
    subscribeToInviteAvailability(next);
    refreshListenable.refresh();
  });
  ref.onDispose(() {
    unawaited(inviteAvailabilitySub?.cancel());
  });

  ref.listen(currentMinorAccountReviewStatusProvider, (previous, next) {
    // A resume/background refetch that resolves to a routing-identical status
    // (active → active) must not refresh: refreshing churns the route pipeline
    // and tears down a reel pushed on top mid-init. Only refresh when the
    // redirect outcome can actually change.
    if (!minorAccountReviewStatusAffectsRouting(previous, next)) {
      return;
    }
    refreshListenable.refresh();
  });
  bool deletionGateActiveForCurrentAccount(
    AsyncValue<AccountDeletionAttempt?>? attempt,
  ) {
    final submitted = ref.read(submittedAccountDeletionAttemptProvider);
    return accountDeletionRecoveryGateActive(
      attempt,
      submittedAttempt: submitted,
      authState: authService.authState,
      currentPubkeyHex: authService.currentPublicKeyHex,
    );
  }

  ref.listen(currentAccountDeletionAttemptProvider, (previous, next) {
    final before = deletionGateActiveForCurrentAccount(previous);
    final after = deletionGateActiveForCurrentAccount(next);
    if (before != after) refreshListenable.refresh();
  });
  ref.listen(
    submittedAccountDeletionMonitorProvider,
    (_, _) {},
    fireImmediately: true,
  );
  ref.onDispose(refreshListenable.dispose);

  final router = GoRouter(
    navigatorKey: NavigatorKeys.root,
    // Start at /welcome - redirect logic will navigate to appropriate route.
    initialLocation:
        ref.read(routerInitialLocationProvider) ?? WelcomeScreen.path,
    observers: _buildRouterObservers(ref),
    // Refresh router when auth or account-review state changes
    refreshListenable: refreshListenable,
    errorBuilder: (context, state) =>
        RouteErrorScreen(message: context.l10n.routeUnknownPath),
    redirect: (context, state) => appRouterRedirect(ref, state),
    // go_router matches same-segment-count routes top-to-bottom, so spread
    // order below is load-bearing whenever two routes share a literal first
    // path segment. It's match-safe today because every module's
    // parameterized routes (`:id`, `:listId`, etc.) sit under a first segment
    // no other module uses. The one same-prefix case in this app
    // (`/people-lists/new` vs. `/people-lists/:listId`) is contained inside
    // `lists_routes.dart`, which orders the literal route first and is
    // guarded by `people_lists_route_order_test.dart`. If you add a bare
    // `/:slug`-style route or a route that shares a first segment with
    // another module, place it deliberately and add a similar order guard —
    // don't rely on this spread order by accident.
    routes: [
      ...videoRoutes(),
      ...shellRoutes(),
      ...searchRoutes(),
      ...messagingRoutes(),
      ...accountDeletionRecoveryRoutes(),
      ...minorAccountReviewRoutes(),
      ...listsRoutes(ref),
      ...authRoutes(ref),
      ...appsRoutes(ref),
      ...settingsRoutes(ref),
      ...profileRoutes(),
      ...libraryRoutes(),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

List<NavigatorObserver> _buildRouterObservers(Ref ref) {
  final observers = <NavigatorObserver>[
    routeObserver,
    PageLoadObserver(analytics: ref.read(screenAnalyticsServiceProvider)),
    ProductAnalyticsNavigationObserver(
      analytics: () => ref.read(analyticsServiceProvider),
    ),
  ];

  return observers;
}
