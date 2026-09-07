// ABOUTME: Unit tests for ContentReportingService
// ABOUTME: Tests NIP-56 content reporting including AI-generated content reports

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingReportsDao extends Mock implements PendingReportsDao {}

class _FakeEvent extends Fake implements Event {}

String _validEventId(String hexDigit) => List.filled(64, hexDigit).join();

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(ReportChannel.relay);
    registerFallbackValue(
      PendingReport(
        reportId: 'fallback',
        userPubkey: 'fallback',
        eventJson: '{}',
        zendeskPayload: '{}',
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  // Outside the ContentReportingService group on purpose: these tags are a
  // pure function of the reason and the blob hash, so the test needs none of
  // that group's mocks, keys, or SharedPreferences setup.
  group('ContentReportingService.moderationDmTags', () {
    test('emits the L, l and report_type rows in the frozen order', () {
      // aiGenerated is the reason the whole change exists for: NIP-56
      // collapses it to 'other' while the NIP-32 label stays granular, so a
      // swapped or collapsed value cannot pass this assertion.
      expect(
        ContentReportingService.moderationDmTags(
          reason: ContentFilterReason.aiGenerated,
        ),
        equals([
          ['L', 'social.nos.ontology'],
          ['l', 'NS-aiGenerated', 'social.nos.ontology'],
          ['report_type', 'other'],
        ]),
      );
    });

    test('appends sha256 as the last tag when a blob hash is present', () {
      final tags = ContentReportingService.moderationDmTags(
        reason: ContentFilterReason.spam,
        sha256: 'a' * 64,
      );

      expect(tags, hasLength(4));
      expect(tags.last, equals(['sha256', 'a' * 64]));
    });

    for (final (label, sha256) in [
      ('null', null),
      ('empty', ''),
      ('whitespace only', '   '),
      ('too short', 'a' * 63),
      ('too long', 'a' * 65),
      ('not hex', 'g' * 64),
    ]) {
      test('omits sha256 when the hash is $label', () {
        expect(
          ContentReportingService.moderationDmTags(
            reason: ContentFilterReason.spam,
            sha256: sha256,
          ).where((tag) => tag.first == 'sha256'),
          isEmpty,
          reason:
              'user_reports.sha256 is NOT NULL server-side; a malformed tag '
              'would let a bad report through instead of degrading cleanly to '
              'no report row',
        );
      });
    }

    test('normalizes a valid hash the publishing client wrote oddly', () {
      // VideoEvent.sha256 is the imeta `x` tag verbatim, unvalidated. A padded
      // hash is a real hash that fails the backend's anchored check, silently
      // filing no report at all. Case is canonicalised for the same reason a
      // key should be canonical, not because the backend needs it to be.
      expect(
        ContentReportingService.moderationDmTags(
          reason: ContentFilterReason.spam,
          sha256: '  ${'AB' * 32}  ',
        ).last,
        equals(['sha256', 'ab' * 32]),
      );
    });

    test('falls back to the Blossom URL when the explicit hash is absent', () {
      expect(
        ContentReportingService.moderationDmTags(
          reason: ContentFilterReason.spam,
          videoUrl: 'https://blossom.example/${'b' * 64}.mp4',
        ).last,
        equals(['sha256', 'b' * 64]),
      );
    });

    test('prefers the explicit hash over the Blossom URL fallback', () {
      expect(
        ContentReportingService.moderationDmTags(
          reason: ContentFilterReason.spam,
          sha256: 'a' * 64,
          videoUrl: 'https://blossom.example/${'b' * 64}.mp4',
        ).last,
        equals(['sha256', 'a' * 64]),
      );
    });
  });

  group('ContentReportingService', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late ContentReportingService service;
    late SharedPreferences prefs;
    late String testPrivateKey;
    late String testPublicKey;

    Event createTestEvent({
      required String pubkey,
      required int kind,
      required List<List<String>> tags,
      required String content,
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    setUp(() async {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();

      // Setup common mocks
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

      service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        moderationRelayUrl: 'wss://relay.divine.video',
      );

      await service.initialize();
    });

    test(
      'initialize() sets service ready when Nostr service is ready',
      () async {
        // Service should be initialized (report history starts empty)
        expect(service.reportHistory, isEmpty);
      },
    );

    test(
      'initialize() fails gracefully when Nostr service not ready',
      () async {
        when(() => mockNostrService.isInitialized).thenReturn(false);

        final uninitializedService = ContentReportingService(
          nostrService: mockNostrService,
          authService: mockAuthService,
          prefs: prefs,
          moderationRelayUrl: 'wss://relay.divine.video',
        );

        await uninitializedService.initialize();

        // Should not throw, but won't be fully initialized
        expect(uninitializedService.reportHistory, isEmpty);
      },
    );

    test(
      'reportContent() fails when service not initialized '
      'and Nostr client still unready',
      () async {
        when(() => mockNostrService.isInitialized).thenReturn(false);

        final uninitializedService = ContentReportingService(
          nostrService: mockNostrService,
          authService: mockAuthService,
          prefs: prefs,
          moderationRelayUrl: 'wss://relay.divine.video',
        );

        final result = await uninitializedService.reportContent(
          eventId: 'test_event_id',
          authorPubkey: 'test_author',
          reason: ContentFilterReason.spam,
          details: 'Spam content',
        );

        expect(result.success, isFalse);
        expect(result.error, 'Reporting service not initialized');
      },
    );

    test(
      'reportContent() recovers via late initialization when '
      'Nostr client becomes ready after construction',
      () async {
        when(() => mockNostrService.isInitialized).thenReturn(false);

        final lateInitService = ContentReportingService(
          nostrService: mockNostrService,
          authService: mockAuthService,
          prefs: prefs,
          moderationRelayUrl: 'wss://relay.divine.video',
        );

        await lateInitService.initialize();
        expect(lateInitService.isInitialized, isFalse);

        when(() => mockNostrService.isInitialized).thenReturn(true);

        final reportEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [
            ['e', _validEventId('a')],
            ['p', 'test_author'],
          ],
          content: 'Spam content',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

        final result = await lateInitService.reportContent(
          eventId: _validEventId('a'),
          authorPubkey: 'test_author',
          reason: ContentFilterReason.spam,
          details: 'Spam content',
        );

        expect(result.success, isTrue);
      },
    );

    test(
      'reportContent() succeeds for AI-generated content after initialization',
      () async {
        // Arrange
        final reportEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [
            ['e', _validEventId('a')],
            ['p', 'suspicious_author'],
          ],
          content: 'Suspected AI-generated content',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

        // Act
        final result = await service.reportContent(
          eventId: _validEventId('a'),
          authorPubkey: 'suspicious_author',
          reason: ContentFilterReason.other,
          details: 'Suspected AI-generated content',
        );

        // Assert
        expect(result.success, true);
        expect(result.error, isNull);

        // Verify createAndSignEvent was called with kind 1984 (NIP-56)
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: 1984,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);

        // Verify Nostr event was published to moderation relay
        verify(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'reportContent() silently refuses a self-report (target == reporter) '
      'without building or publishing any event (#8352)',
      () async {
        // Publishing WOULD succeed here — the point is that the guard refuses
        // before we ever reach signing or the relay.
        final wouldBeEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: const <List<String>>[],
          content: '',
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => wouldBeEvent);
        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => PublishSuccess(event: wouldBeEvent));

        // Act: target the reporter's own pubkey (== currentPublicKeyHex).
        final result = await service.reportContent(
          eventId: _validEventId('a'),
          authorPubkey: testPublicKey,
          reason: ContentFilterReason.other,
          details: 'accidental self-report',
        );

        // Silent success to the caller, nothing left the device, and neither
        // signing nor publishing was ever attempted.
        expect(result.success, isTrue);
        expect(result.delivery, ReportDelivery.refused);
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );

    test(
      'reportContent() self-report guard is case-insensitive (#8352)',
      () async {
        // authorPubkey can arrive uppercased (it is copied from Event.pubkey),
        // while currentPublicKeyHex is lowercase. The guard must still catch it.
        final result = await service.reportContent(
          eventId: _validEventId('a'),
          authorPubkey: testPublicKey.toUpperCase(),
          reason: ContentFilterReason.other,
          details: 'accidental self-report, upper-cased target',
        );

        expect(result.success, isTrue);
        expect(result.delivery, ReportDelivery.refused);
        verifyNever(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );

    test('reportContent() handles all ContentFilterReason types including '
        'aiGenerated', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Test report',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      const reasons = ContentFilterReason.values;

      for (final reason in reasons) {
        final result = await service.reportContent(
          eventId: _validEventId(reason.index.toRadixString(16)),
          authorPubkey: 'author_123',
          reason: reason,
          details: 'Test report for ${reason.name}',
        );

        expect(
          result.success,
          true,
          reason: 'Failed for reason: ${reason.name}',
        );
      }

      // Should have called createAndSignEvent once per reason
      verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(reasons.length);
    });

    test('reportContent() includes NIP-32 l/L tags for each reason', () async {
      const expectedNip32Labels = {
        ContentFilterReason.spam: 'NS-spam',
        ContentFilterReason.harassment: 'NS-harassment',
        ContentFilterReason.violence: 'NS-violence',
        ContentFilterReason.sexualContent: 'NS-sexualContent',
        ContentFilterReason.copyright: 'NS-copyright',
        ContentFilterReason.falseInformation: 'NS-falseInformation',
        ContentFilterReason.childSafety: 'NS-childSafety',
        ContentFilterReason.csam: 'NS-csam',
        ContentFilterReason.underageUser: 'NS-underageUser',
        ContentFilterReason.aiGenerated: 'NS-aiGenerated',
        ContentFilterReason.other: 'NS-other',
      };

      final capturedTags = <List<List<String>>>[];

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        capturedTags.add(tags);
        return createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: tags,
          content: 'test',
        );
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => PublishSuccess(
          event: createTestEvent(
            pubkey: testPublicKey,
            kind: 1984,
            tags: [],
            content: 'test',
          ),
        ),
      );

      for (final reason in ContentFilterReason.values) {
        final _ = await service.reportContent(
          eventId: _validEventId(reason.index.toRadixString(16)),
          authorPubkey: 'author_${reason.name}',
          reason: reason,
          details: 'Test ${reason.name}',
        );
      }

      expect(
        capturedTags,
        hasLength(ContentFilterReason.values.length),
        reason: 'Should have captured tags for each reason',
      );

      for (var i = 0; i < ContentFilterReason.values.length; i++) {
        final reason = ContentFilterReason.values[i];
        final tags = capturedTags[i];

        final eTags = tags.where((t) => t[0] == 'e').toList();
        expect(eTags, hasLength(1), reason: 'Missing e tag for ${reason.name}');

        final pTags = tags.where((t) => t[0] == 'p').toList();
        expect(pTags, hasLength(1), reason: 'Missing p tag for ${reason.name}');

        final clientTags = tags.where((t) => t[0] == 'client').toList();
        expect(
          clientTags,
          isEmpty,
          reason:
              'Client tag should be injected during signing for ${reason.name}',
        );

        final lNamespaceTags = tags.where((t) => t[0] == 'L').toList();
        expect(
          lNamespaceTags,
          hasLength(1),
          reason: 'Expected exactly one L tag for ${reason.name}',
        );
        expect(lNamespaceTags.single, ['L', 'social.nos.ontology']);

        final lTags = tags.where((t) => t[0] == 'l').toList();
        expect(
          lTags,
          hasLength(1),
          reason: 'Expected exactly one l tag for ${reason.name}',
        );
        expect(lTags.single, [
          'l',
          expectedNip32Labels[reason]!,
          'social.nos.ontology',
        ], reason: 'Missing or incorrect l tag for ${reason.name}');

        // Both report channels must label a reason identically, or the
        // backend resolves one report to two types depending on which
        // channel it ingested first (#6593). Compared against the tags this
        // kind-1984 event actually carried, so it fails if either channel
        // stops sharing the pair.
        expect(
          ContentReportingService.moderationDmTags(
            reason: reason,
          ).take(2).toList(),
          equals([lNamespaceTags.single, lTags.single]),
          reason:
              'Moderation DM and kind-1984 report disagree on the NIP-32 '
              'label for ${reason.name}',
        );
      }
    });

    test('reportContent() specifically tests aiGenerated reason', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [
          ['e', 'ai_content'],
          ['p', 'ai_creator'],
        ],
        content: 'Detected AI generation patterns',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      // Act - This should not throw an exception due to missing switch case
      final result = await service.reportContent(
        eventId: _validEventId('b'),
        authorPubkey: 'ai_creator',
        reason: ContentFilterReason.other,
        details: 'Detected AI generation patterns',
      );

      // Assert
      expect(result.success, true);
      expect(result.error, isNull);
    });

    test('keeps only the redacted copy in local history', () async {
      // Nothing reads this history today, which is exactly why the raw copy
      // should not sit there waiting for the first feature that surfaces,
      // exports or replays it.
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [
          ['e', _validEventId('e')],
          ['p', 'reported_author'],
        ],
        content: 'spam',
      );
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('e'),
        authorPubkey: 'reported_author',
        reason: ContentFilterReason.other,
        details: 'they posted my password: hunter2',
        additionalContext: 'and my api_key=SECRETKEY123',
      );

      final stored = service.reportHistory.last;
      expect(stored.details, contains('[REDACTED]'));
      expect(stored.details, isNot(contains('hunter2')));
      expect(stored.additionalContext, isNot(contains('SECRETKEY123')));
    });

    test('never publishes a credential in the kind 1984 event', () async {
      // The NIP-56 event goes to public relays: world-readable, permanent and
      // unretractable, so it is a worse destination for a pasted secret than
      // the Zendesk ticket. Both the content body and the `alt` tag carry
      // user-typed text.
      String? capturedContent;
      List<List<String>>? capturedTags;

      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [
          ['e', _validEventId('d')],
          ['p', 'reported_author'],
        ],
        content: 'spam',
      );
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedContent =
            invocation.namedArguments[const Symbol('content')] as String?;
        capturedTags =
            invocation.namedArguments[const Symbol('tags')]
                as List<List<String>>?;
        return reportEvent;
      });
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('d'),
        authorPubkey: 'reported_author',
        reason: ContentFilterReason.other,
        details: 'they posted my password: hunter2 and my token: abc123',
        additionalContext: 'also my api_key=SECRETKEY123',
      );

      expect(capturedContent, contains('[REDACTED]'));
      expect(capturedContent, isNot(contains('hunter2')));
      expect(capturedContent, isNot(contains('abc123')));
      expect(capturedContent, isNot(contains('SECRETKEY123')));
      // Redacting is not the same as deleting. Without these, dropping the
      // reporter's context entirely would satisfy the assertions above and
      // moderation would silently lose what the report was about.
      expect(capturedContent, contains('they posted my'));
      expect(capturedContent, contains('also my'));
      final altTag = capturedTags!.firstWhere((tag) => tag.first == 'alt');
      expect(altTag.last, contains('also my'));
      expect(altTag.last, contains('[REDACTED]'));
    });

    test(
      'a stray brace in details cannot erase the reporter context',
      () async {
        // Redaction spans lines, so sanitizing only the assembled ticket let a
        // credential key with an unclosed brace in `details` consume the
        // additional-context section printed after it. A moderation ticket that
        // silently loses the reporter's context is the same failure as a bug
        // report that arrives empty.
        const zendeskChannel = MethodChannel('com.openvine/zendesk_support');
        String? capturedDescription;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(zendeskChannel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') {
                capturedDescription = call.arguments['description'] as String?;
                return true;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(zendeskChannel, null);
        });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        final reportEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [
            ['e', _validEventId('c')],
            ['p', 'reported_author'],
          ],
          content: 'spam',
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => reportEvent);
        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

        final _ = await service.reportContent(
          eventId: _validEventId('c'),
          authorPubkey: 'reported_author',
          reason: ContentFilterReason.other,
          details: 'they posted my password: {and then more',
          // A closing brace downstream is what an unclosed one reaches for.
          additionalContext: 'this happened in a reply {twice}',
        );

        final description = capturedDescription!;

        expect(description, contains('[REDACTED]'));
        expect(description, contains('this happened in a reply'));
      },
    );

    test('reportContent() handles broadcast failures gracefully', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Spam content',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Mock failed publish - returns null on failure
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => const PublishFailed());

      // Act
      final result = await service.reportContent(
        eventId: _validEventId('1'),
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // Assert - Service is resilient: saves report locally even if broadcast
      // fails
      expect(result.success, true);
      expect(result.error, isNull);
      expect(result.reportId, isNotNull);
      // #6387: but resilient is not the same as delivered. Zendesk is not
      // initialized under test, so with the relay refusing too, nothing
      // left the device and the UI must not claim otherwise.
      expect(result.delivery, ReportDelivery.localOnly);

      // Verify report was saved to local history
      expect(service.reportHistory, isNotEmpty);
    });

    test('reportContent() saves report locally when PublishNoRelays', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Spam content',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => const PublishNoRelays());

      // Act
      final result = await service.reportContent(
        eventId: _validEventId('2'),
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // Assert — report is still saved locally regardless of relay state
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(service.reportHistory, isNotEmpty);
      // #6387: with no relay connected and Zendesk uninitialized, the
      // report is a local dead letter — nothing replays reportHistory.
      expect(result.delivery, ReportDelivery.localOnly);
    });

    test('reportContent() reports delivery when the relay accepts', () async {
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Spam content',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final result = await service.reportContent(
        eventId: _validEventId('3'),
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // The relay leg alone is enough — Zendesk is uninitialized under
      // test, so this also pins that delivery is a disjunction, not a
      // conjunction, of the two channels.
      expect(result.success, isTrue);
      expect(result.delivery, ReportDelivery.reached);
    });

    test('reportContent() stores report in history on success', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'AI detection',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      // Act
      final _ = await service.reportContent(
        eventId: _validEventId('3'),
        authorPubkey: 'bad_actor',
        reason: ContentFilterReason.other,
        details: 'AI detection',
      );

      // Assert
      expect(service.reportHistory, isNotEmpty);
      expect(service.reportHistory.first.reason, ContentFilterReason.other);
    });

    test('reportContent() fails when not authenticated', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.reportContent(
        eventId: 'test_event',
        authorPubkey: 'test_author',
        reason: ContentFilterReason.spam,
        details: 'Test',
      );

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Not authenticated'));

      // Verify createAndSignEvent was NOT called
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test(
      'reportContent() fails when createAndSignEvent returns null',
      () async {
        // Arrange
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        final result = await service.reportContent(
          eventId: 'test_event',
          authorPubkey: 'test_author',
          reason: ContentFilterReason.spam,
          details: 'Test',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Failed to create report event'));

        // Verify publishEvent was NOT called
        verifyNever(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );
  });

  group('NIP-56 tag compliance', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late ContentReportingService service;
    late String testPublicKey;

    setUp(() async {
      final testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

      service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        moderationRelayUrl: 'wss://relay.divine.video',
      );
      await service.initialize();
    });

    test('uses EventKind.report (1984) as kind', () async {
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('4'),
        authorPubkey: 'author_1',
        reason: ContentFilterReason.spam,
        details: 'test',
      );

      verify(
        () => mockAuthService.createAndSignEvent(
          kind: EventKind.report,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);

      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: ['wss://relay.divine.video'],
        ),
      ).called(1);
    });

    test('publishes report to the configured moderation relay', () async {
      const customRelay = 'wss://relay.staging.divine.video';
      SharedPreferences.setMockInitialValues({});
      final testPrefs = await SharedPreferences.getInstance();
      final stagingService = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: testPrefs,
        moderationRelayUrl: customRelay,
      );
      await stagingService.initialize();

      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await stagingService.reportContent(
        eventId: _validEventId('5'),
        authorPubkey: 'author_relay',
        reason: ContentFilterReason.other,
        details: 'relay routing test',
      );

      verify(
        () => mockNostrService.publishEvent(any(), targetRelays: [customRelay]),
      ).called(1);
    });

    test(
      'publishes report to moderation and source relays when provided',
      () async {
        const sourceRelay = 'wss://relay.staging.dvines.org';
        final reportEvent = Event(
          testPublicKey,
          EventKind.report,
          [],
          'test',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        reportEvent.id = 'test_id';
        reportEvent.sig = 'test_sig';

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

        final _ = await service.reportContent(
          eventId: _validEventId('5'),
          authorPubkey: 'author_source_relay',
          reason: ContentFilterReason.other,
          details: 'source relay routing test',
          sourceRelay: '  $sourceRelay  ',
        );

        verify(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: ['wss://relay.divine.video', sourceRelay],
          ),
        ).called(1);
      },
    );

    test('dedupes source relay when it matches configured relay', () async {
      const sourceRelay = 'wss://relay.divine.video';
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('6'),
        authorPubkey: 'author_source_relay',
        reason: ContentFilterReason.other,
        details: 'source relay dedupe test',
        sourceRelay: sourceRelay,
      );

      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: ['wss://relay.divine.video'],
        ),
      ).called(1);
    });

    test('author supplied relay cannot remove moderation relay', () async {
      const unmonitoredRelay = 'wss://unmonitored.relay.example';
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('7'),
        authorPubkey: 'author_relay_hint',
        reason: ContentFilterReason.other,
        details: 'author relay hint routing test',
        sourceRelay: unmonitoredRelay,
      );

      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: ['wss://relay.divine.video', unmonitoredRelay],
        ),
      ).called(1);
    });

    test('falls back to configured relay for invalid source relay', () async {
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('6'),
        authorPubkey: 'author_invalid_relay',
        reason: ContentFilterReason.other,
        details: 'invalid relay routing test',
        sourceRelay: 'https://relay.staging.dvines.org',
      );

      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: ['wss://relay.divine.video'],
        ),
      ).called(1);
    });

    test('falls back to configured relay for plaintext source relay', () async {
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final _ = await service.reportContent(
        eventId: _validEventId('8'),
        authorPubkey: 'author_plaintext_relay',
        reason: ContentFilterReason.other,
        details: 'plaintext relay routing test',
        sourceRelay: 'ws://relay.staging.dvines.org',
      );

      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: ['wss://relay.divine.video'],
        ),
      ).called(1);
    });

    test('places NIP-56 report type as 3rd element of e and p tags', () async {
      List<List<String>>? capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
        final event = Event(
          testPublicKey,
          EventKind.report,
          capturedTags ?? [],
          'test',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'test_id';
        event.sig = 'test_sig';
        return event;
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(
            testPublicKey,
            EventKind.report,
            [],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      const validSpamEventId =
          '6666666666666666666666666666666666666666666666666666666666666666';
      final _ = await service.reportContent(
        eventId: validSpamEventId,
        authorPubkey: 'author_spam',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      expect(capturedTags, isNotNull);

      // Find e and p tags
      final eTag = capturedTags!.firstWhere((t) => t[0] == 'e');
      final pTag = capturedTags!.firstWhere((t) => t[0] == 'p');

      // NIP-56: report type is the 3rd element
      expect(eTag, hasLength(3));
      expect(eTag[1], equals(validSpamEventId));
      expect(eTag[2], equals('spam'));

      expect(pTag, hasLength(3));
      expect(pTag[1], equals('author_spam'));
      expect(pTag[2], equals('spam'));

      // No separate ['report', ...] tag should exist
      final reportTags = capturedTags!.where((t) => t[0] == 'report');
      expect(reportTags, isEmpty);
    });

    test('reportUser() without related events omits e tags', () async {
      const reportedPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      List<List<String>>? capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
        final event = Event(
          testPublicKey,
          EventKind.report,
          capturedTags ?? [],
          'test',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'test_id';
        event.sig = 'test_sig';
        return event;
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(
            testPublicKey,
            EventKind.report,
            [],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      final _ = await service.reportUser(
        userPubkey: reportedPubkey,
        reason: ContentFilterReason.harassment,
        details: 'Reported from DM conversation',
      );

      expect(capturedTags, isNotNull);
      expect(capturedTags!.where((t) => t[0] == 'e'), isEmpty);

      final pTag = capturedTags!.singleWhere((t) => t[0] == 'p');
      expect(pTag, ['p', reportedPubkey, 'profanity']);

      expect(service.reportHistory.single.eventId, 'user_$reportedPubkey');
    });

    test('reportUser() emits e tags only for valid related event ids', () async {
      const reportedPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const validEventId1 =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const validEventId2 =
          'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';
      const invalidSyntheticUserTarget =
          'user_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      List<List<String>>? capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
        final event = Event(
          testPublicKey,
          EventKind.report,
          capturedTags ?? [],
          'test',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'test_id';
        event.sig = 'test_sig';
        return event;
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(
            testPublicKey,
            EventKind.report,
            [],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      final _ = await service.reportUser(
        userPubkey: reportedPubkey,
        reason: ContentFilterReason.spam,
        details: 'Spam reports from this user',
        relatedEventIds: [
          invalidSyntheticUserTarget,
          validEventId1,
          'not-an-event-id',
          validEventId2,
        ],
      );

      expect(capturedTags, isNotNull);
      final eTags = capturedTags!.where((t) => t[0] == 'e').toList();
      expect(eTags, [
        ['e', validEventId1, 'spam'],
        ['e', validEventId2, 'spam'],
      ]);

      final pTag = capturedTags!.singleWhere((t) => t[0] == 'p');
      expect(pTag, ['p', reportedPubkey, 'spam']);
    });

    test(
      'reportContent() omits invalid event ids from emitted e tags',
      () async {
        List<List<String>>? capturedTags;

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[#tags] as List<List<String>>?;
          final event = Event(
            testPublicKey,
            EventKind.report,
            capturedTags ?? [],
            'test',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          event.id = 'test_id';
          event.sig = 'test_sig';
          return event;
        });

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishSuccess(
            event: Event(
              testPublicKey,
              EventKind.report,
              [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ),
        );

        final _ = await service.reportContent(
          eventId: 'user_not_a_real_event_id',
          authorPubkey:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          reason: ContentFilterReason.other,
          details: 'User-only report preserved for local history',
        );

        expect(capturedTags, isNotNull);
        // This locks in the follow-up hardening: reportContent() itself now
        // refuses to publish invalid e tags even if a caller passes one in.
        expect(capturedTags!.where((t) => t[0] == 'e'), isEmpty);

        final pTag = capturedTags!.singleWhere((t) => t[0] == 'p');
        expect(pTag, [
          'p',
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          'other',
        ]);
      },
    );

    test('maps ContentFilterReason to NIP-56 standard types', () async {
      final expectedMappings = {
        ContentFilterReason.spam: 'spam',
        ContentFilterReason.harassment: 'profanity',
        ContentFilterReason.violence: 'illegal',
        ContentFilterReason.sexualContent: 'nudity',
        ContentFilterReason.copyright: 'illegal',
        ContentFilterReason.falseInformation: 'other',
        ContentFilterReason.childSafety: 'other',
        ContentFilterReason.csam: 'illegal',
        ContentFilterReason.underageUser: 'other',
        ContentFilterReason.aiGenerated: 'other',
        ContentFilterReason.other: 'other',
      };

      for (final entry in expectedMappings.entries) {
        List<List<String>>? capturedTags;

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[#tags] as List<List<String>>?;
          final event = Event(
            testPublicKey,
            EventKind.report,
            capturedTags ?? [],
            'test',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          event.id = 'id_${entry.key.name}';
          event.sig = 'sig';
          return event;
        });

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishSuccess(
            event: Event(
              testPublicKey,
              EventKind.report,
              [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ),
        );

        final _ = await service.reportContent(
          eventId: _validEventId(entry.key.index.toRadixString(16)),
          authorPubkey: 'author_${entry.key.name}',
          reason: entry.key,
          details: 'Test ${entry.key.name}',
        );

        final eTag = capturedTags!.firstWhere((t) => t[0] == 'e');
        expect(
          eTag[2],
          equals(entry.value),
          reason:
              '${entry.key.name} should map to NIP-56 type "${entry.value}"',
        );
      }
    });
  });

  group('ContentReportingService Provider Integration', () {
    test('provider pattern calls initialize() on service creation', () async {
      // This test validates that the provider pattern we fixed actually works
      // The fix was adding: await service.initialize(); in the provider

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostrService = _MockNostrClient();
      final mockAuthService = _MockAuthService();

      // Generate valid keys
      final testPrivateKey = generatePrivateKey();
      final testPublicKey = getPublicKey(testPrivateKey);

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);

      // Simulate what the provider does
      final service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        moderationRelayUrl: 'wss://relay.divine.video',
      );
      await service.initialize(); // This is what the provider now does

      // Setup mocks for reportContent
      final reportEvent = Event(
        testPublicKey,
        1984,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      // Now reportContent should work
      final result = await service.reportContent(
        eventId: 'test',
        authorPubkey: 'test',
        reason: ContentFilterReason.other,
        details: 'test',
      );

      expect(result.success, true);
    });
  });

  group('ContentReportingService durable queue (#8053)', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late SharedPreferences prefs;
    late AppDatabase database;
    late PendingReportsDao dao;
    late String tempDbPath;
    late ContentReportingService service;
    late String testPublicKey;

    Event signedEvent(String id) {
      final event = Event(
        testPublicKey,
        1984,
        [
          ['e', _validEventId('a')],
          ['p', _validEventId('b')],
        ],
        'report content',
        createdAt: 1700000000,
      )..sig = 'sig';
      event.id = id;
      return event;
    }

    setUp(() async {
      testPublicKey = getPublicKey(generatePrivateKey());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final tempDir = Directory.systemTemp.createTempSync('crs_queue_test_');
      tempDbPath = '${tempDir.path}/test.db';
      database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
      dao = database.pendingReportsDao;

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

      service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        moderationRelayUrl: 'wss://relay.divine.video',
        pendingReportsDao: dao,
      );
      await service.initialize();
    });

    tearDown(() async {
      await database.close();
      final file = File(tempDbPath);
      if (file.existsSync()) file.deleteSync();
      final dir = Directory(tempDbPath).parent;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('enqueues a row and, on a relay success with Zendesk unavailable, '
        'keeps it with relay done and zendesk queued', () async {
      final reportEvent = signedEvent('a' * 64);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final result = await service.reportContent(
        eventId: _validEventId('a'),
        authorPubkey: _validEventId('c'),
        reason: ContentFilterReason.spam,
        details: 'spam',
      );

      // Optimistic: the report is reported reached as soon as it is durably
      // queued, before the channels are driven.
      expect(result.delivery, ReportDelivery.reached);

      // The channels are driven unawaited in the background; let that run.
      await pumpEventQueue();

      // Zendesk is not configured under test, so its leg stays queued for the
      // background sweep while the relay leg is retired.
      final row = await dao.getById(result.reportId!);
      expect(row, isNotNull);
      expect(row!.relayStatus, PendingReportChannelStatus.done);
      expect(row.zendeskStatus, PendingReportChannelStatus.pending);
      expect(row.zendeskAttempts, 1);
      expect(row.eventJson, contains('"id":"${'a' * 64}"'));
    });

    test('a relay failure leaves the relay channel queued for retry', () async {
      final reportEvent = signedEvent('d' * 64);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => const PublishNoRelays());

      final result = await service.reportContent(
        eventId: _validEventId('a'),
        authorPubkey: _validEventId('c'),
        reason: ContentFilterReason.spam,
        details: 'spam',
      );

      // The background drive runs unawaited; let it attempt and fail.
      await pumpEventQueue();

      final row = await dao.getById(result.reportId!);
      expect(row!.relayStatus, PendingReportChannelStatus.pending);
      expect(row.relayAttempts, 1);
    });

    test('deliverReportChannel republishes the stored relay event', () async {
      final reportEvent = signedEvent('e' * 64);
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final row = PendingReport(
        reportId: 'report_x',
        userPubkey: testPublicKey,
        eventJson:
            '{"id":"${'e' * 64}","pubkey":"$testPublicKey",'
            '"created_at":1700000000,"kind":1984,"tags":[],'
            '"content":"c","sig":"s"}',
        targetRelays: '["wss://relay.divine.video"]',
        zendeskPayload: '{}',
        createdAt: DateTime.utc(2026),
      );

      final ok = await service.deliverReportChannel(row, ReportChannel.relay);

      expect(ok, isTrue);
      final captured = verify(
        () => mockNostrService.publishEvent(
          captureAny(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).captured;
      expect((captured.single as Event).id, 'e' * 64);
    });

    test('a queue enqueue failure does not block the report send', () async {
      // The queue is enrichment; a DB failure must degrade to the pre-queue
      // one-shot send rather than sinking a (possibly child-safety) report.
      final throwingDao = _MockPendingReportsDao();
      when(() => throwingDao.enqueue(any())).thenThrow(
        StateError('database is locked'),
      );

      final crs = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
        moderationRelayUrl: 'wss://relay.divine.video',
        pendingReportsDao: throwingDao,
      );
      await crs.initialize();

      final reportEvent = signedEvent('f' * 64);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: reportEvent));

      final result = await crs.reportContent(
        eventId: _validEventId('a'),
        authorPubkey: _validEventId('c'),
        reason: ContentFilterReason.spam,
        details: 'spam',
      );

      // The relay leg still ran and the report is reported delivered; the
      // enqueue throw never reached the caller.
      expect(result.success, isTrue);
      expect(result.delivery, ReportDelivery.reached);
      verify(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).called(1);
      // No channel bookkeeping was attempted because the enqueue failed.
      verifyNever(
        () => throwingDao.markChannelDone(
          reportId: any(named: 'reportId'),
          channel: any(named: 'channel'),
        ),
      );
    });
  });
}
