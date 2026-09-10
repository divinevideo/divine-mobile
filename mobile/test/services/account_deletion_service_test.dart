// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, NIP-09 batch
// ABOUTME: deletion, and broadcast behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_type.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {
  /// Drives the `timedOut` field of the record synthesized below, so tests
  /// keep stubbing the simpler [queryEvents] for the event list.
  bool queryTimedOut = false;
  Duration? queryTimeout;
  bool? queryRequiresAllRelaysSettled;

  @override
  Future<
    ({
      List<Event> events,
      bool timedOut,
      bool noRelays,
      bool anyRelayAnswered,
      List<String> unsettledRelays,
    })
  >
  queryEventsDetailed(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    queryTimeout = timeout;
    queryRequiresAllRelaysSettled = requireAllRelaysSettled;
    final events = await queryEvents(filters);
    return (
      events: events,
      timedOut: queryTimedOut,
      noRelays: connectedRelays.isEmpty,
      anyRelayAnswered: false,
      unsettledRelays: const <String>[],
    );
  }
}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

/// A relay returned `OK true`.
const _confirmed = PublishOutcome(
  eventId: 'confirmed',
  acceptedBy: ['wss://relay.example.com'],
  rejectedBy: <String, String>{},
  noResponseFrom: <String>[],
);

/// Every targeted relay returned `OK false`.
const _rejected = PublishOutcome(
  eventId: 'rejected',
  acceptedBy: <String>[],
  rejectedBy: {'wss://relay.example.com': 'blocked: test'},
  noResponseFrom: <String>[],
);

/// The relay received the event and never answered before the timeout.
///
/// A targeted relay always lands in one of the outcome's buckets, so leaving
/// all of them empty would describe a publish with no targets at all.
const _noRelayResponse = PublishOutcome(
  eventId: 'unreachable',
  acceptedBy: <String>[],
  rejectedBy: <String, String>{},
  noResponseFrom: <String>['wss://relay.example.com'],
);

const _alreadyVanished = PublishOutcome(
  eventId: 'already-vanished',
  acceptedBy: <String>[],
  rejectedBy: {'wss://relay.example.com': 'blocked: pubkey already vanished'},
  noResponseFrom: <String>[],
);

const _accountRestricted = PublishOutcome(
  eventId: 'restricted',
  acceptedBy: <String>[],
  rejectedBy: {'wss://relay.example.com': 'blocked: pubkey is suspended'},
  noResponseFrom: <String>[],
);

