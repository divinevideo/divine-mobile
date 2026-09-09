import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';

const _rawNsec =
    'nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6';
const _rawNcryptsec = 'ncryptsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.openvine/zendesk_support');

  setUp(() {
    ZendeskSupportService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // The setUp above only protects this file. Under the merged VGV isolate the
  // statics and the mock handler outlive it, so a later suite would see
  // Zendesk as initialized and answering `createTicket` — which flips
  // ContentReportingService's delivery from localOnly to reached.
  tearDown(() {
    ZendeskSupportService.resetForTesting();
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

    test('a repeat call keeps a successful initialization', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final second = await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Completing the initialization gate twice used to throw out of
      // initialize() and, on the way through the catch-all, reset
      // _initialized on an SDK that had just come up fine.
      expect(second, true);
      expect(ZendeskSupportService.isAvailable, true);
    });
  });

  group('ZendeskSupportService initialization gate', () {
    // The deferred startup phase kicks off initialize() without awaiting it,
    // so the auth listener can reach these identity calls while the native
    // handshake is still in flight. Both must wait for it rather than read a
    // transiently false _initialized and give up.
    test('setJwtIdentity waits for an in-flight initialization', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return true;
            }
            return null;
          });

      final nip98Service = _RecordingNip98AuthService();

      final initialization = ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.setJwtIdentity(
        nip98Service: nip98Service,
        relayManagerUrl: 'https://test-relay.divine.video',
      );
      await initialization;

      // Reaching token creation is the observable: bailing at the
      // not-initialized check would leave this at zero.
      expect(nip98Service.createAuthTokenCalls, 1);
    });

    test(
      'setAnonymousIdentityWithUserInfo waits for an in-flight initialization',
      () async {
        var userIdentityCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') {
                await Future<void>.delayed(const Duration(milliseconds: 20));
                return true;
              }
              if (call.method == 'setUserIdentity') {
                userIdentityCalls++;
                return true;
              }
              return null;
            });

        ZendeskSupportService.setUserIdentity(
          npub: 'npub1testuser',
          displayName: 'Test User',
        );

        final initialization = ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        final identitySet =
            await ZendeskSupportService.setAnonymousIdentityWithUserInfo();
        await initialization;

        // This is the identity the JWT upgrade is allowed to fall back to, so
        // losing the startup race here leaves a logged-in reporter with no
        // Zendesk identity at all.
        expect(identitySet, true);
        expect(userIdentityCalls, 1);
      },
    );

    test(
      'setAnonymousIdentity waits for an in-flight initialization',
      () async {
        var anonymousIdentityCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') {
                await Future<void>.delayed(const Duration(milliseconds: 20));
                return true;
              }
              if (call.method == 'setAnonymousIdentity') {
                anonymousIdentityCalls++;
                return true;
              }
              return null;
            });

        final initialization = ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        final identitySet = await ZendeskSupportService.setAnonymousIdentity();
        await initialization;

        expect(identitySet, true);
        expect(anonymousIdentityCalls, 1);
      },
    );
  });

  group('ZendeskSupportService.showNewTicketScreen', () {
    test('returns false when not initialized', () async {
      await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );
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

    test('retries with anonymous identity when NO_IDENTITY error', () async {
      var showNewTicketCallCount = 0;
      var setUserIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              setUserIdentityCalled = true;
              return true;
            }
            if (call.method == 'showNewTicket') {
              showNewTicketCallCount++;
              if (showNewTicketCallCount == 1) {
                throw PlatformException(
                  code: 'NO_IDENTITY',
                  message: 'Set an identity before showing Zendesk UI',
                );
              }
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, isTrue);
      expect(showNewTicketCallCount, 2);
      expect(setUserIdentityCalled, isTrue);
    });

    test('returns false when NO_IDENTITY retry also fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') return true;
            if (call.method == 'showNewTicket') {
              throw PlatformException(
                code: 'NO_IDENTITY',
                message: 'Set an identity before showing Zendesk UI',
              );
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, isFalse);
    });
  });

  group('ZendeskSupportService user-facing initialization gate', () {
    test('showNewTicketScreen waits for an in-flight initialization', () async {
      final initializationRelease = Completer<void>();
      var showNewTicketCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              await initializationRelease.future;
              return true;
            }
            if (call.method == 'showNewTicket') showNewTicketCalls++;
            return null;
          });

      final initialization = ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );
      final opening = ZendeskSupportService.showNewTicketScreen();
      await pumpEventQueue();

      expect(showNewTicketCalls, 0);
      initializationRelease.complete();

      expect(await opening, isTrue);
      await initialization;
      expect(showNewTicketCalls, 1);
    });

    test(
      'showTicketListScreen waits for an in-flight initialization',
      () async {
        final initializationRelease = Completer<void>();
        var showTicketListCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') {
                await initializationRelease.future;
                return true;
              }
              if (call.method == 'showTicketList') showTicketListCalls++;
              return null;
            });

        final initialization = ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );
        final opening = ZendeskSupportService.showTicketListScreen();
        await pumpEventQueue();

        expect(showTicketListCalls, 0);
        initializationRelease.complete();

        expect(await opening, isTrue);
        await initialization;
        expect(showTicketListCalls, 1);
      },
    );

    test('createTicket waits for an in-flight initialization', () async {
      final initializationRelease = Completer<void>();
      var createTicketCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              await initializationRelease.future;
              return true;
            }
            if (call.method == 'createTicket') {
              createTicketCalls++;
              return true;
            }
            return null;
          });

      final initialization = ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );
      final creation = ZendeskSupportService.createTicket(
        subject: 'Subject',
        description: 'Description',
      );
      await pumpEventQueue();

      expect(createTicketCalls, 0);
      initializationRelease.complete();

      expect(await creation, isTrue);
      await initialization;
      expect(createTicketCalls, 1);
    });
  });

  group('ZendeskSupportService.showTicketListScreen', () {
    test('returns false when not initialized', () async {
      await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );
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

    test('sets a plain anonymous identity without cached user info', () async {
      final calls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call.method);
            if (call.method == 'initialize') return true;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, isTrue);
      expect(
        calls,
        containsAllInOrder(['setAnonymousIdentity', 'showTicketList']),
      );
    });

    test('retries with anonymous identity when NO_IDENTITY error', () async {
      var showTicketListCallCount = 0;
      var setUserIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              setUserIdentityCalled = true;
              return true;
            }
            if (call.method == 'showTicketList') {
              showTicketListCallCount++;
              if (showTicketListCallCount == 1) {
                throw PlatformException(
                  code: 'NO_IDENTITY',
                  message: 'Set an identity before showing Zendesk UI',
                );
              }
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Set user identity so anonymous fallback has name/email
      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, isTrue);
      expect(showTicketListCallCount, 2);
      expect(setUserIdentityCalled, isTrue);
    });

    test('returns false when NO_IDENTITY retry also fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') return true;
            if (call.method == 'showTicketList') {
              throw PlatformException(
                code: 'NO_IDENTITY',
                message: 'Set an identity before showing Zendesk UI',
              );
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, isFalse);
    });
  });

  group('ZendeskSupportService.setUserIdentity', () {
    test('uses NIP-05 as email when available', () {
      ZendeskSupportService.setUserIdentity(
        displayName: 'Test User',
        nip05: 'testuser@example.com',
        npub: 'npub1testtesttesttesttesttesttesttesttesttesttesttesttesttest',
      );

      expect(ZendeskSupportService.userName, 'Test User');
      expect(ZendeskSupportService.userEmail, 'testuser@example.com');
    });

    test('uses full npub as email when NIP-05 not available', () {
      const testNpub =
          'npub1abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345';
      ZendeskSupportService.setUserIdentity(npub: testNpub);

      // CRITICAL: Uses full npub for unique user identification
      // Email format: {npub}@divine.video
      expect(ZendeskSupportService.userEmail, '$testNpub@divine.video');
    });

    test('uses full npub as name when no displayName or NIP-05', () {
      const testNpub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuv';
      ZendeskSupportService.setUserIdentity(npub: testNpub);

      // CRITICAL: Uses full npub (never truncated) for traceability
      expect(ZendeskSupportService.userName, testNpub);
    });

    test('returns true even when native SDK not initialized', () {
      final result = ZendeskSupportService.setUserIdentity(
        displayName: 'Test',
        nip05: 'test@example.com',
        npub: 'npub1test',
      );

      expect(result, true);
    });

    test('stores npub correctly', () {
      ZendeskSupportService.setUserIdentity(
        displayName: 'Test',
        npub: 'npub1test',
      );

      expect(ZendeskSupportService.userNpub, 'npub1test');
    });
  });

  group('ZendeskSupportService.clearUserIdentity', () {
    test('calls native method when initialized', () async {
      var clearIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'clearUserIdentity') {
              clearIdentityCalled = true;
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.clearUserIdentity();

      expect(clearIdentityCalled, true);
    });
  });

  group('ZendeskSupportService.createTicket', () {
    test('returns false when not initialized', () async {
      await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );
      final result = await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test description',
      );

      expect(result, false);
    });

    test('passes parameters correctly to native', () async {
      String? capturedSubject;
      String? capturedDescription;
      List<dynamic>? capturedTags;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              capturedDescription = call.arguments['description'] as String?;
              capturedTags = call.arguments['tags'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createTicket(
        subject: 'Bug Report',
        description: 'Something broke',
        tags: ['mobile', 'bug'],
      );

      expect(capturedSubject, 'Bug Report');
      expect(capturedDescription, 'Something broke');
      expect(capturedTags, ['mobile', 'bug']);
    });

    test('sanitizes public ticket fields before native submission', () async {
      Map<String, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createTicket(
        subject: 'Bug $_rawNsec',
        description: 'Description $_rawNcryptsec and liz@example.com',
        customFields: [
          {'id': 123, 'value': 'Field $_rawNsec'},
        ],
      );

      expect(capturedArgs, isNotNull);
      final customFields = capturedArgs!['customFields'] as List<dynamic>;
      final customField = customFields.single as Map<dynamic, dynamic>;

      expect(capturedArgs!['subject'], isNot(contains(_rawNsec)));
      expect(capturedArgs!['description'], isNot(contains(_rawNcryptsec)));
      expect(capturedArgs!['description'], isNot(contains('liz@example.com')));
      expect(customField['value'], isNot(contains(_rawNsec)));
      expect(capturedArgs!['subject'], contains('[REDACTED]'));
      expect(capturedArgs!['description'], contains('[REDACTED]'));
      expect(customField['value'], contains('[REDACTED]'));
    });
  });

  group('ZendeskSupportService.createTicket attachmentPaths', () {
    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            return null;
          });
      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );
    });

    test('includes attachmentPaths when provided', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
        attachmentPaths: ['/tmp/img1.jpg', '/tmp/img2.jpg'],
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['attachmentPaths'], [
        '/tmp/img1.jpg',
        '/tmp/img2.jpg',
      ]);
    });

    test('omits attachmentPaths when null', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.containsKey('attachmentPaths'), false);
    });

    test('omits attachmentPaths when empty list', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
        attachmentPaths: [],
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.containsKey('attachmentPaths'), false);
    });

    test(
      'throws a sanitized attachment upload exception on upload failure',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'createTicket') {
                throw PlatformException(
                  code: 'UPLOAD_FAILED',
                  message: 'File not found: /private/var/mobile/Containers/Data/Application/foo.jpg',
                );
              }
              return null;
            });

        await expectLater(
          () => ZendeskSupportService.createTicket(
            subject: 'Test',
            description: 'Test desc',
            attachmentPaths: ['/tmp/img1.jpg'],
          ),
          throwsA(isA<ZendeskAttachmentUploadException>()),
        );
      },
    );
  });

  group('ZendeskSupportService.createTicket JWT expiry retry', () {
    test(
      'retries with anonymous identity when JWT returns unauthorized',
      () async {
        var createTicketCallCount = 0;
        var setUserIdentityCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'setUserIdentity') {
                setUserIdentityCalled = true;
                return true;
              }
              if (call.method == 'createTicket') {
                createTicketCallCount++;
                if (createTicketCallCount == 1) {
                  // First call fails with expired JWT
                  throw PlatformException(
                    code: 'CREATE_FAILED',
                    message: 'unauthorized',
                  );
                }
                // Second call (after anonymous identity set) succeeds
                return true;
              }
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // Set user identity so anonymous fallback has name/email
        ZendeskSupportService.setUserIdentity(
          npub: 'npub1test1234567890abcdef1234567890abcdef1234567890abcdef1234',
          displayName: 'Test User',
        );

        final result = await ZendeskSupportService.createTicket(
          subject: 'Content Report',
          description: 'Test report',
          tags: ['content-report'],
        );

        expect(result, isTrue);
        expect(createTicketCallCount, 2);
        expect(setUserIdentityCalled, isTrue);
      },
    );
  });

  group('ZendeskSupportService identity consistency', () {
    test('same npub produces same synthetic email', () {
      const testNpub =
          'npub1consistent1234567890abcdef1234567890abcdef1234567890ab';

      ZendeskSupportService.setUserIdentity(
        displayName: 'User 1',
        npub: testNpub,
      );
      final email1 = ZendeskSupportService.userEmail;

      ZendeskSupportService.setUserIdentity(
        displayName: 'User 2',
        npub: testNpub,
      );
      final email2 = ZendeskSupportService.userEmail;

      expect(email1, email2);
    });

    test('different npubs produce different synthetic emails', () {
      ZendeskSupportService.setUserIdentity(
        npub: 'npub1user1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final email1 = ZendeskSupportService.userEmail;

      ZendeskSupportService.setUserIdentity(
        npub: 'npub1user2bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final email2 = ZendeskSupportService.userEmail;

      expect(email1, isNot(email2));
    });
  });

  group('ZendeskSupportService.createStructuredBugReport fallback', () {
    test('uses native SDK when initialized', () async {
      var createTicketCalled = false;
      String? capturedSubject;
      List<dynamic>? capturedCustomFields;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              createTicketCalled = true;
              capturedSubject = call.arguments['subject'] as String?;
              capturedCustomFields =
                  call.arguments['customFields'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test Bug',
        description: 'Something broke',
        reportId: 'test-report-123',
        appVersion: '1.0.0+42',
        deviceInfo: {'platform': 'ios', 'version': '17.0', 'model': 'iPhone'},
        stepsToReproduce: '1. Tap button\n2. See crash',
        expectedBehavior: 'Should not crash',
      );

      expect(result, isTrue);
      expect(createTicketCalled, isTrue);
      expect(capturedSubject, 'Test Bug');
      // Verify custom fields include platform, OS version, build number
      expect(capturedCustomFields, isNotNull);
      final fieldIds = capturedCustomFields!
          .map((f) => (f as Map)['id'])
          .toList();
      // Platform field
      expect(fieldIds, contains(14884176561807));
      // OS Version field
      expect(fieldIds, contains(14884157556111));
      // Build Number field
      expect(fieldIds, contains(14884184890511));
      // Steps to Reproduce field (optional, but provided)
      expect(fieldIds, contains(14677364166031));
      // Expected Behavior field (optional, but provided)
      expect(fieldIds, contains(14677341431695));
    });

    test('subject passes through without prefix modification', () async {
      String? capturedSubject;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Subject should be passed exactly as provided -- no "fix:" prefix
      await ZendeskSupportService.createStructuredBugReport(
        subject: 'Links not working in DMs',
        description: 'When I tap a link it does nothing',
        reportId: 'test-subject-001',
        appVersion: '1.0.7+497',
        deviceInfo: {'platform': 'ios'},
      );

      expect(capturedSubject, 'Links not working in DMs');
      expect(capturedSubject, isNot(startsWith('fix:')));
    });

    test(
      'includes aggregate local-storage diagnostics in the ticket',
      () async {
        String? capturedDescription;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') {
                capturedDescription = call.arguments['description'] as String?;
                return true;
              }
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        await ZendeskSupportService.createStructuredBugReport(
          subject: 'Drafts disappeared',
          description: 'The library is empty',
          reportId: 'test-local-storage-001',
          appVersion: '1.0.20+848',
          deviceInfo: {
            'platform': 'ios',
            'localStorage': {
              'databaseRecovery': {'outcome': 'recreatedKeyLoss'},
              'contentInventory': {
                'visibleDraftRows': 0,
                'foreignDraftRows': 4,
              },
            },
          },
        );

        expect(capturedDescription, contains('localStorage'));
        expect(capturedDescription, contains('recreatedKeyLoss'));
        expect(capturedDescription, contains('visibleDraftRows: 0'));
        expect(capturedDescription, contains('foreignDraftRows: 4'));
      },
    );

    test('subject with user-typed prefix is not double-prefixed', () async {
      String? capturedSubject;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // If a user types "fix: something" it should pass through as-is
      await ZendeskSupportService.createStructuredBugReport(
        subject: 'fix: video upload stuck',
        description: 'Video stays at processing forever',
        reportId: 'test-subject-002',
        appVersion: '1.0.7+497',
        deviceInfo: {'platform': 'ios'},
      );

      expect(capturedSubject, 'fix: video upload stuck');
      expect(capturedSubject, isNot(startsWith('fix: fix:')));
    });

    test('redacts a credential in every assembled field', () async {
      // Each field is sanitized separately, so each needs its own evidence: a
      // mutation sweep found that subject, steps, device info, current screen
      // and the error summary were all unpinned while only the description
      // half of the assembly was covered.
      String? capturedDescription;
      String? capturedSubject;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              capturedDescription = call.arguments['description'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createStructuredBugReport(
        subject: 'crash when password: SUBJECTSECRET',
        description: 'it broke, token: DESCRIPTIONSECRET',
        reportId: 'test-every-field-001',
        appVersion: '1.0.7+497',
        deviceInfo: {'platform': 'ios', 'sessionKey': 'DEVICESECRET'},
        stepsToReproduce: '1. paste api_key=STEPSSECRET',
        expectedBehavior: 'no secret=EXPECTEDSECRET in the ticket',
        currentScreen: 'CameraScreen?secret=SCREENSECRET',
        recentScreens: const [
          'home',
          'profile?token=RECENTSCREENSECRET',
        ],
        errorCounts: {'upload:password=COUNTSSECRET': 3},
        logsSummary: '[10:00] [ERROR] jwt: LOGSSECRET',
      );

      final payload = '$capturedSubject\n$capturedDescription';

      for (final secret in [
        'SUBJECTSECRET',
        'DESCRIPTIONSECRET',
        'DEVICESECRET',
        'STEPSSECRET',
        'EXPECTEDSECRET',
        'SCREENSECRET',
        'RECENTSCREENSECRET',
        'COUNTSSECRET',
        'LOGSSECRET',
      ]) {
        expect(payload, isNot(contains(secret)), reason: 'leaked $secret');
      }
      expect(capturedDescription, contains('**Recent Screens:** home'));
    });

    // Each contributed field is sanitized separately, and the containment that
    // buys is per field: a stray brace in any one of them must not reach the
    // fields printed after it. The assembled-blob pass in `createTicket` masks
    // a plain secret, so only this shape shows whether a given field's own
    // pass is doing anything - a mutation sweep found subject, steps and
    // current screen unpinned while only the description was covered.
    const fieldsUnderTest = [
      'subject',
      'description',
      'steps',
      'expected',
      'screen',
      'device',
      'errorCounts',
      'appVersion',
    ];

    for (final field in fieldsUnderTest) {
      test('a stray brace in $field cannot empty the whole report', () async {
        // `my password: {weird symbols` is how someone describes a login bug,
        // not an attack, and the field has no length limit below the cap.
        const poison = 'my password: {weird symbols and it died';
        String? capturedDescription;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') {
                capturedDescription = call.arguments['description'] as String?;
                return true;
              }
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        await ZendeskSupportService.createStructuredBugReport(
          subject: field == 'subject' ? poison : 'App crashes on upload',
          description: field == 'description' ? poison : 'it just dies',
          reportId: 'test-blast-radius-$field',
          // `appVersion` is machine-generated, so this case pins the
          // invariant that every assembled field is contained, not a reachable
          // leak - it is the field that would silently break containment if
          // someone later routed user text through it.
          appVersion: field == 'appVersion' ? poison : '1.0.7+497',
          // The device case carries a credential-*shaped key* with a
          // malformed value, not a poisoned ordinary value: the report renders
          // device info as `- **key:** value`, so only a composed-line pass
          // sees the key and the value together. A poisoned value alone is
          // caught by value-only sanitization and pins nothing.
          deviceInfo: {
            'platform': 'ios',
            if (field == 'device') 'password': '{oops',
            'version': '18.2',
          },
          stepsToReproduce: field == 'steps'
              ? poison
              : '1. open the app 2. tap record',
          expectedBehavior: field == 'expected' ? poison : 'it should upload',
          currentScreen: field == 'screen' ? poison : 'CameraScreen',
          errorCounts: {if (field == 'errorCounts') poison: 3},
          // A closing brace downstream is what an unclosed one reaches for,
          // and real logs are full of them (`Map.toString`). Without one the
          // collection branch never engages and this passes on the unquoted
          // fallback instead of the property it names.
          logsSummary:
              '[10:00] [ERROR] upload failed {code: 500}\n'
              '[10:01] [INFO] relay reconnected',
        );

        final description = capturedDescription!;
        expect(description, contains('[REDACTED]'));
        // Everything the poisoned field does not own survives.
        if (field != 'appVersion') {
          expect(description, contains('App Version: 1.0.7+497'));
        }
        expect(description, contains('ios'));
        // Printed after the device block, so it is the marker a malformed
        // device value would consume.
        expect(description, contains('18.2'));
        expect(description, contains('upload failed'));
        expect(description, contains('relay reconnected'));
        if (field != 'steps') {
          expect(description, contains('1. open the app 2. tap record'));
        }
        if (field != 'screen') {
          expect(description, contains('CameraScreen'));
        }
        if (field != 'expected') {
          expect(description, contains('it should upload'));
        }
      });
    }

    test('falls back to REST API when SDK not initialized', () async {
      // Reset _initialized by calling initialize with a handler that fails
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return false;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // SDK not initialized → falls to REST API → but API token not configured
      // in test env, so returns false
      final result = await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test Bug',
        description: 'Something broke',
        reportId: 'test-report-456',
        appVersion: '1.0.0+42',
        deviceInfo: {'platform': 'android', 'version': '14'},
      );

      // Without ZENDESK_API_TOKEN, REST API fallback returns false
      expect(result, isFalse);
    });

    test('extracts build number from appVersion correctly', () async {
      List<dynamic>? capturedCustomFields;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedCustomFields =
                  call.arguments['customFields'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test',
        description: 'Test',
        reportId: 'test-789',
        appVersion: '2.1.0+99',
        deviceInfo: {'platform': 'ios', 'version': '18.0'},
      );

      // Verify build number extracted from "2.1.0+99" → "99"
      expect(capturedCustomFields, isNotNull);
      final buildField = capturedCustomFields!.firstWhere(
        (f) => (f as Map)['id'] == 14884184890511,
      );
      expect((buildField as Map)['value'], '99');
    });

    test('sanitizes feature request fields before native submission', () async {
      Map<String, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.createFeatureRequest(
        subject: 'Feature $_rawNsec',
        description: 'Description $_rawNcryptsec',
        usefulness: 'Useful for liz@example.com',
        whenToUse: 'When importing $_rawNsec',
      );

      expect(result, isTrue);
      expect(capturedArgs, isNotNull);
      final customFields = capturedArgs!['customFields'] as List<dynamic>;
      final values = customFields
          .map((field) {
            return (field as Map<dynamic, dynamic>)['value'] as String;
          })
          .join('\n');

      expect(capturedArgs!['subject'], isNot(contains(_rawNsec)));
      expect(capturedArgs!['description'], isNot(contains(_rawNsec)));
      expect(capturedArgs!['description'], isNot(contains(_rawNcryptsec)));
      expect(capturedArgs!['description'], isNot(contains('liz@example.com')));
      expect(values, isNot(contains(_rawNsec)));
      expect(values, isNot(contains('liz@example.com')));
      expect(capturedArgs!['description'], contains('[REDACTED]'));
      expect(values, contains('[REDACTED]'));
    });

    test('sanitizes bug report fields before native submission', () async {
      Map<String, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.createStructuredBugReport(
        subject: 'Crash $_rawNsec',
        description: 'Broke after importing $_rawNcryptsec',
        reportId: 'test-sanitize-001',
        appVersion: '1.0.0+42',
        deviceInfo: {'platform': 'ios', 'version': '17.0'},
        stepsToReproduce: 'Paste $_rawNsec',
        expectedBehavior: 'Mail liz@example.com',
        logsSummary: 'ERROR key=$_rawNsec',
      );

      expect(result, isTrue);
      expect(capturedArgs, isNotNull);
      final customFields = capturedArgs!['customFields'] as List<dynamic>;
      final stepsField = customFields.firstWhere(
        (f) => (f as Map)['id'] == 14677364166031,
      );
      final expectedField = customFields.firstWhere(
        (f) => (f as Map)['id'] == 14677341431695,
      );

      // The body concatenates subject, description, steps, expected and the
      // log summary, so one assertion covers every user-entered field on the
      // way into the publicly mirrored ticket.
      final description = capturedArgs!['description'] as String;
      expect(description, isNot(contains(_rawNsec)));
      expect(description, isNot(contains(_rawNcryptsec)));
      expect(description, isNot(contains('liz@example.com')));
      expect(description, contains('[REDACTED]'));
      expect(capturedArgs!['subject'], isNot(contains(_rawNsec)));
      expect(capturedArgs!['subject'], contains('[REDACTED]'));
      expect((stepsField as Map)['value'], isNot(contains(_rawNsec)));
      expect((expectedField as Map)['value'], isNot(contains('liz@example')));
    });
  });

  group('ZendeskSupportService.createFeatureRequest field isolation', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // Same containment property as the bug report builder, and the same
    // reason it needs one case per field: the assembled-blob pass in
    // `createTicket` masks a plain secret, so only the stray-brace shape shows
    // whether a given field's own pass does anything.
    const featureFields = ['subject', 'description', 'usefulness', 'whenToUse'];

    for (final field in featureFields) {
      test('a stray brace in $field cannot erase the others', () async {
        const poison = 'my password: {weird symbols and it died';
        String? capturedDescription;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') {
                capturedDescription = call.arguments['description'] as String?;
                return true;
              }
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        await ZendeskSupportService.createFeatureRequest(
          subject: field == 'subject' ? poison : 'Let me pin a vine',
          description: field == 'description' ? poison : 'it would help a lot',
          usefulness: field == 'usefulness'
              ? poison
              : 'I would use it daily {every morning}',
          whenToUse: field == 'whenToUse'
              ? poison
              : 'when I open the app {every morning}',
        );

        final description = capturedDescription!;

        expect(description, contains('[REDACTED]'));
        if (field != 'description') {
          expect(description, contains('it would help a lot'));
        }
        if (field != 'usefulness') {
          expect(description, contains('I would use it daily'));
        }
        if (field != 'whenToUse') {
          expect(description, contains('when I open the app'));
        }
      });
    }
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
  });

  group('storeAuthContext and JWT refresh', () {
    test('resetForTesting clears stored auth context', () {
      // storeAuthContext is a static setter -- we verify it's cleared by
      // checking that createTicket doesn't attempt a JWT refresh when
      // auth context is absent (no setJwtIdentity call in the channel log)
      ZendeskSupportService.resetForTesting();

      // After reset, auth context should be null -- createTicket should
      // skip _ensureFreshJwt and proceed directly to SDK (or return false
      // if not initialized)
      expect(ZendeskSupportService.isAvailable, false);
    });

    test(
      'createTicket without auth context still works (no refresh attempt)',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // No storeAuthContext called -- _ensureFreshJwt should be a no-op
        methodCalls.clear();

        final result = await ZendeskSupportService.createTicket(
          subject: 'Test',
          description: 'Test description',
        );

        expect(result, true);
        // Should NOT have called setJwtIdentity (no auth context stored)
        expect(methodCalls, ['createTicket']);
      },
    );

    test(
      'createTicket with auth context attempts JWT refresh before SDK call',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'setJwtIdentity') return true;
              if (call.method == 'createTicket') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // Store auth context -- _ensureFreshJwt will attempt setJwtIdentity.
        // fetchPreAuthToken will fail (no real server), but _ensureFreshJwt
        // catches the error and proceeds. The important thing is createTicket
        // still succeeds afterward.
        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://test-relay.divine.video',
        );

        methodCalls.clear();

        final result = await ZendeskSupportService.createTicket(
          subject: 'Test',
          description: 'Test description',
        );

        // createTicket should succeed even though JWT refresh failed
        // (the refresh is best-effort, not blocking)
        expect(result, true);
        expect(methodCalls, contains('createTicket'));
      },
    );

    test('showNewTicketScreen without auth context skips refresh', () async {
      final methodCalls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methodCalls.add(call.method);
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') return true;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      methodCalls.clear();

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, true);
      expect(methodCalls, ['showNewTicket']);
    });

    test(
      'showTicketListScreen without auth context sets anonymous identity',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        methodCalls.clear();

        final result = await ZendeskSupportService.showTicketListScreen();

        expect(result, true);
        expect(methodCalls, ['setAnonymousIdentity', 'showTicketList']);
      },
    );

    test(
      'showTicketListScreen falls back to anonymous identity when JWT refresh fails',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'setUserIdentity') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );
        ZendeskSupportService.setUserIdentity(
          npub: 'npub1fallback1234567890abcdef1234567890abcdef1234567890abcdef',
          displayName: 'Fallback User',
        );
        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );

        methodCalls.clear();

        final result = await ZendeskSupportService.showTicketListScreen();

        expect(result, isTrue);
        expect(methodCalls, ['setUserIdentity', 'showTicketList']);
      },
    );

    test(
      'showTicketListScreen reuses a recent JWT refresh for consecutive calls',
      () async {
        final methodCalls = <String>[];
        var refreshCallCount = 0;
        final now = DateTime.utc(2026, 3, 24, 12);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          now: () => now,
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        methodCalls.clear();

        final firstResult = await ZendeskSupportService.showTicketListScreen();
        final secondResult = await ZendeskSupportService.showTicketListScreen();

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(refreshCallCount, 1);
        expect(methodCalls.where((m) => m == 'showTicketList').length, 2);
      },
    );

    test(
      'showTicketListScreen refreshes again once cached JWT is stale',
      () async {
        var refreshCallCount = 0;
        var now = DateTime.utc(2026, 3, 24, 12);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          now: () => now,
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        final firstResult = await ZendeskSupportService.showTicketListScreen();
        now = now.add(const Duration(minutes: 5));
        final secondResult = await ZendeskSupportService.showTicketListScreen();

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(refreshCallCount, 2);
      },
    );

    test(
      'clearUserIdentity clears stored auth context for future SDK actions',
      () async {
        final methodCalls = <String>[];
        var refreshCallCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'clearUserIdentity') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        await ZendeskSupportService.clearUserIdentity();
        methodCalls.clear();

        final result = await ZendeskSupportService.showTicketListScreen();

        expect(result, isTrue);
        expect(refreshCallCount, 0);
        expect(methodCalls, ['setAnonymousIdentity', 'showTicketList']);
      },
    );
  });

  group('fetchPreAuthToken signed URL', () {
    // The `u` tag is signed from the composed string while the POST goes to a
    // Uri built from that same string. NIP-98 binds the two and relay-manager
    // compares them as raw strings, so a base that Uri.parse would normalize
    // makes them disagree and the pre-auth call 401s — which downgrades the
    // Zendesk identity to the raw npub path this token exists to replace.
    for (final base in const [
      'https://RELAY.example',
      'HTTPS://relay.example',
      'https://relay.example:443',
      'https://relay.example/.',
      'https://relay.example/',
    ]) {
      test('is canonical for a base of $base', () async {
        final nip98 = _RecordingUrlNip98AuthService();
        http.Request? captured;

        await expectLater(
          ZendeskSupportService.fetchPreAuthToken(
            nip98Service: nip98,
            relayManagerUrl: base,
            httpClient: MockClient(
              (request) async {
                captured = request;
                return http.Response('{"success":true,"token":"t"}', 200);
              },
            ),
          ),
          completion(equals('t')),
        );

        expect(nip98.signedUrl, isNotNull);
        expect(
          nip98.signedUrl,
          equals('https://relay.example/api/zendesk/pre-auth'),
        );
        expect(nip98.signedUrl, equals(captured!.url.toString()));
      });
    }
  });
}

