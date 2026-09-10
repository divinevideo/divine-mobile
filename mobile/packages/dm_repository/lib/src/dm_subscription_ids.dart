// ABOUTME: Builds DM relay subscription ids that stay inside NIP-01's
// ABOUTME: 64-character cap while remaining distinct per account and page.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Subscription id for the live gift-wrap inbox of [pubkey].
String dmInboxSubscriptionId(String pubkey) =>
    scopedSubscriptionId('dm_inbox', pubkey);

/// Subscription id for page [page] of the NIP-17 history drain of [pubkey].
String dmHistoryDrainSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_drain', pubkey)}_$page';

/// Subscription id for page [page] of the NIP-04 history drain of [pubkey].
String dmNip04DrainSubscriptionId(String pubkey, int page) =>
    '${scopedSubscriptionId('dm_drain_nip04', pubkey)}_$page';
