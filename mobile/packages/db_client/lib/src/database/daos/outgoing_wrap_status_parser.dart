// ABOUTME: Parses a persisted outgoing_dms wrap status, refusing unknown ones.
// ABOUTME: Shared by every DAO that reads the outbox's status columns.

import 'package:db_client/db_client.dart';

/// Parse a persisted wrap-status string back to [OutgoingWrapStatus].
///
/// Throws [UnknownOutgoingWrapStatusException] when [raw] does not
/// match any known case. Coercing unknown values to
/// [OutgoingWrapStatus.pending] would put corrupt or future-schema
/// rows back into the retry service's active set — for a retry queue
/// that risks double-delivery, so we fail loudly instead.
OutgoingWrapStatus parseOutgoingWrapStatus(String raw) {
  for (final status in OutgoingWrapStatus.values) {
    if (status.name == raw) return status;
  }
  throw UnknownOutgoingWrapStatusException(raw);
}
