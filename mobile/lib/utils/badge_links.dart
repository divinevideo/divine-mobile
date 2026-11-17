// ABOUTME: Lossless badge navigation and sharing for every public identifier.

import 'dart:convert';

import 'package:badge_repository/badge_repository.dart';

/// Percent-encoded path segment for the badge routes: the naddr, or the raw
/// coordinate when the identifier is too long for NIP-19.
String badgeRouteReference(BadgeCoordinate coordinate) =>
    Uri.encodeComponent(_naddr(coordinate) ?? coordinate.value);

/// Web link where NIP-19 fits; otherwise the complete protocol coordinate.
String badgeShareReference(BadgeCoordinate coordinate) {
  final naddr = _naddr(coordinate);
  return naddr == null
      ? coordinate.value
      : 'https://badges.divine.video/b/$naddr';
}

// NIP-19 uses a one-byte TLV length; a valid NIP-58 identifier can be longer.
String? _naddr(BadgeCoordinate coordinate) =>
    utf8.encode(coordinate.identifier).length <= 255
    ? coordinate.toNaddr()
    : null;
