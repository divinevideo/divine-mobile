import 'dart:collection';
import 'dart:convert';

import 'event.dart';
import 'filter.dart';
import 'utils/hash_util.dart';
import 'utils/string_util.dart';

/// NIP-01: "`<subscription_id>` is an arbitrary, non-empty string of max
/// length 64 chars."
///
/// A relay that enforces this refuses the `REQ` outright (strfry answers with
/// `CLOSED` or `NOTICE`), so a subscription with a longer id silently gets
/// nothing from that relay.
const int nip01MaxSubscriptionIdLength = 64;

/// Hex characters of the scope digest kept by [scopedSubscriptionId].
const int _scopeTagLength = 16;

/// Builds a stable subscription id for [prefix] that stays distinct per
/// [scope], such as one live subscription per account (a pubkey) or per
/// thread (a root event id).
///
/// A 64-character hex pubkey or event id behind any prefix already exceeds
/// [nip01MaxSubscriptionIdLength], so [scope] is hashed rather than
/// shortened: a shortened public identifier looks correlatable and is not,
/// whereas a digest is honestly opaque and never mistaken for the key itself.
String scopedSubscriptionId(String prefix, String scope) {
  final tag = HashUtil.sha256Bytes(
    utf8.encode(scope),
  ).substring(0, _scopeTagLength);
  final id = '${prefix}_$tag';
  assert(
    id.length <= nip01MaxSubscriptionIdLength,
    'Subscription id "$id" is ${id.length} characters; prefix "$prefix" '
    'leaves no room under the $nip01MaxSubscriptionIdLength-character cap',
  );
  return id;
}

/// Representation of a Nostr event subscription.
class Subscription {
  final String _id;
  final List<Map<String, dynamic>> filters;
  Function onEvent;

  /// Callback invoked when EOSE (End of Stored Events) is received from all
  /// relays for this subscription.
  void Function()? onEose;

  /// Callback invoked when every relay serving this subscription has ended
  /// its REQ with a `CLOSED` frame.
  void Function(String reason)? onClosed;

  /// [filters] parsed once at construction.
  ///
  /// [matchesEvent] runs on every inbound frame, and `Filter.fromJson` copies
  /// each id/author list it is handed — parsing per event would make the
  /// receive path scale with the size of the author set. Parsing here also
  /// means a malformed filter throws at subscribe time rather than being
  /// swallowed per-event by the frame handler's catch-all.
  final List<Filter> _parsedFilters;

  /// [filters] as parsed at construction, in the same order.
  ///
  /// Read-only: [matchesEvent] reads these same objects, so a caller that
  /// needs per-filter matching reuses this parse instead of repeating it.
  List<Filter> get parsedFilters => UnmodifiableListView(_parsedFilters);

  /// Subscription ID
  String get id => _id;

  /// Creates a subscription for [filters].
  ///
  /// An explicit [id] must be 1 to [nip01MaxSubscriptionIdLength] characters
  /// long; build one with [scopedSubscriptionId]. Without it, a random
  /// 16-character id is generated.
  Subscription(
    this.filters,
    this.onEvent, {
    String? id,
    this.onEose,
    this.onClosed,
  }) : assert(
         id == null ||
             (id.isNotEmpty && id.length <= nip01MaxSubscriptionIdLength),
         'Subscription id "$id" is ${id.length} characters; NIP-01 allows '
         '1 to $nip01MaxSubscriptionIdLength, and a relay enforcing that '
         'refuses the REQ',
       ),
       _id = id ?? StringUtil.rndSecureNameStr(16),
       _parsedFilters = [for (final filter in filters) Filter.fromJson(filter)];

  /// Whether [event] satisfies at least one filter in this subscription.
  ///
  /// A subscription carrying no filters matches nothing; the pool's entry
  /// points reject an empty filter list before one can be constructed.
  bool matchesEvent(Event event) =>
      _parsedFilters.any((filter) => filter.checkEvent(event));

  /// Returns the subscription as a Nostr subscription request in JSON format
  List<dynamic> toJson() {
    List<dynamic> json = ["REQ", _id];

    for (Map<String, dynamic> filter in filters) {
      json.add(filter);
    }

    return json;
  }
}
