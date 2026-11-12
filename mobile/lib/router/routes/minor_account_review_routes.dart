// ABOUTME: Minor-account-review flow routes (welcome / review / parent / under-13)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';

part 'minor_account_review_routes.g.dart';

/// The review routes, registered in the order the hand-written list used.
List<RouteBase> minorAccountReviewRoutes() => $appRoutes;

/// The review opened from the welcome screen rather than from moderation.
@TypedGoRoute<MinorAccountReviewWelcomeRouteData>(
  path: MinorAccountReviewScreen.welcomePath,
  name: MinorAccountReviewScreen.welcomeRouteName,
)
class MinorAccountReviewWelcomeRouteData extends GoRouteData
    with $MinorAccountReviewWelcomeRouteData {
  const MinorAccountReviewWelcomeRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewScreen(
        entryPoint: MinorAccountReviewEntryPoint.welcome,
      );
}

/// The review status screen reached from moderation.
@TypedGoRoute<MinorAccountReviewRouteData>(
  path: MinorAccountReviewScreen.path,
  name: MinorAccountReviewScreen.routeName,
)
class MinorAccountReviewRouteData extends GoRouteData
    with $MinorAccountReviewRouteData {
  const MinorAccountReviewRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewScreen();
}

/// The wait while the review status loads, entered only through the gate's
/// redirect, which appends a `from` query this route does not read.
@TypedGoRoute<MinorAccountReviewLoadingRouteData>(
  path: MinorAccountReviewLoadingScreen.path,
  name: MinorAccountReviewLoadingScreen.routeName,
)
class MinorAccountReviewLoadingRouteData extends GoRouteData
    with $MinorAccountReviewLoadingRouteData {
  const MinorAccountReviewLoadingRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewLoadingScreen();
}

/// The teen path's parent consent options.
@TypedGoRoute<MinorAccountReviewParentConsentRouteData>(
  path: MinorAccountReviewParentConsentScreen.path,
  name: MinorAccountReviewParentConsentScreen.routeName,
)
class MinorAccountReviewParentConsentRouteData extends GoRouteData
    with $MinorAccountReviewParentConsentRouteData {
  const MinorAccountReviewParentConsentRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewParentConsentScreen();
}

/// The in-app recording step of parent consent.
@TypedGoRoute<MinorAccountReviewRecordConsentRouteData>(
  path: MinorAccountReviewRecordConsentScreen.path,
  name: MinorAccountReviewRecordConsentScreen.routeName,
)
class MinorAccountReviewRecordConsentRouteData extends GoRouteData
    with $MinorAccountReviewRecordConsentRouteData {
  const MinorAccountReviewRecordConsentRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewRecordConsentScreen();
}

/// The step that reaches a parent by email.
@TypedGoRoute<MinorAccountReviewParentContactRouteData>(
  path: MinorAccountReviewParentContactScreen.path,
  name: MinorAccountReviewParentContactScreen.routeName,
)
class MinorAccountReviewParentContactRouteData extends GoRouteData
    with $MinorAccountReviewParentContactRouteData {
  const MinorAccountReviewParentContactRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewParentContactScreen();
}

/// The under-13 outcome.
@TypedGoRoute<MinorAccountReviewUnder13RouteData>(
  path: MinorAccountReviewUnder13Screen.path,
  name: MinorAccountReviewUnder13Screen.routeName,
)
class MinorAccountReviewUnder13RouteData extends GoRouteData
    with $MinorAccountReviewUnder13RouteData {
  const MinorAccountReviewUnder13RouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewUnder13Screen();
}

/// Support instructions for the under-13 path.
@TypedGoRoute<MinorAccountReviewUnder13SupportRouteData>(
  path: MinorAccountReviewUnder13SupportScreen.path,
  name: MinorAccountReviewUnder13SupportScreen.routeName,
)
class MinorAccountReviewUnder13SupportRouteData extends GoRouteData
    with $MinorAccountReviewUnder13SupportRouteData {
  const MinorAccountReviewUnder13SupportRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MinorAccountReviewUnder13SupportScreen();
}
