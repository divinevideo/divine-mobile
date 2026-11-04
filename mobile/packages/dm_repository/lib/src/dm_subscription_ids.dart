// ABOUTME: Builds DM relay subscription ids that stay inside NIP-01's
// ABOUTME: 64-character cap while remaining distinct per account and page.

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