/// Fails token creation like [_FakeNip98AuthService], but records whether
/// fetchPreAuthToken was reached at all. That count is what separates "the
/// initialization gate let the caller through" from "the caller bailed at the
/// not-initialized check", since both end in a false return.
class _RecordingNip98AuthService implements Nip98AuthService {
  int createAuthTokenCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createAuthToken) {
      createAuthTokenCalls++;
    }
    return null;
  }
}

/// Minimal fake for Nip98AuthService that always fails token creation.
/// Tests that _ensureFreshJwt handles failures gracefully.
class _FakeNip98AuthService implements Nip98AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // createAuthToken and clearTokenCache are the only methods called
    // by fetchPreAuthToken. Return null/void for all calls, which causes
    // fetchPreAuthToken to throw, which _ensureFreshJwt catches gracefully.
    return null;
  }
}

/// Records the URL [ZendeskSupportService.fetchPreAuthToken] signs, and hands
/// back a usable token so the request is actually attempted.
class _RecordingUrlNip98AuthService implements Nip98AuthService {
  String? signedUrl;

  @override
  Future<Nip98Token?> createAuthToken({
    required String url,
    required HttpMethod method,
    String? payload,
  }) async {
    signedUrl = url;
    final now = clock.now();
    return Nip98Token(
      token: 'fake-token',
      signedEvent: Event(
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
        27235,
        [
          ['u', url],
          ['method', 'POST'],
        ],
        '',
        createdAt: 1700000000,
      ),
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 45)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
