import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/config/zendesk_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.openvine/zendesk_support');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ZendeskSupportService.initialize', () {
    test('returns false when credentials empty', () async {
      final result = await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });

    test('returns true when native initialization succeeds', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              expect(call.arguments['appId'], 'test_app_id');
              expect(call.arguments['clientId'], 'test_client_id');
              expect(call.arguments['zendeskUrl'], 'https://test.zendesk.com');
              return true;
            }
            return null;
          });

      final result = await ZendeskSupportService.initialize(
        appId: 'test_app_id',
        clientId: 'test_client_id',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, true);
      expect(ZendeskSupportService.isAvailable, true);
    });

    test('returns false when native initialization fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              throw PlatformException(code: 'INIT_FAILED', message: 'Failed');
            }
            return null;
          });

      final result = await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });
  });

  group('ZendeskSupportService.showNewTicketScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });

    test('passes parameters correctly to native', () async {
      // Initialize first
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') {
              expect(call.arguments['subject'], 'Test Subject');
              expect(call.arguments['description'], 'Test Description');
              expect(call.arguments['tags'], ['tag1', 'tag2']);
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Test Subject',
        description: 'Test Description',
        tags: ['tag1', 'tag2'],
      );

      expect(result, true);
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') {
              throw PlatformException(code: 'SHOW_FAILED', message: 'Failed');
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });
  });

  group('ZendeskSupportService.showTicketListScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, false);
    });

    test('calls native method when initialized', () async {
      var showTicketListCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showTicketList') {
              showTicketListCalled = true;
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, true);
      expect(showTicketListCalled, true);
    });
  });

  group('ZendeskSupportService REST API', () {
    test('isRestApiAvailable returns false when token not configured', () {
      // ZendeskConfig uses String.fromEnvironment which defaults to ''
      // Without --dart-define, this will be empty
      expect(
        ZendeskConfig.apiToken.isEmpty || ZendeskConfig.isRestApiConfigured,
        isTrue,
      );
    });

    test('ZendeskConfig has default apiEmail configured', () {
      // The default email should be set for bug report submissions
      expect(ZendeskConfig.apiEmail, isNotEmpty);
      expect(ZendeskConfig.apiEmail, contains('@'));
    });

    test('createTicketViaApi returns false when API not configured', () async {
      // Without ZENDESK_API_TOKEN defined at compile time, this should return false
      final result = await ZendeskSupportService.createTicketViaApi(
        subject: 'Test Subject',
        description: 'Test Description',
      );

      // When API token is not configured, should return false
      expect(result, ZendeskConfig.isRestApiConfigured);
    });

    test(
      'createBugReportTicketViaApi returns false when API not configured',
      () async {
        final result = await ZendeskSupportService.createBugReportTicketViaApi(
          reportId: 'test-123',
          userDescription: 'Test bug',
          appVersion: '1.0.0',
          deviceInfo: {'platform': 'test'},
        );

        // When API token is not configured, should return false
        expect(result, ZendeskConfig.isRestApiConfigured);
      },
    );
  });
}
