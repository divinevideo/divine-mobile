// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minor_account_review_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$minorAccountReviewRecordConsentRouteData];

RouteBase get $minorAccountReviewRecordConsentRouteData => GoRouteData.$route(
  path: '/account-review/parent-consent/record',
  name: 'minor-account-review-record-consent',
  hasOverriddenOnExit: false,
  parentNavigatorKey:
      MinorAccountReviewRecordConsentRouteData.$parentNavigatorKey,
  factory: $MinorAccountReviewRecordConsentRouteData._fromState,
);

mixin $MinorAccountReviewRecordConsentRouteData on GoRouteData {
  static MinorAccountReviewRecordConsentRouteData _fromState(
    GoRouterState state,
  ) => const MinorAccountReviewRecordConsentRouteData();

  @override
  String get location =>
      GoRouteData.$location('/account-review/parent-consent/record');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
