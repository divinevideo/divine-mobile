import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/network/vine_cdn_http_overrides.dart';

void main() {
  test('VineCdnHttpOverrides returns override IP for Vine CDN hosts', () async {
    final ip = InternetAddress('151.101.244.157');
    final overrides = VineCdnHttpOverrides(overrideAddress: ip);

    final result1 = await overrides.lookup('v.cdn.vine.co');
    expect(result1, isNotEmpty);
    expect(result1.first.address, equals('151.101.244.157'));

    final result2 = await overrides.lookup('cdn.vine.co');
    expect(result2, isNotEmpty);
    expect(result2.first.address, equals('151.101.244.157'));
  });
}
