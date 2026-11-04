// ABOUTME: What a retry of a DM reaction, removal or retraction does for a
// ABOUTME: recipient an earlier attempt reached, or whose wrap a fallback-pool
// ABOUTME: relay accepted while their inbox could not be read (#10012).

import 'dart:convert';

import 'package:dm_repository/src/dm_repository.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// What an earlier attempt recorded for one recipient of a DM reaction, its
/// removal or a retraction (#10012): `wrapId`, the gift wrap a relay accepted
/// for them, and whether that wrap is their `delivered` copy or one the
/// fallback pool holds while their inbox could not be read.
typedef HeldWrap = ({String wrapId, bool delivered});

/// The held-wrap record a queue row stores, by recipient hex pubkey: a JSON
/// object from each to `{"wrap": <gift-wrap event id>, "delivered": <bool>}`.
/// Empty when the row holds none, or one that cannot be read. An entry that
/// names no wrap is left out, and one that does not say it was delivered is
/// read as held: neither names a delivery a retry could rely on.
Map<String, HeldWrap> decodeHeldWraps(String? json) {
  if (json == null) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is Map && value['wrap'] is String)
          key: (
            wrapId: value['wrap'] as String,
            delivered: value['delivered'] == true,
          ),
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
/// anything, when an earlier attempt left [heldWrap] with a relay (#10012).
/// `null` when the attempt sends as before: nothing is recorded for them, or
/// the fallback pool holds their wrap and their inbox is now found, so the
/// wrap goes where they read.
///
/// A recipient the record says has it is delivered already: the checks a
/// send makes passed when that wrap was sent, and nothing this attempt finds
/// takes it back, so it counts them as delivered with no check and no send.
/// While their inbox stays unreadable another wrap is no more likely to reach
/// it, so the attempt holds again on the one the pool has. Once it reads
/// absent the pool is where they read, so that wrap is the delivery. Either
/// way [NIP17MessageService.heldRetryRefusal]'s checks come first, as they
/// would inside a send: a refused recipient, an offline device, or no relay
/// ends the attempt as it would end a publish.
Future<NIP17SendResult?> resolveHeldWrap({
  required NIP17MessageService messageService,
  required Event rumor,
  required String recipientPubkey,
  required HeldWrap? heldWrap,
  required DmInboxResolution? inboxState,
}) async {
  if (heldWrap == null) return null;
  final (wrapId: heldWrapId, :delivered) = heldWrap;
  if (delivered) {
    Log.info(
      'Not republishing rumor ${rumor.id} to '
      '${pubkeyForLogs(recipientPubkey)}: an earlier attempt delivered wrap '
      '$heldWrapId to them (#10012)',
      category: LogCategory.system,
    );
    return NIP17SendResult.success(
      rumorEventId: rumor.id,
      messageEventId: heldWrapId,
      recipientPubkey: recipientPubkey,
      selfWrapPublished: false,
    );
  }
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
