// ABOUTME: Full-screen route for interrupted account-deletion recovery.
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';

part 'account_deletion_recovery_routes.g.dart';

List<RouteBase> accountDeletionRecoveryRoutes() => $appRoutes;

@TypedGoRoute<AccountDeletionRecoveryRouteData>(
  path: AccountDeletionRecoveryScreen.path,
  name: AccountDeletionRecoveryScreen.routeName,
)
class AccountDeletionRecoveryRouteData extends GoRouteData
    with $AccountDeletionRecoveryRouteData {
  const AccountDeletionRecoveryRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AccountDeletionRecoveryScreen();
}
