import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/zendesk_config.dart';

void main() {
  group('ZendeskConfig', () {
    test('appId should be defined from environment', () {
      expect(ZendeskConfig.appId, isA<String>());
    });

    test('clientId should be defined from environment', () {
      expect(ZendeskConfig.clientId, isA<String>());
    });

    test('zendeskUrl should have default value', () {
      expect(ZendeskConfig.zendeskUrl, isNotEmpty);
      expect(ZendeskConfig.zendeskUrl, contains('zendesk.com'));
    });
  });
}
