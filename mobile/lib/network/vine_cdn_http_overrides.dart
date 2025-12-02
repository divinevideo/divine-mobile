// ABOUTME: DNS override to route Vine CDN hostnames to a working edge IP
// This preserves TLS SNI and Host headers by keeping the original hostname
// while forcing DNS resolution to a fixed IP address.

import 'dart:io';

class VineCdnHttpOverrides extends HttpOverrides {
  VineCdnHttpOverrides({required this.overrideAddress, Set<String>? hosts})
    : hosts = hosts ?? const {'v.cdn.vine.co', 'cdn.vine.co'};

  final InternetAddress overrideAddress;
  final Set<String> hosts;

  Future<List<InternetAddress>> lookup(
    String host, {
    InternetAddressType type = InternetAddressType.any,
    String? zone,
  }) async {
    if (hosts.contains(host)) {
      // Force connect to the edge IP while retaining the original hostname
      // for TLS SNI and HTTP Host header.
      return [overrideAddress];
    }
    return InternetAddress.lookup(host, type: type);
  }
}
