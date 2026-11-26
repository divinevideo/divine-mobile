// ABOUTME: Checks mounted conversation viewports only when a push arrives.
import 'package:dm_repository/dm_repository.dart';

typedef DmViewportProbe = bool Function(
  String owner,
  String conversation,
  String message,
);

class DmMessageVisibility {
  static final _probes = <DmViewportProbe>{};
  static void attach(DmViewportProbe probe) => _probes.add(probe);
  static void detach(DmViewportProbe probe) => _probes.remove(probe);
  static bool contains(String owner, String conversation, String message) =>
      _probes.any((probe) => probe(owner, conversation, message));
}

/// Permission and account-specific consent are checked around this decision.
/// An unprocessed wrap can generate a generic alert after the lookup budget.
bool shouldDisplayDmAlert(
  DmWrapLookup lookup, {
  required String owner,
  required bool restricted,
  required bool Function(String) allowedPeer,
  DmViewportProbe visible = DmMessageVisibility.contains,
}) {
  if (lookup is DmWrapPending) return !restricted;
  if (lookup is! DmWrapFound || lookup.isRequest) return false;
  if (restricted && !lookup.participants.every(allowedPeer)) return false;
  return !visible(owner, lookup.conversationId, lookup.messageId);
}
