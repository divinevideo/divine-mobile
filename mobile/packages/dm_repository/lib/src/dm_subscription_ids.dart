// ABOUTME: Builds DM relay subscription ids that stay inside NIP-01's
// ABOUTME: 64-character cap, distinct per account, page and history read.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Subscription id for the live gift-wrap inbox of [pubkey].
String dmInboxSubscriptionId(String pubkey) =>
    scopedSubscriptionId('dm_inbox', pubkey);

/// Subscription id for page [page] of the NIP-17 history drain of [pubkey].
String dmHistoryDrainSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_drain', pubkey)}_$page';

/// Subscription id for page [page] of a walk of [pubkey]'s catch-up debt:
/// the part of a catch-up window a relay may have withheld at its result cap.
String dmCatchUpDebtSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_catchup', pubkey)}_$page';

/// Subscription id for page [page] of the re-query below the live window of
/// [pubkey] (#8439).
String dmBelowWindowRequerySubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_requery', pubkey)}_$page';

/// Subscription id for the kind-5 read paired with the read [readId] names.
///
/// Deletions are asked for in a REQ of their own: a relay that gates DMs
/// behind NIP-42 serves a REQ mixing them with kinds 1059 and 4 without the
/// DMs, instead of refusing it (#9468).
String dmDeletionsSubscriptionId(String readId) => '${readId}_k5';

/// Subscription id for page [page] of the end-of-drain deletion pass of
/// [pubkey].
String dmDeletionDrainSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_drain_k5', pubkey)}_$page';

/// Subscription id for page [page] of the NIP-04 history drain of [pubkey].
String dmNip04DrainSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_drain_nip04', pubkey)}_$page';

/// [readId] with a token of its own, for one REQ of that read.
///
/// The pool routes a relay's frames by subscription id alone, and a relay can
/// still be answering a REQ after its CLOSE. A read that asks again under the
/// id an earlier REQ used can be settled by that REQ's late answer, so every
/// history read asks under a fresh one (#11025). Not for a subscription that
/// is later closed by its id, such as the live inbox.
String dmReadAttemptSubscriptionId(String readId) {
  final id =
      '${readId}_${StringUtil.rndSecureNameStr(_readAttemptTokenLength)}';
  assert(
    id.length <= nip01MaxSubscriptionIdLength,
    'Subscription id "$id" is ${id.length} characters, over NIP-01\'s '
    '$nip01MaxSubscriptionIdLength',
  );
  return id;
}

/// Characters in a read's token, each a digit or lowercase letter: enough
/// that two reads of one page never share an id, few enough that every DM read
/// id stays under NIP-01's cap.
const _readAttemptTokenLength = 8;
