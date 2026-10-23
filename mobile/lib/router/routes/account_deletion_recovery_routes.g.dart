// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_recovery_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$accountDeletionRecoveryRouteData];

RouteBase get $accountDeletionRecoveryRouteData => GoRouteData.$route(
  path: '/account-deletion-recovery',
  name: 'account-deletion-recovery',
  hasOverriddenOnExit: false,
  factory: $AccountDeletionRecoveryRouteData._fromState,
);

mixin $AccountDeletionRecoveryRouteData on GoRouteData {
  static AccountDeletionRecoveryRouteData _fromState(GoRouterState state) =>
      const AccountDeletionRecoveryRouteData();

  @override
  String get location => GoRouteData.$location('/account-deletion-recovery');

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
