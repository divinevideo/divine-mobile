// ABOUTME: Writes the record of the gift wraps a fallback-pool relay holds
// ABOUTME: for a DM rumor while its recipient's inbox cannot be read (#10012).

import 'dart:convert';

/// [heldWraps], a JSON object from recipient hex pubkey to gift-wrap event id,
/// with [recipientPubkey] now held by [wrapEventId] (#10012).
///
/// A record that cannot be read is replaced: it names no wrap a retry could
/// rely on, so the worst it costs is the wrap a retry would have sent anyway.
String withHeldPoolWrap(
  String? heldWraps, {
  required String recipientPubkey,
  required String wrapEventId,
}) {
  final wraps = <String, String>{};
  if (heldWraps != null) {
    try {
      final decoded = jsonDecode(heldWraps);
      if (decoded is Map) {
        for (final MapEntry(:key, :value) in decoded.entries) {
          if (key is String && value is String) wraps[key] = value;
        }
      }
    } on FormatException {
      // Unreadable, so replaced by the one recorded below.
    }
  }
  wraps[recipientPubkey] = wrapEventId;
  return jsonEncode(wraps);
}
