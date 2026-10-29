// ABOUTME: Writes the record of the gift wraps relays hold of a DM rumor, per
// ABOUTME: recipient, while the rumor is not yet delivered to all (#10012).

import 'dart:convert';

/// [heldWraps], the record of the gift wraps relays hold of a DM rumor
/// (#10012), with each recipient in [wraps] now holding the wrap it names:
/// their delivery when [delivered], otherwise a wrap a fallback-pool relay
/// accepted while their inbox could not be read.
///
/// The record is a JSON object from recipient hex pubkey to
/// `{"wrap": <gift-wrap event id>, "delivered": <bool>}`. A recipient already
/// recorded as delivered stays delivered: within one rumor, a held wrap for
/// them can only come from an attempt that began before they had it. A record
/// or an entry that cannot be read is dropped: it names no wrap a retry could
/// rely on, so the worst it costs is the wrap a retry would have sent anyway.
String withHeldWraps(
  String? heldWraps,
  Map<String, String> wraps, {
  required bool delivered,
}) {
  final entries = <String, Map<String, Object>>{};
  if (heldWraps != null) {
    try {
      final decoded = jsonDecode(heldWraps);
      if (decoded is Map) {
        for (final MapEntry(:key, :value) in decoded.entries) {
          if (key is String && value is Map && value['wrap'] is String) {
            entries[key] = {
              'wrap': value['wrap'] as String,
              'delivered': value['delivered'] == true,
            };
          }
        }
      }
    } on FormatException {
      // Unreadable, so replaced by the entries recorded below.
    }
  }
  for (final MapEntry(key: recipient, value: wrap) in wraps.entries) {
    if (!delivered && entries[recipient]?['delivered'] == true) continue;
    entries[recipient] = {'wrap': wrap, 'delivered': delivered};
  }
  return jsonEncode(entries);
}
