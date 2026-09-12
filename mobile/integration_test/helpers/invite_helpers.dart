// ABOUTME: Shared helpers for asserting invite allocation in integration tests
// ABOUTME: Reads the app-wide InviteStatusCubit without triggering the fetch,
// ABOUTME: so tests observe the app's own loading behaviour rather than
// ABOUTME: driving it. Used by both the local-key and Keycast identity paths.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';

/// Invites the server grants an identity on its first authenticated
/// `GET /v1/invite-status` (`initial_allocation_count`, default 10).
const initialInviteAllocation = 10;

/// Reads the app-wide invite status straight out of the running app.
InviteStatusState inviteState(WidgetTester tester) =>
    tester.element(find.byType(MaterialApp)).read<InviteStatusCubit>().state;

/// Pump until the invite status cubit holds a server response.
///
/// The cubit loads on its own once the signer is ready, so this only waits;
/// it never triggers the fetch, which is the behaviour under test.
Future<InviteStatusState> waitForLoadedInviteStatus(
  WidgetTester tester, {
  int maxSeconds = 45,
}) async {
  final iterations = maxSeconds * 4;
  var last = inviteState(tester);
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    last = inviteState(tester);
    if (last.status == InviteStatusLoadingStatus.loaded) return last;
  }
  fail(
    'Invite status never loaded within ${maxSeconds}s '
    '(last status: ${last.status}, signerReady: ${last.isSignerReady}). '
    'The invite server should answer the first authenticated '
    'GET /v1/invite-status for an authenticated identity.',
  );
}
