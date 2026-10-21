// ABOUTME: Minor-account-review flow routes (welcome / review / parent / under-13)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';

List<RouteBase> minorAccountReviewRoutes() {
  return [
    GoRoute(
      path: MinorAccountReviewScreen.welcomePath,
      name: '${MinorAccountReviewScreen.routeName}-welcome',
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewScreen(
        entryPoint: MinorAccountReviewEntryPoint.welcome,
      ),
    ),
    GoRoute(
      path: MinorAccountReviewScreen.path,
      name: MinorAccountReviewScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewScreen(),
    ),
    GoRoute(
      path: MinorAccountReviewLoadingScreen.path,
      name: MinorAccountReviewLoadingScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewLoadingScreen(),
    ),
    GoRoute(
      path: MinorAccountReviewParentConsentScreen.path,
      name: MinorAccountReviewParentConsentScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewParentConsentScreen(),
    ),
    GoRoute(
      path: MinorAccountReviewRecordConsentScreen.path,
      name: MinorAccountReviewRecordConsentScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewRecordConsentScreen(),
    ),
    GoRoute(
      path: MinorAccountReviewParentContactScreen.path,
      name: MinorAccountReviewParentContactScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewParentContactScreen(),
    ),
    GoRoute(
      path: MinorAccountReviewUnder13Screen.path,
      name: MinorAccountReviewUnder13Screen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewUnder13Screen(),
    ),
    GoRoute(
      path: MinorAccountReviewUnder13SupportScreen.path,
      name: MinorAccountReviewUnder13SupportScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MinorAccountReviewUnder13SupportScreen(),
    ),
  ];
}
