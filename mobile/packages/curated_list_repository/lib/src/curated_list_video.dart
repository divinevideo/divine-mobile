// ABOUTME: One video under both names a curated list can hold it by: its
// ABOUTME: NIP-71 coordinate, or the event id of one of its versions.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show legacyVideoCoordinateFor;

/// Maps video event ids to the `kind:pubkey:d-tag` coordinate of the video
/// each one is a version of. Ids that are not addressable videos, or that
/// cannot be found, are left out of the result.
///
/// Lets a list item saved as the event id of an older version be recognised
/// as the video it was edited into (#7135).
typedef CuratedListVideoAddressResolver =
    Future<Map<String, String>> Function(List<String> eventIds);

/// One video, under both names a curated list can hold it by.
///
/// NIP-71 names an addressable video by its `kind:pubkey:d-tag` coordinate,
/// because an edit republishes it under a new event id (#7135). Items saved
/// before then, or by clients that name a version, hold an event id instead.
class CuratedListVideo {
  /// Creates the names of the video published as [eventId], whose coordinate
  /// is [address] when it has one.
  const CuratedListVideo({required this.eventId, this.address});

  /// The event id of the version at hand.
  final String eventId;

  /// The video's `kind:pubkey:d-tag` coordinate, or null without one.
  final String? address;

  /// The item a list stores to hold this video: [address] when there is one,
  /// so the item outlives an edit, otherwise [eventId].
  String get reference => address ?? eventId;

  /// The items of [list] that name this video, in list order. A Kind 34235
  /// video is also found under the `34236:` coordinate Divine wrote for it
  /// before #10776.
  ///
  /// [addressByEventId] holds the coordinates a
  /// [CuratedListVideoAddressResolver] reported: an event-id item mapped to
  /// this video's coordinate is an older version of it.
  List<String> referencesIn(
    CuratedList list, {
    Map<String, String> addressByEventId = const {},
  }) {
    final address = this.address;
    final addresses = {
      ?address,
      if (address != null) ?legacyVideoCoordinateFor(address),
    };
    return [
      for (final item in list.videoEventIds)
        if (item == eventId ||
            addresses.contains(item) ||
            addresses.contains(addressByEventId[item]))
          item,
    ];
  }

  /// Whether [list] holds this video under any name; see [referencesIn].
  bool isIn(
    CuratedList list, {
    Map<String, String> addressByEventId = const {},
  }) => referencesIn(list, addressByEventId: addressByEventId).isNotEmpty;

  /// The event-id items of [lists], once each in list order, leaving out
  /// [except]: the items a [CuratedListVideoAddressResolver] can place.
  static List<String> eventIdItemsOf(
    Iterable<CuratedList> lists, {
    Set<String> except = const {},
  }) => {
    for (final list in lists)
      for (final item in list.videoEventIds)
        if (!item.contains(':') && !except.contains(item)) item,
  }.toList();
}
