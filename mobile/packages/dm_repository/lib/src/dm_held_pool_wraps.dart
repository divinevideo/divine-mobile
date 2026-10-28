// ABOUTME: What a retry of a DM reaction, removal or retraction does for a
// ABOUTME: recipient whose earlier wrap a fallback-pool relay accepted while
// ABOUTME: their inbox could not be read (#10012).

import 'dart:convert';

import 'package:dm_repository/src/dm_repository.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// The held-wrap record a queue row stores, a JSON object from recipient hex
/// pubkey to gift-wrap event id, as a map. Empty when the row holds none, or
/// one that cannot be read: that names no wrap a retry could rely on.
Map<String, String> decodeHeldPoolWraps(String? json) {
  if (json == null) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is String) key: value,
    };
  } on FormatException {
    return const {};
  }
}

/// The wrap [downgradeFallbackPoolDelivery] held: the one a relay confirmed
/// in [published] while [result], what the downgrade made of it, is not
/// delivery. `null` when the attempt was not held that way.
String? heldPoolWrapOf(NIP17SendResult published, NIP17SendResult result) =>
    published.success && !result.success ? published.messageEventId : null;

/// This attempt's outcome for [recipientPubkey], without sending them
/// anything, when an earlier attempt left [heldWrapId] with the fallback pool
/// on an unreadable inbox (#10012). `null` when the attempt sends as before:
/// nothing is held for them, or their inbox is now found, so the wrap goes
/// where they read.
///
/// While their inbox stays unreadable another wrap is no more likely to reach
/// it, so the attempt holds again on the one the pool has. Once it reads
/// absent the pool is where they read, so that wrap is the delivery. Either
/// way [NIP17MessageService.heldRetryRefusal]'s checks come first, as they
/// would inside a send: a refused recipient, an offline device, or no relay
/// ends the attempt as it would end a publish.
Future<NIP17SendResult?> resolveHeldPoolWrap({
  required NIP17MessageService messageService,
  required Event rumor,
  required String recipientPubkey,
  required String? heldWrapId,
  required DmInboxResolution? inboxState,
}) async {
  if (heldWrapId == null) return null;
  final keeps = inboxState == DmInboxResolution.unreadable;
  if (!keeps && inboxState != DmInboxResolution.absent) return null;
  final refusal = await messageService.heldRetryRefusal(recipientPubkey);
  if (refusal != null) return refusal;
  if (keeps) {
    Log.info(
      'Not republishing rumor ${rumor.id} to '
      '${pubkeyForLogs(recipientPubkey)}: the fallback pool already accepted '
      'wrap $heldWrapId and their inbox is still unreadable, so it stays held '
      '(#10012)',
      category: LogCategory.system,
    );
    return const NIP17SendResult.failure(
      'Recipient DM inbox still unreadable; the fallback pool holds the wrap',
      retryablePending: true,
    );
  }
  Log.info(
    'Not republishing rumor ${rumor.id} to '
    '${pubkeyForLogs(recipientPubkey)}: they advertise no DM inbox, so wrap '
    '$heldWrapId the fallback pool accepted is delivery (#10012)',
    category: LogCategory.system,
  );
  return NIP17SendResult.success(
    rumorEventId: rumor.id,
    messageEventId: heldWrapId,
    recipientPubkey: recipientPubkey,
    selfWrapPublished: false,
  );
}