const _rateLimited = PublishOutcome(
  eventId: 'rate-limited',
  acceptedBy: <String>[],
  rejectedBy: {
    'wss://relay.example.com': 'rate-limited: too many events, slow down',
  },
  noResponseFrom: <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });

  group('AccountDeletionService', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late AccountDeletionService service;
    late String testPrivateKey;
    late String testPublicKey;

    Event createTestEvent({
      required String pubkey,
      required int kind,
      required List<List<String>> tags,
      required String content,
      String? id,
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = id ?? 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    setUp(() {
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        retryDelay: (_) async {},
      );

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => []);
      when(() => mockNostrService.isDisposed).thenReturn(false);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      when(
        () => mockNostrService.defaultRelayUrl,
      ).thenReturn('wss://relay.example.com');
      when(() => mockNostrService.isRelayAllowed(any())).thenReturn(true);
      when(
        () => mockNostrService.publishEventAwaitOk(any()),
      ).thenAnswer((_) async => _confirmed);
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => _confirmed);
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => _confirmed);
    });

    test('createNip62Event should create kind 62 event', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);

      // Verify createAndSignEvent was called with kind 62
      verify(
        () => mockAuthService.createAndSignEvent(
          kind: 62,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);
    });

    test('createNip62Event should include ALL_RELAYS tag', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      await service.createNip62Event(reason: 'User requested account deletion');

      // Assert - verify tags include ALL_RELAYS
      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured.first as List<List<String>>;
      expect(
        tags.any(
          (tag) =>
              tag.length == 2 && tag[0] == 'relay' && tag[1] == 'ALL_RELAYS',
        ),
        isTrue,
      );
    });

    test('deleteAccount should broadcast NIP-62 event', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      await expectLater(service.deleteAccount(), completes);

      // Assert
      verify(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: const Duration(seconds: 30),
        ),
      ).called(1);
    });

    test(
      'deleteAccount should return success when broadcast succeeds',
      () async {
        // Arrange
        final expectedEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.failureReason, isNull);
      },
    );

    test('deleteAccount should return failure when publish fails', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // publishEventAwaitOk reports every relay rejecting
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => _rejected);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(
        result.failureReason,
        DeleteAccountFailureReason.vanishNotConfirmed,
      );
      expect(result.diagnosticError, contains('rejected'));
    });

    test('deleteAccount does not retry an account restriction', () async {
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => _accountRestricted);

      final result = await service.deleteAccount();

      expect(result.success, isFalse);
      expect(
        result.failureReason,
        DeleteAccountFailureReason.accountRestricted,
      );
      verify(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
    });

    test(
      'deleteAccount returns generic publish-failure message when no relay responds',
      () async {
        // Arrange
        final expectedEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => _noRelayResponse);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isFalse);
        expect(
          result.failureReason,
          DeleteAccountFailureReason.vanishNotConfirmed,
        );
        expect(result.diagnosticError, contains('no relay responded'));
      },
    );

    test('deleteAccount retries vanish publish and succeeds later', () async {
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      var publishCalls = 0;
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async {
        publishCalls++;
        return publishCalls == 3 ? _confirmed : _noRelayResponse;
      });

      final result = await service.deleteAccount();

      expect(result.success, isTrue);
      expect(publishCalls, equals(3));
      verify(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: const Duration(seconds: 30),
        ),
      ).called(3);
    });

    test(
      'deleteAccount treats already-vanished relay rejection as success',
      () async {
        final expectedEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => _alreadyVanished);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.deleteEventId, expectedEvent.id);
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      },
    );

    test('deleteAccount should fail when not authenticated', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.failureReason, DeleteAccountFailureReason.notAuthenticated);

      // Verify publishEvent was NOT called
      verifyNever(() => mockNostrService.publishEventAwaitOk(any()));
    });

    test(
      'deleteAccount should fail when createAndSignEvent returns null',
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
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isFalse);
        expect(result.failureReason, DeleteAccountFailureReason.signingFailed);

        // Verify publishEvent was NOT called
        verifyNever(() => mockNostrService.publishEventAwaitOk(any()));
      },
    );

    test(
      'publishes nothing when kind 62 signing fails after preparing a sweep',
      () async {
        final contentEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
        );
        final kind5Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', contentEvent.id],
            ['k', '1'],
          ],
          content: 'deletion',
        );
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [contentEvent]);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          return kind == 5 ? kind5Event : null;
        });

        final result = await service.deleteAccount();

        expect(result.success, isFalse);
        expect(result.failureReason, DeleteAccountFailureReason.signingFailed);
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test('publishes nothing when any sweep batch cannot be signed', () async {
      final contentEvents = [
        createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
        ),
        createTestEvent(
          pubkey: testPublicKey,
          kind: 6,
          tags: const [],
          content: 'repost',
        ),
      ];
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => contentEvents);
      var kind5Signatures = 0;
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async {
        kind5Signatures++;
        if (kind5Signatures == 2) return null;
        return createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: const [],
          content: 'deletion',
        );
      });

      final result = await service.deleteAccount();

      expect(result.success, isFalse);
      expect(result.failureReason, DeleteAccountFailureReason.signingFailed);
      verifyNever(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      );
      verifyNever(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test(
      'signs every sweep batch before vanish and publishes vanish last',
      () async {
        final contentEvents = [
          createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: const [],
            content: 'note',
          ),
          createTestEvent(
            pubkey: testPublicKey,
            kind: 6,
            tags: const [],
            content: 'repost',
          ),
        ];
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => contentEvents);
        // One interleaved timeline, not two per-phase lists: separate
        // sign-order and publish-order lists are each satisfied by the
        // sign/publish/sign/publish interleaving this change exists to
        // remove, so only a merged timeline can fail on it.
        final timeline = <String>[];
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          timeline.add('sign:$kind');
          return createTestEvent(
            pubkey: testPublicKey,
            kind: kind,
            tags: const [],
            content: 'deletion',
          );
        });
        void recordPublish(Invocation invocation) {
          final event = invocation.positionalArguments.single as Event;
          timeline.add('publish:${event.kind}');
        }

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          recordPublish(invocation);
          return _confirmed;
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          recordPublish(invocation);
          return _confirmed;
        });

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(timeline, [
          'sign:5',
          'sign:5',
          'sign:62',
          'publish:5',
          'publish:5',
          'publish:62',
        ]);
      },
    );

    group('NIP-09 batch deletion', () {
      test('should fetch all user events before deletion', () async {
        // Arrange
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        await service.deleteAccount();

        // Assert
        verify(() => mockNostrService.queryEvents(any())).called(1);
      });

      test(
        'should publish kind 5 events for user events before NIP-62',
        () async {
          // Arrange
          final userVideoEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 34236,
            tags: [],
            content: 'test video',
            id: 'video_event_1',
          );

          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'video_event_1'],
              ['k', '34236'],
            ],
            content: 'User requested account deletion via Divine app',
          );

          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'User requested account deletion via Divine app',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userVideoEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          // Act
          final result = await service.deleteAccount();

          // Assert
          expect(result.success, isTrue);
          verify(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: ['wss://relay.example.com'],
            ),
          ).called(1);
          verify(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: const Duration(seconds: 30),
            ),
          ).called(1);
        },
      );

      test('does not publish kind 5 to the Divine relay', () async {
        const divineRelay = 'wss://relay.divine.video';
        const fallbackRelay = 'wss://relay.example.com';
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn([divineRelay, fallbackRelay]);
        final userEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
          id: 'note_for_external_sweep',
        );
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [userEvent]);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[const Symbol('kind')] as int;
          return createTestEvent(
            pubkey: testPublicKey,
            kind: kind,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: [fallbackRelay],
          ),
        ).called(1);
      });

      test('does not publish kind 5 to any Divine-hosted relay', () async {
        const stagingRelay = 'wss://relay.staging.divine.video';
        const pocRelay = 'wss://relay.poc.dvines.org';
        const localRelay = 'ws://localhost:47777';
        const fallbackRelay = 'wss://relay.example.com';
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn([stagingRelay, pocRelay, localRelay, fallbackRelay]);
        final userEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
          id: 'note_for_multi_env_sweep',
        );
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [userEvent]);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[const Symbol('kind')] as int;
          return createTestEvent(
            pubkey: testPublicKey,
            kind: kind,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: [fallbackRelay],
          ),
        ).called(1);
      });

      test(
        'does not publish kind 5 when environment lock rejects every target',
        () async {
          const stagingRelay = 'wss://relay.staging.divine.video';
          const externalRelay = 'wss://relay.example.com';
          when(
            () => mockNostrService.connectedRelays,
          ).thenReturn([stagingRelay, externalRelay]);
          when(
            () => mockNostrService.isRelayAllowed(stagingRelay),
          ).thenReturn(true);
          when(
            () => mockNostrService.isRelayAllowed(externalRelay),
          ).thenReturn(false);
          when(() => mockNostrService.queryEvents(any())).thenAnswer(
            (_) async => [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
              ),
            ],
          );
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 62,
              tags: const [
                ['relay', 'ALL_RELAYS'],
              ],
              content: 'deletion',
            ),
          );

          final result = await service.deleteAccount();

          expect(result.success, isTrue);
          expect(result.deletedEventsCount, isZero);
          expect(result.contentDeletionIncomplete, isFalse);
          verifyNever(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          );
        },
      );

      test(
        'targets non-Divine relays when the Divine relay is disconnected',
        () async {
          const fallbackRelay = 'wss://relay.example.com';
          when(
            () => mockNostrService.connectedRelays,
          ).thenReturn([fallbackRelay]);
          when(() => mockNostrService.queryEvents(any())).thenAnswer(
            (_) async => [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
              ),
            ],
          );
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            final kind = invocation.namedArguments[const Symbol('kind')] as int;
            return createTestEvent(
              pubkey: testPublicKey,
              kind: kind,
              tags: const [],
              content: 'deletion',
            );
          });
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => _confirmed);

          final result = await service.deleteAccount();

          expect(result.success, isTrue);
          verify(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: [fallbackRelay],
            ),
          ).called(1);
        },
      );

      test('does not publish kind 5 when no relay is connected', () async {
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(const <String>[]);
        when(() => mockNostrService.queryEvents(any())).thenAnswer(
          (_) async => [
            createTestEvent(
              pubkey: testPublicKey,
              kind: 1,
              tags: const [],
              content: 'cached note',
            ),
          ],
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isTrue);
        expect(result.contentDeletionIncomplete, isTrue);
        verifyNever(() => mockNostrService.publishEventAwaitOk(any()));
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('skips kind 5 when only the Divine relay is connected', () async {
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(['wss://relay.divine.video']);
        when(() => mockNostrService.queryEvents(any())).thenAnswer(
          (_) async => [
            createTestEvent(
              pubkey: testPublicKey,
              kind: 1,
              tags: const [],
              content: 'note',
            ),
          ],
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.deletedEventsCount, 0);
        expect(result.contentDeletionIncomplete, isFalse);
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('should group events by kind for batch deletion', () async {
        // Arrange
        final videoEvent1 = createTestEvent(
          pubkey: testPublicKey,
          kind: 34236,
          tags: [],
          content: 'video 1',
          id: 'video_1',
        );
        final videoEvent2 = createTestEvent(
          pubkey: testPublicKey,
          kind: 34236,
          tags: [],
          content: 'video 2',
          id: 'video_2',
        );
        final likeEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 7,
          tags: [],
          content: '+',
          id: 'like_1',
        );

        final kind5VideoEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'video_1'],
            ['e', 'video_2'],
            ['k', '34236'],
          ],
          content: 'deletion',
        );
        final kind5LikeEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'like_1'],
            ['k', '7'],
          ],
          content: 'deletion',
        );
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [videoEvent1, videoEvent2, likeEvent]);

        var createCallCount = 0;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5VideoEvent;
          if (createCallCount == 2) return kind5LikeEvent;
          return nip62Event;
        });

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(3));
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: ['wss://relay.example.com'],
          ),
        ).called(2);
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: const Duration(seconds: 30),
          ),
        ).called(1);
      });

      test('should return deletedEventsCount in result', () async {
        // Arrange
        final userEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: [],
          content: 'note',
          id: 'note_1',
        );

        final kind5Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'note_1'],
            ['k', '1'],
          ],
          content: 'deletion',
        );
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [userEvent]);

        var createCallCount = 0;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5Event;
          return nip62Event;
        });

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(1));
      });

      test('should still publish NIP-62 even if no events found', () async {
        // Arrange
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(0));
        verify(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: const Duration(seconds: 30),
          ),
        ).called(1);
      });

      test(
        'batch deletion does not count events when no relay responds',
        () async {
          // Arrange
          final userEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: [],
            content: 'note',
            id: 'note_1',
          );
          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'note_1'],
              ['k', '1'],
            ],
            content: 'deletion',
          );
          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => _noRelayResponse);

          // Act
          final result = await service.deleteAccount();

          // Assert — NIP-62 still succeeds; batch counted 0 because relay
          // was unreachable for kind-5.
          expect(result.success, isTrue);
          expect(result.deletedEventsCount, equals(0));
          expect(result.contentDeletionIncomplete, isTrue);
        },
      );

      test(
        'batch deletion retries once after a rate-limit rejection',
        () async {
          final delays = <Duration>[];
          final retryingService = AccountDeletionService(
            nostrService: mockNostrService,
            authService: mockAuthService,
            retryDelay: (delay) async => delays.add(delay),
          );
          final userEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: [],
            content: 'note',
            id: 'rate_limited_note',
          );
          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', userEvent.id],
              ['k', '1'],
            ],
            content: 'deletion',
          );
          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          );
          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userEvent]);
          var createCalls = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createCalls++ == 0 ? kind5Event : nip62Event,
          );
          var batchPublishes = 0;
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async {
            batchPublishes++;
            return batchPublishes == 1 ? _rateLimited : _confirmed;
          });

          final result = await retryingService.deleteAccount();

          expect(result.success, isTrue);
          expect(result.deletedEventsCount, 1);
          expect(batchPublishes, 2);
          expect(delays, contains(const Duration(minutes: 1)));
        },
      );

      test(
        'restricted batch stops the sweep before publishing another kind',
        () async {
          final delays = <Duration>[];
          final restrictedService = AccountDeletionService(
            nostrService: mockNostrService,
            authService: mockAuthService,
            retryDelay: (delay) async => delays.add(delay),
          );
          when(() => mockNostrService.queryEvents(any())).thenAnswer(
            (_) async => [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
                id: 'restricted_note',
              ),
              createTestEvent(
                pubkey: testPublicKey,
                kind: 7,
                tags: const [],
                content: 'reaction',
                id: 'unattempted_reaction',
              ),
            ],
          );
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 5,
              tags: const [],
              content: 'deletion',
            ),
          );
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => _accountRestricted);
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => _accountRestricted);

          final result = await restrictedService.deleteAccount();

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            DeleteAccountFailureReason.accountRestricted,
          );
          verify(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
          expect(delays, isEmpty);
        },
      );

      test('reports partial deletion when the account changes during the '
          'inter-batch delay after a batch was confirmed', () async {
        var current = testPublicKey;
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenAnswer((_) => current);

        final delays = <Duration>[];
        final pacingService = AccountDeletionService(
          nostrService: mockNostrService,
          authService: mockAuthService,
          retryDelay: (delay) async {
            delays.add(delay);
            // Swap the signed-in account while the sweep waits between
            // batches, after batch 0 has already been confirmed on relays.
            current = 'a_different_pubkey_than_confirmed';
          },
        );

        when(() => mockNostrService.queryEvents(any())).thenAnswer(
          (_) async => [
            createTestEvent(
              pubkey: testPublicKey,
              kind: 1,
              tags: const [],
              content: 'note',
              id: 'kind1_note',
            ),
            createTestEvent(
              pubkey: testPublicKey,
              kind: 7,
              tags: const [],
              content: 'reaction',
              id: 'kind7_reaction',
            ),
          ],
        );
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _confirmed);

        final result = await pacingService.deleteAccount(
          expectedPubkey: testPublicKey,
        );

        // Two kind-5 deletion requests were already confirmed on relays
        // before the swap, so the user must be told deletion began, not
        // that nothing happened.
        expect(result.success, isFalse);
        expect(
          result.failureReason,
          DeleteAccountFailureReason.accountChangedAfterDeletion,
        );
        expect(delays, contains(const Duration(milliseconds: 500)));
      });

      test(
        'batch deletion does not count events when every relay rejects',
        () async {
          // Arrange
          final userEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: [],
            content: 'note',
            id: 'note_2',
          );
          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'note_2'],
              ['k', '1'],
            ],
            content: 'deletion',
          );
          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => _rejected);

          // Act
          final result = await service.deleteAccount();

          // Assert — NIP-62 still succeeds; batch counted 0 because send
          // failed.
          expect(result.success, isTrue);
          expect(result.deletedEventsCount, equals(0));
        },
      );
    });

    group('sweep target selection', () {
      // Regression for #6335: the sweep had no kind filter, so on every retry
      // it asked relays to delete its own prior kind-5 requests and the
      // kind-62 vanish request itself, growing the e-tag list each time. Both
      // are protocol no-ops (NIP-09: "Publishing a deletion request event
      // against a deletion request has no effect"; NIP-62 says the same for a
      // request to vanish), so this only ever wasted remote-signing
      // round-trips and asked the network to retract a legal notice.
      test("excludes the flow's own kind-5 and kind-62 events", () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        final note = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
          id: 'note_1',
        );
        final priorDeletion = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: const [
            ['e', 'note_1'],
          ],
          content: 'prior sweep',
          id: 'kind5_1',
        );
        final priorVanish = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: const [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'prior vanish',
          id: 'kind62_1',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [note, priorDeletion, priorVanish]);

        final signedKinds = <int>[];
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>;
          for (final tag in tags) {
            if (tag.length >= 2 && tag[0] == 'k') {
              signedKinds.add(int.parse(tag[1]));
            }
          }
          return createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        await service.deleteAccount();

        // The kind-1 note is swept; the flow's own kind-5 and kind-62 are not.
        expect(signedKinds, contains(1));
        expect(signedKinds, isNot(contains(5)));
        expect(signedKinds, isNot(contains(62)));
      });

      // Regression for #6335: the sweep emitted `e` tags only. NIP-09 says
      // "When an `a` tag is used, relays SHOULD delete all versions of the
      // replaceable event up to the `created_at`", so with `e` alone every
      // prior version of an edited video survives on a relay that implements
      // NIP-09 but not NIP-62 — exactly the relays this sweep exists for.
      test(
        'emits an a tag for addressable kinds alongside the e tag',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(testPublicKey);

          final video = createTestEvent(
            pubkey: testPublicKey,
            kind: 34236,
            tags: const [
              ['d', 'my-vine-id'],
            ],
            content: 'video',
            id: 'video_1',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [video]);

          List<List<String>>? kind5Tags;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            final tags =
                invocation.namedArguments[const Symbol('tags')]
                    as List<List<String>>;
            if (tags.any((tag) => tag.isNotEmpty && tag[0] == 'e')) {
              kind5Tags = tags;
            }
            return createTestEvent(
              pubkey: testPublicKey,
              kind: 5,
              tags: const [],
              content: 'deletion',
            );
          });
          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          await service.deleteAccount();

          expect(kind5Tags, isNotNull);
          // `contains` compares with `==`, and Dart lists use identity
          // equality, so each expected tag must be wrapped in `equals`.
          expect(kind5Tags, contains(equals(['e', 'video_1'])));
          expect(
            kind5Tags,
            contains(equals(['a', '34236:$testPublicKey:my-vine-id'])),
          );
        },
      );

      test('omits the a tag for non-addressable kinds', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        final note = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [
            ['d', 'not-addressable'],
          ],
          content: 'note',
          id: 'note_1',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [note]);

        List<List<String>>? kind5Tags;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>;
          if (tags.any((tag) => tag.isNotEmpty && tag[0] == 'e')) {
            kind5Tags = tags;
          }
          return createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        await service.deleteAccount();

        expect(kind5Tags, isNotNull);
        expect(kind5Tags!.any((tag) => tag[0] == 'a'), isFalse);
      });

      // Regression for #6335: a failed relay query was swallowed into an empty
      // list, so the entire kind-5 sweep was skipped while the irreversible
      // vanish was still published — and the caller reported plain success.
      test('reports contentQueryFailed when the relay query throws', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenThrow(Exception('relay unreachable'));
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isTrue);
        expect(result.deletedEventsCount, equals(0));
      });

      test('contentQueryFailed is false on a healthy query', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isFalse);
        expect(mockNostrService.queryTimeout, const Duration(seconds: 30));
        expect(mockNostrService.queryRequiresAllRelaysSettled, isTrue);
      });

      test(
        'reports incomplete deletion when the query reaches its cap',
        () async {
          final priorDeletion = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'prior deletion',
          );
          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => List<Event>.filled(10000, priorDeletion));
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 62,
              tags: const [
                ['relay', 'ALL_RELAYS'],
              ],
              content: 'deletion',
            ),
          );

          final result = await service.deleteAccount();

          expect(result.success, isTrue);
          expect(result.contentQueryFailed, isFalse);
          expect(result.contentDeletionIncomplete, isTrue);
        },
      );

      test('reports contentQueryFailed when no relay is connected', () async {
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(const <String>[]);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isTrue);
        expect(result.deletedEventsCount, equals(0));
      });

      test(
        'reports contentQueryFailed when the relay query times out',
        () async {
          mockNostrService.queryTimedOut = true;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 62,
              tags: const [
                ['relay', 'ALL_RELAYS'],
              ],
              content: 'deletion',
            ),
          );
          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          final result = await service.deleteAccount();

          expect(result.success, isTrue);
          expect(result.contentQueryFailed, isTrue);
          expect(result.deletedEventsCount, equals(0));
        },
      );
    });

    group('expectedPubkey binding', () {
      test(
        'reports partial deletion when account changes during confirmed kind 5',
        () async {
          var current = testPublicKey;
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenAnswer((_) => current);
          when(() => mockNostrService.queryEvents(any())).thenAnswer(
            (_) async => [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
              ),
            ],
          );
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 5,
              tags: const [],
              content: 'deletion',
            ),
          );
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async {
            current = 'a_different_pubkey_than_confirmed';
            return _confirmed;
          });

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            DeleteAccountFailureReason.accountChangedAfterDeletion,
          );
          verify(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
          verifyNever(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
        },
      );

      test(
        'aborts when the account changes while awaiting vanish confirmation',
        () async {
          var current = testPublicKey;
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenAnswer((_) => current);
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 62,
              tags: const [
                ['relay', 'ALL_RELAYS'],
              ],
              content: 'deletion',
            ),
          );
          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async {
            current = 'a_different_pubkey_than_confirmed';
            return _confirmed;
          });

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            DeleteAccountFailureReason.accountChangedAfterDeletion,
          );
        },
      );

      test(
        'aborts before signing when the account changes mid-deletion',
        () async {
          var current = testPublicKey;
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenAnswer((_) => current);
          when(() => mockNostrService.queryEvents(any())).thenAnswer((_) async {
            // Account switches away during the event fetch, before any signing.
            current = 'a_different_pubkey_than_confirmed';
            return [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
              ),
            ];
          });

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            DeleteAccountFailureReason.accountChanged,
          );
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test(
        'aborts at entry when expectedPubkey already differs from the signer',
        () async {
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('a_different_pubkey_than_confirmed');

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            DeleteAccountFailureReason.accountChanged,
          );
          // Bailed before fetching or signing anything.
          verifyNever(() => mockNostrService.queryEvents(any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test(
        'reaches signing when expectedPubkey stays the current account',
        () async {
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(testPublicKey);
          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);

          await service.deleteAccount(expectedPubkey: testPublicKey);

          // Guard passed with a matching account → reached the kind-62 signing.
          verify(
            () => mockAuthService.createAndSignEvent(
              kind: 62,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
        },
      );
    });
  });
}
