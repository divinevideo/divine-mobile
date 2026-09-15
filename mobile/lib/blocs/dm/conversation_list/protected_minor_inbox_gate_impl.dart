// ABOUTME: Real ProtectedMinorInboxGate (#176) — composes the protected-minor
// ABOUTME: status with OfficialAccountsService: a restricted minor sees only
// ABOUTME: all-approved conversations, and each pass kicks receive-time
// ABOUTME: revalidation so a server-side revocation drops the counterparty.

import 'dart:async';

import 'package:async/async.dart' show StreamGroup;
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/services/official_accounts_service.dart';

class ProtectedMinorInboxGateImpl implements ProtectedMinorInboxGate {
  ProtectedMinorInboxGateImpl({
    required bool Function() isRestricted,
    required OfficialAccountsService officials,
  }) : _isRestricted = isRestricted,
       _officials = officials;

  final bool Function() _isRestricted;
  final OfficialAccountsService _officials;

  /// Ticks pushed by [notifyRestrictionChanged] when the DM-restriction
  /// status itself flips (mid-session approval/revocation).
  final _restrictionChanges = StreamController<void>.broadcast();

  /// A verdict flip persisted by [OfficialAccountsService] — or a flip of the
  /// DM-restriction status itself — re-fires the list so the sync filter
  /// re-evaluates with the fresh answer.
  @override
  Stream<void> get changes => StreamGroup.mergeBroadcast([
    _officials.onVerdictChanged,
    _restrictionChanges.stream,
  ]);

  @override
  void notifyRestrictionChanged() {
    if (!_restrictionChanges.isClosed) _restrictionChanges.add(null);
  }

  /// Releases the restriction-change stream. Owned by the Riverpod provider
  /// (`ref.onDispose`); test-constructed gates should also call this.
  void dispose() {
    unawaited(_restrictionChanges.close());
  }

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    if (!_isRestricted()) return conversations;

    final visible = <DmConversation>[];
    for (final c in conversations) {
      var allApproved = true;
      // Fail closed on a degenerate row with no non-self counterparty: the
      // `every`-style check below is vacuously true on an empty set, so without
      // this a self-only conversation would stay visible while the
      // conversation_page route guard bounces entry. Match the guard's
      // "non-empty AND all-approved" predicate.
      var sawCounterparty = false;
      for (final p in c.participantPubkeys) {
        if (p == userPubkey) continue;
        sawCounterparty = true;
        // Receive-time revalidation (fire-and-forget): refresh the verdict so a
        // server-side revocation is pulled into the sync answer; the async
        // method re-resolves only when the cached verdict is stale. A resulting
        // flip fires onVerdictChanged -> the list re-filters and this
        // counterparty drops.
        unawaited(_officials.isApprovedMinorDmRecipient(p));
        if (!_officials.isReadableByProtectedMinor(p)) {
          allApproved = false;
        }
      }
      if (allApproved && sawCounterparty) visible.add(c);
    }
    return visible;
  }
}
