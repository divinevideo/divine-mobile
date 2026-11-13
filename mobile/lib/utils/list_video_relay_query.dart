// ABOUTME: Builds the relay query for the videos a curated list names that no
// ABOUTME: cache held, within the number of filters one REQ may carry.

import 'dart:math' as math;

import 'package:nostr_sdk/aid.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

/// The relay query for the videos a curated list names that no cache held:
/// event ids by id and `kind:pubkey:d-tag` coordinates by address.
///
/// relay.divine.video closes a REQ carrying more than [maxFiltersPerRequest]
/// filters, and lists name videos by coordinate since #7135, so a filter per
/// coordinate would stop a list of eleven videos from loading. Coordinates
/// share filters instead. A shared filter also matches an author's video
/// under another coordinate's d-tag, which [asked] tells apart.
class ListVideoRelayQuery {
  /// Creates the query for [eventIds] and [coordinates]. A coordinate that
  /// does not parse is left out.
  ListVideoRelayQuery({
    required List<String> eventIds,
    required List<String> coordinates,
  }) : _eventIds = eventIds,
       _askedEventIds = {for (final id in eventIds) id.toLowerCase()},
       _addresses = [
         for (final coordinate in coordinates) ?AId.fromString(coordinate),
       ];

  /// The most filters relay.divine.video accepts in one REQ.
  static const maxFiltersPerRequest = 10;

  /// How many addresses share a filter while the REQ has room to spare.
  static const addressesPerFilter = 50;

  final List<String> _eventIds;
  final Set<String> _askedEventIds;
  final List<AId> _addresses;

  late final Set<String> _askedCoordinates = {
    for (final address in _addresses) address.toAString(),
  };

  /// The filters for one REQ: one by id, and as few by address as fit.
  List<Filter> get filters {
    final addressSlots = maxFiltersPerRequest - (_eventIds.isEmpty ? 0 : 1);
    final perFilter = math.max(
      addressesPerFilter,
      (_addresses.length / addressSlots).ceil(),
    );
    return [
      if (_eventIds.isNotEmpty) Filter(ids: _eventIds),
      for (var i = 0; i < _addresses.length; i += perFilter)
        _addressFilter(_addresses.skip(i).take(perFilter)),
    ];
  }

  /// Whether [event] is a video this query asked for, by id or by address.
  bool asked(Event event) =>
      _askedEventIds.contains(event.id.toLowerCase()) ||
      _askedCoordinates.contains(
        AId(
          kind: event.kind,
          pubkey: event.pubkey,
          dTag: event.dTagValue,
        ).toAString(),
      );

  static Filter _addressFilter(Iterable<AId> batch) => Filter(
    kinds: {for (final address in batch) address.kind}.toList(),
    authors: {for (final address in batch) address.pubkey}.toList(),
    d: {for (final address in batch) address.dTag}.toList(),
  );
}
