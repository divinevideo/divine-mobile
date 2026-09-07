// ABOUTME: Unit tests for CuratedListService CRUD operations (create, update, delete lists)
// ABOUTME: Tests core list management functionality with mocked dependencies

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

String _seal(String plaintext) => sealForTest(plaintext);

String? _unseal(String ciphertext) => unsealForTest(ciphertext);

const _ownerPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _otherPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

/// A kind 30005 curated-list event as a relay would replay it.
Event _listEvent(String listId, String title, [String pubkey = _ownerPubkey]) =>
    Event.fromJson({
      'id': 'relay_event_for_$listId',
      'pubkey': pubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'kind': 30005,
      'tags': [
        ['d', listId],
        ['title', title],
      ],
      'content': '',
      'sig': 'test_signature',
    });

/// An outcome one relay accepted — what [PublishOutcome.acceptedByAny] gates on.
PublishOutcome _accepted(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const ['wss://relay.test'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

/// An outcome no relay accepted, so the caller may roll local state back.
PublishOutcome _rejected(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const [],
  rejectedBy: const {'wss://relay.test': 'blocked'},
  noResponseFrom: const [],
);

PublishOutcome _partiallyAccepted(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const ['wss://accepted.test'],
  rejectedBy: const {'wss://rejected.test': 'blocked'},
  noResponseFrom: const [],
);

void main() {
  group('CuratedListService - CRUD Operations', () {
    late CuratedListService service;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late _MockNostrSigner mockSigner;
    late SharedPreferences prefs;

    setUpAll(() {
      registerFallbackValue(
        Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          1,
          <List<String>>[],
          '',
        ),
      );
      registerFallbackValue(<Filter>[]);
    });

    setUp(() async {
      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      mockSigner = _MockNostrSigner();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Setup common mocks
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownerPubkey);
      when(() => mockNostr.signer).thenReturn(mockSigner);
      when(mockSigner.getPublicKey).thenAnswer((_) async => _ownerPubkey);
      when(
        () => mockSigner.nip44Encrypt(any(), any()),
      ).thenAnswer((i) async => _seal(i.positionalArguments[1] as String));
      when(
        () => mockSigner.nip44Decrypt(any(), any()),
      ).thenAnswer((i) async => _unseal(i.positionalArguments[1] as String));

      // Mock successful event publishing. Both paths are stubbed: the service
      // confirms relay acceptance where a failure rolls local state back, and
      // fires and forgets where it does not.
      when(() => mockNostr.publishEvent(any())).thenAnswer((invocation) {
        return Future<PublishResult>.value(
          PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );
      });
      when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((invocation) {
        return Future<PublishOutcome>.value(
          _accepted(invocation.positionalArguments[0] as Event),
        );
      });

      // Mock subscribeToEvents for relay sync
      when(
        () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());

      // Mock event creation
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;

        return Future.value(
          Event.fromJson({
            'id': sha256
                .convert(
                  utf8.encode(
                    json.encode([0, _ownerPubkey, now, kind, tags, content]),
                  ),
                )
                .toString(),
            'pubkey': _ownerPubkey,
            'created_at': now,
            'kind': kind,
            'tags': tags,
            'content': content,
            'sig': 'test_signature',
          }),
        );
      });

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('initialize()', () {
      test('creates default list when none exists', () async {
        // Start with no lists
        expect(service.hasDefaultList(), isFalse);

        await service.initialize();

        // Should create default list
        expect(service.hasDefaultList(), isTrue);
        expect(service.isInitialized, isTrue);

        final defaultList = service.getDefaultList();
        expect(defaultList, isNotNull);
        expect(defaultList!.id, CuratedListService.defaultListId);
        expect(defaultList.name, 'My List');
      });

      test('creates default list with correct ID', () async {
        // Start with no lists
        expect(service.hasDefaultList(), isFalse);

        await service.initialize();

        // Should create default list
        expect(service.hasDefaultList(), isTrue);
        expect(
          service.lists.where((l) => l.id == CuratedListService.defaultListId),
          hasLength(1),
        );
      });

      test('does not create duplicate default list after relaunch', () async {
        // Collect lists saved to the relay
        final lists = <CuratedList>[];

        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final event = Event.fromJson({
            'id': sha256
                .convert(
                  utf8.encode(
                    json.encode([
                      0,
                      _ownerPubkey,
                      now,
                      30005,
                      invocation.namedArguments[#tags] as List<List<String>>,
                      invocation.namedArguments[#content] as String,
                    ]),
                  ),
                )
                .toString(),
            'pubkey': _ownerPubkey,
            'created_at': now,
            'kind': 30005,
            'tags': invocation.namedArguments[#tags] as List<List<String>>,
            'content': invocation.namedArguments[#content] as String,
            'sig': 'test_signature',
          });

          return Future.value(event);
        });

        when(() => mockNostr.publishEvent(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments[0] as Event;
          final list = CuratedListConverter.fromEvent(event);
          if (list != null) {
            lists.add(list);
          }
          return Future.value(PublishSuccess(event: event));
        });

        // Mock subscription to return collected lists
        when(() => mockNostr.subscribe(any())).thenAnswer((invocation) {
          final filters = invocation.positionalArguments[0] as List<Filter>;

          if (filters.isNotEmpty) {
            final filter = filters.first;

            if (filter.kinds?.contains(30005) ?? false) {
              if (filter.authors?.contains(_ownerPubkey) ?? false) {
                return Stream.fromIterable(
                  lists.map((l) {
                    final tags = CuratedListConverter.toEventTags(l);
                    final description =
                        l.description ?? 'Curated video list: ${l.name}';

                    return Event.fromJson({
                      'id': sha256
                          .convert(
                            utf8.encode(
                              json.encode([
                                0,
                                _ownerPubkey,
                                DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                30005,
                                tags,
                                description,
                              ]),
                            ),
                          )
                          .toString(),
                      'pubkey': _ownerPubkey,
                      'created_at':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      'kind': 30005,
                      'tags': tags,
                      'content': description,
                      'sig': 'test_signature',
                    });
                  }),
                );
              }
            }
          }

          return const Stream.empty();
        });

        expect(service.hasDefaultList(), isFalse);

        await service.initialize();

        expect(service.hasDefaultList(), isTrue);
        expect(service.lists.length, 1);

        // Trigger the constructor again
        service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // Initialize again
        await service.initialize();

        // Verify that there is still only the default list
        expect(service.hasDefaultList(), isTrue);
        expect(service.lists.length, 1);
      });

      test('does not recreate default list after explicit deletion', () async {
        await service.initialize();
        final defaultList = service.getDefaultList();
        expect(defaultList, isNotNull);
        clearInteractions(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        final deleted = await service.deleteOwnedList(defaultList!.id);
        expect(deleted, isTrue);
        expect(service.hasDefaultList(), isFalse);

        service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        await service.initialize();

        expect(service.hasDefaultList(), isFalse);
      });

      test('does not create duplicate default list', () async {
        // Initialize once
        await service.initialize();
        final firstDefaultList = service.getDefaultList();

        // Initialize again
        await service.initialize();
        final secondDefaultList = service.getDefaultList();

        // Should be the same list
        expect(secondDefaultList!.id, firstDefaultList!.id);
        expect(service.lists.length, 1);
      });

      test('does nothing when user not authenticated', () async {
        when(() => mockAuth.isAuthenticated).thenReturn(false);

        await service.initialize();

        expect(service.isInitialized, isFalse);
        expect(service.hasDefaultList(), isFalse);
      });

      test('calls fetchUserListsFromRelays during initialization', () async {
        // Mock subscription for relay sync
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_list_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_list_1'],
                ['title', 'Relay List'],
              ],
              'content': 'List from relay',
              'sig': 'test_signature',
            }),
          ),
        );

        await service.initialize();

        // Should have called subscribeToEvents
        verify(() => mockNostr.subscribe(any())).called(1);
      });

      test('re-queries relays only when the fetch is forced', () async {
        when(
          () => mockNostr.subscribe(any()),
        ).thenAnswer((_) => const Stream.empty());
        await service.fetchUserListsFromRelays();
        clearInteractions(mockNostr);

        // The session sync already ran, so an unforced call is a no-op and a
        // list created on another device would stay invisible until restart.
        await service.fetchUserListsFromRelays();
        verifyNever(() => mockNostr.subscribe(any()));

        await service.fetchUserListsFromRelays(force: true);
        verify(() => mockNostr.subscribe(any())).called(1);
      });

      test('relay-synced own lists stay in myLists', () async {
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_list_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_list_1'],
                ['title', 'Relay List'],
              ],
              'content': 'List from relay',
              'sig': 'test_signature',
            }),
          ),
        );

        await service.fetchUserListsFromRelays();

        final relayList = service.getListById('relay_list_1');
        expect(relayList, isNotNull);
        expect(relayList!.pubkey, _ownerPubkey);
        expect(service.myLists.map((list) => list.id), contains(relayList.id));
      });

      test('backs up a list that never reached a relay', () async {
        // What an install upgrading into this change looks like: lists in
        // SharedPreferences, no event id, nothing on any relay.
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            CuratedList(
              id: 'stranded-private',
              name: 'Stranded',
              videoEventIds: const ['stranded_video'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              isPublic: false,
              pubkey: _ownerPubkey,
            ).toJson(),
          ]),
        });
        final upgraded = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: await SharedPreferences.getInstance(),
        );

        await upgraded.fetchUserListsFromRelays();

        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.tags, contains(equals(['d', 'stranded-private'])));
        expect(jsonDecode(_unseal(published.content)!), [
          ['e', 'stranded_video'],
        ]);
        expect(
          upgraded.getListById('stranded-private')!.nostrEventId,
          isNotNull,
        );
      });

      test('does not backfill after a relay sync timeout', () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            CuratedList(
              id: 'timeout-private',
              name: 'Timeout Private',
              videoEventIds: const ['local_video'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              isPublic: false,
              pubkey: _ownerPubkey,
            ).toJson(),
          ]),
        });
        final neverCompletes = StreamController<Event>();
        var subscriptionCount = 0;
        when(() => mockNostr.subscribe(any())).thenAnswer((_) {
          subscriptionCount++;
          return subscriptionCount == 1
              ? neverCompletes.stream
              : const Stream<Event>.empty();
        });
        final upgraded = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: await SharedPreferences.getInstance(),
          relaySyncTimeout: const Duration(milliseconds: 10),
        );

        await upgraded.fetchUserListsFromRelays();

        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
        expect(upgraded.getListById('timeout-private')!.nostrEventId, isNull);

        await upgraded.fetchUserListsFromRelays();
        verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
        expect(
          upgraded.getListById('timeout-private')!.nostrEventId,
          isNotNull,
        );
        await neverCompletes.close();
      });

      test('merges divergent unpublished and relay item sets', () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            CuratedList(
              id: CuratedListService.defaultListId,
              name: 'My List',
              videoEventIds: const ['local_video'],
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025),
              isPublic: false,
              pubkey: _ownerPubkey,
            ).toJson(),
          ]),
        });
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'other_device_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', CuratedListService.defaultListId],
                ['title', 'My List'],
              ],
              'content': _seal(
                jsonEncode([
                  ['e', 'relay_video'],
                ]),
              ),
              'sig': 'test_signature',
            }),
          ),
        );
        final upgraded = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: await SharedPreferences.getInstance(),
        );

        await upgraded.fetchUserListsFromRelays();

        final merged = upgraded.getDefaultList()!;
        expect(
          merged.videoEventIds,
          containsAll(['local_video', 'relay_video']),
        );
        expect(merged.isPublic, isFalse);
        expect(merged.nostrEventId, isNotNull);
        final republished =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(
          jsonDecode(_unseal(republished.content)!),
          containsAll([
            ['e', 'local_video'],
            ['e', 'relay_video'],
          ]),
        );
      });

      test(
        'does not restore deleted default list from a stale relay event',
        () async {
          await service.initialize();
          final defaultList = service.getDefaultList();
          expect(defaultList, isNotNull);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _accepted(invocation.positionalArguments[0] as Event),
          );

          final deleted = await service.deleteOwnedList(defaultList!.id);
          expect(deleted, isTrue);
          clearInteractions(mockNostr);

          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) => Stream.value(
              Event.fromJson({
                'id': 'stale_default_event',
                'pubkey': _ownerPubkey,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                'kind': 30005,
                'tags': [
                  ['d', CuratedListService.defaultListId],
                  ['title', 'My List'],
                  ['e', 'stale_default_video'],
                ],
                'content': 'My favorite vines and videos',
                'sig': 'test_signature',
              }),
            ),
          );

          await service.fetchUserListsFromRelays(force: true);

          expect(service.hasDefaultList(), isFalse);
        },
      );

      test(
        'does not union a failed local deletion with stale relay items',
        () async {
          final list = await service.createList(name: 'Failed Delete');
          await service.addVideoToList(list!.id, 'kept_video');
          await service.addVideoToList(list.id, 'removed_video');
          final beforeDelete = service.getListById(list.id)!;
          final originalEventId = beforeDelete.nostrEventId;
          expect(originalEventId, isNotNull);
          clearInteractions(mockNostr);
          when(
            () => mockNostr.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final removed = await service.removeVideoFromList(
            list.id,
            'removed_video',
          );

          expect(removed, isFalse);
          var stored = service.getListById(list.id)!;
          expect(stored.videoEventIds, ['kept_video']);
          expect(stored.nostrEventId, originalEventId);
          expect(stored.pendingRepublish, isTrue);

          when(() => mockNostr.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );
          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) => Stream.value(
              Event.fromJson({
                'id': 'stale_relay_event',
                'pubkey': _ownerPubkey,
                'created_at':
                    beforeDelete.updatedAt.millisecondsSinceEpoch ~/ 1000,
                'kind': 30005,
                'tags': [
                  ['d', list.id],
                  ['title', 'Failed Delete'],
                  ['e', 'kept_video'],
                  ['e', 'removed_video'],
                ],
                'content': 'Failed Delete',
                'sig': 'test_signature',
              }),
            ),
          );

          await service.fetchUserListsFromRelays(force: true);

          stored = service.getListById(list.id)!;
          expect(stored.videoEventIds, ['kept_video']);
          expect(stored.pendingRepublish, isFalse);
          final republished =
              verify(
                    () => mockNostr.publishEventAwaitOk(captureAny()),
                  ).captured.last
                  as Event;
          expect(
            republished.tags,
            isNot(contains(equals(['e', 'removed_video']))),
          );
        },
      );

      test('merge repairs a legacy private collaborative list', () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            CuratedList(
              id: 'collaborative-local',
              name: 'Collaborative Local',
              videoEventIds: const ['local_video'],
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025),
              isPublic: false,
              isCollaborative: true,
              allowedCollaborators: const ['collaborator_pubkey'],
              pubkey: _ownerPubkey,
            ).toJson(),
          ]),
        });
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_collaborative_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'collaborative-local'],
                ['title', 'Collaborative Local'],
                ['e', 'relay_video'],
              ],
              'content': 'Collaborative Local',
              'sig': 'test_signature',
            }),
          ),
        );
        final upgraded = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: await SharedPreferences.getInstance(),
        );

        await upgraded.fetchUserListsFromRelays();

        final merged = upgraded.getListById('collaborative-local')!;
        expect(merged.isCollaborative, isFalse);
        expect(merged.allowedCollaborators, isEmpty);
        expect(merged.isPublic, isFalse);
      });

      test(
        'private list wins a collaborative relay conflict and republishes sealed',
        () async {
          await LogCaptureService().clearAllLogs();
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([
              CuratedList(
                id: 'private-local',
                name: 'Private Local',
                videoEventIds: const ['local_video'],
                createdAt: DateTime(2025),
                updatedAt: DateTime(2025),
                isPublic: false,
                pubkey: _ownerPubkey,
              ).toJson(),
            ]),
          });
          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) => Stream.value(
              Event.fromJson({
                'id': 'relay_collaborative_event',
                'pubkey': _ownerPubkey,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                'kind': 30005,
                'tags': [
                  ['d', 'private-local'],
                  ['title', 'Collaborative Relay'],
                  ['e', 'relay_video'],
                  ['collaborative', 'true'],
                  ['collaborator', _otherPubkey],
                ],
                'content': 'Collaborative Relay',
                'sig': 'test_signature',
              }),
            ),
          );
          final upgraded = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: await SharedPreferences.getInstance(),
          );

          await upgraded.fetchUserListsFromRelays();

          final merged = upgraded.getListById('private-local')!;
          expect(merged.isPublic, isFalse);
          expect(merged.isCollaborative, isFalse);
          expect(merged.allowedCollaborators, isEmpty);
          expect(merged.videoEventIds, ['relay_video', 'local_video']);

          final warning = LogCaptureService()
              .getRecentLogs()
              .where(
                (entry) =>
                    entry.level == LogLevel.warning &&
                    entry.message.contains('private-local'),
              )
              .single;
          expect(warning.level, LogLevel.warning);

          final republished =
              verify(
                    () => mockNostr.publishEventAwaitOk(captureAny()),
                  ).captured.last
                  as Event;
          expect(
            republished.tags,
            isNot(contains(equals(['e', 'local_video']))),
          );
          expect(
            republished.tags,
            isNot(contains(equals(['e', 'relay_video']))),
          );
          expect(_unseal(republished.content), isNotNull);
        },
      );

      test(
        'backs up null-pubkey local lists as the authenticated owner',
        () async {
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([
              CuratedList(
                id: 'null-pubkey-local',
                name: 'Null Pubkey Local',
                videoEventIds: const ['local_video'],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ).toJson(),
            ]),
          });
          final upgraded = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: await SharedPreferences.getInstance(),
          );

          await upgraded.fetchUserListsFromRelays();

          final stored = upgraded.getListById('null-pubkey-local')!;
          expect(stored.pubkey, _ownerPubkey);
          expect(stored.nostrEventId, isNotNull);
          final published =
              verify(
                    () => mockNostr.publishEventAwaitOk(captureAny()),
                  ).captured.single
                  as Event;
          expect(published.pubkey, _ownerPubkey);
        },
      );

      test('does not double-publish a list resolved during backfill', () async {
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: jsonEncode([
            CuratedList(
              id: 'first-stranded',
              name: 'First Stranded',
              videoEventIds: const ['first_video'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              pubkey: _ownerPubkey,
            ).toJson(),
            CuratedList(
              id: 'second-stranded',
              name: 'Second Stranded',
              videoEventIds: const ['second_video'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              pubkey: _ownerPubkey,
            ).toJson(),
          ]),
        });
        var publishCount = 0;
        late CuratedListService upgraded;
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          publishCount++;
          if (publishCount == 1) {
            await upgraded.addVideoToList('second-stranded', 'third_video');
          }
          return _accepted(invocation.positionalArguments[0] as Event);
        });
        upgraded = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: await SharedPreferences.getInstance(),
        );

        await upgraded.fetchUserListsFromRelays();

        verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
      });

      test(
        'does not backfill a subscribed list owned by someone else',
        () async {
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([
              CuratedList(
                id: 'foreign-stranded',
                name: 'Foreign Stranded',
                videoEventIds: const ['foreign_video'],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                pubkey: _otherPubkey,
              ).toJson(),
            ]),
          });
          final upgraded = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: await SharedPreferences.getInstance(),
          );

          await upgraded.fetchUserListsFromRelays();

          verifyNever(() => mockNostr.publishEventAwaitOk(any()));
          expect(
            upgraded.getListById('foreign-stranded')!.nostrEventId,
            isNull,
          );
        },
      );

      for (final scenario in <({String description, String? nextOwner})>[
        (description: 'authenticated owner changes', nextOwner: _otherPubkey),
        (description: 'authenticated pubkey is lost', nextOwner: null),
      ]) {
        test('stops backfill when the ${scenario.description}', () async {
          await LogCaptureService().clearAllLogs();
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: jsonEncode([
              CuratedList(
                id: 'first-stranded',
                name: 'First Stranded',
                videoEventIds: const ['first_video'],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ).toJson(),
              CuratedList(
                id: 'second-stranded',
                name: 'Second Stranded',
                videoEventIds: const ['second_video'],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ).toJson(),
            ]),
          });
          var publishCount = 0;
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            publishCount++;
            if (publishCount == 1) {
              // The signer follows the account. Re-stubbing only the auth
              // pubkey models auth != signer, which sealItemTags rejects
              // outright, so the fixture would not be a real switch.
              when(
                () => mockAuth.currentPublicKeyHex,
              ).thenReturn(scenario.nextOwner);
              when(
                mockSigner.getPublicKey,
              ).thenAnswer((_) async => scenario.nextOwner);
            }
            return _accepted(invocation.positionalArguments[0] as Event);
          });
          final upgraded = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: await SharedPreferences.getInstance(),
          );

          await upgraded.fetchUserListsFromRelays();

          verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
          expect(
            upgraded.getListById('first-stranded')!.nostrEventId,
            isNotNull,
          );
          final second = upgraded.getListById('second-stranded')!;
          expect(second.nostrEventId, isNull);
          expect(second.pubkey, isNull);
          expect(
            LogCaptureService().getRecentLogs().where(
              (entry) =>
                  entry.level == LogLevel.error &&
                  entry.message.contains('Failed to fetch lists from relays'),
            ),
            isEmpty,
            reason:
                'the owner guard must be what stopped the second publish; a '
                'swallowed backfill exception would satisfy the counts above',
          );
        });
      }

      test('does not republish a list the relay already has', () async {
        final list = await service.createList(name: 'Already Published');
        expect(service.getListById(list!.id)!.nostrEventId, isNotNull);
        clearInteractions(mockNostr);

        await service.fetchUserListsFromRelays(force: true);

        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
      });

      test('reconstructs a private list from its sealed content', () async {
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_private_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_private_1'],
                ['title', 'Sealed List'],
              ],
              'content': _seal(
                jsonEncode([
                  ['e', 'sealed_video_id'],
                  ['a', '34236:$_ownerPubkey:sealed-clip'],
                ]),
              ),
              'sig': 'test_signature',
            }),
          ),
        );

        await service.fetchUserListsFromRelays();

        final list = service.getListById('relay_private_1');
        expect(list, isNotNull);
        expect(list!.isPublic, isFalse);
        expect(list.name, 'Sealed List');
        expect(list.videoEventIds, [
          'sealed_video_id',
          '34236:$_ownerPubkey:sealed-clip',
        ]);
      });

      test('reconstructs legacy NIP-04 private list content', () async {
        const legacyCiphertext =
            'Y2lwaGVydGV4dA==?iv=aW5pdGlhbGl6YXRpb252ZWN0b3I=';
        when(
          () => mockSigner.decrypt(_ownerPubkey, legacyCiphertext),
        ).thenAnswer(
          (_) async => jsonEncode([
            ['e', 'legacy_private_video_id'],
          ]),
        );
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_nip04_private_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_nip04_private_1'],
                ['title', 'Legacy Private'],
              ],
              'content': legacyCiphertext,
              'sig': 'test_signature',
            }),
          ),
        );

        await service.fetchUserListsFromRelays();

        final list = service.getListById('relay_nip04_private_1');
        expect(list, isNotNull);
        expect(list!.isPublic, isFalse);
        expect(list.videoEventIds, ['legacy_private_video_id']);
      });

      test('skips a sealed list signed by another user', () async {
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_foreign_event',
              'pubkey': _otherPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_foreign_1'],
                ['title', 'Someone Else'],
              ],
              'content': _seal(
                jsonEncode([
                  ['e', 'their_private_video_id'],
                ]),
              ),
              'sig': 'test_signature',
            }),
          ),
        );

        await service.fetchUserListsFromRelays();

        // A sealed event must never fall through as a public empty list when
        // its author cannot be authenticated as the current owner.
        verifyNever(() => mockSigner.nip44Decrypt(any(), any()));
        expect(service.getListById('relay_foreign_1'), isNull);
      });

      test('skips a sealed event if the user signs out during sync', () async {
        final events = StreamController<Event>();
        when(() => mockNostr.subscribe(any())).thenAnswer((_) => events.stream);

        final sync = service.fetchUserListsFromRelays();
        when(() => mockAuth.isAuthenticated).thenReturn(false);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        events.add(
          Event.fromJson({
            'id': 'relay_signed_out_event',
            'pubkey': _ownerPubkey,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'relay_signed_out_1'],
              ['title', 'Signed Out Mid-Sync'],
            ],
            'content': _seal(
              jsonEncode([
                ['e', 'private_video_id'],
              ]),
            ),
            'sig': 'test_signature',
          }),
        );
        await events.close();
        await sync;

        verifyNever(() => mockSigner.nip44Decrypt(any(), any()));
        expect(service.getListById('relay_signed_out_1'), isNull);
      });

      test('keeps a list whose content will not unseal', () async {
        when(
          () => mockSigner.nip44Decrypt(any(), any()),
        ).thenAnswer((_) async => null);
        when(() => mockNostr.subscribe(any())).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_legacy_event',
              'pubkey': _ownerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_legacy_1'],
                ['title', 'Legacy List'],
                ['e', 'legacy_video_id'],
              ],
              'content': 'Curated video list: Legacy List',
              'sig': 'test_signature',
            }),
          ),
        );

        await service.fetchUserListsFromRelays();

        // Every list published before this change has a plain description in
        // content. Failing to unseal it means it is one of those, not that
        // the list should be dropped.
        final list = service.getListById('relay_legacy_1');
        expect(list, isNotNull);
        expect(list!.isPublic, isTrue);
        expect(list.videoEventIds, ['legacy_video_id']);
      });

      test(
        'keeps local private list when sealed relay copy will not unseal',
        () async {
          final list = await service.createList(
            name: 'Local Private',
            isPublic: false,
          );
          await service.addVideoToList(list!.id, 'local_private_video_id');
          final localUpdatedAt = service.getListById(list.id)!.updatedAt;
          when(
            () => mockSigner.nip44Decrypt(any(), any()),
          ).thenAnswer((_) async => null);
          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) => Stream.value(
              Event.fromJson({
                'id': 'relay_private_unreadable_event',
                'pubkey': _ownerPubkey,
                'created_at':
                    localUpdatedAt
                        .add(const Duration(seconds: 10))
                        .millisecondsSinceEpoch ~/
                    1000,
                'kind': 30005,
                'tags': [
                  ['d', list.id],
                  ['title', 'Local Private'],
                ],
                'content': _seal('but signer not ready'),
                'sig': 'test_signature',
              }),
            ),
          );

          await service.fetchUserListsFromRelays(force: true);

          final retained = service.getListById(list.id);
          expect(retained, isNotNull);
          expect(retained!.isPublic, isFalse);
          expect(retained.videoEventIds, ['local_private_video_id']);
        },
      );
    });

    group('createList()', () {
      test('creates list with name only', () async {
        final list = await service.createList(name: 'My Videos');

        expect(list, isNotNull);
        expect(list!.name, 'My Videos');
        expect(list.id, startsWith('list_'));
        expect(list.videoEventIds, isEmpty);
        expect(list.isPublic, isTrue);
        expect(list.tags, isEmpty);
        expect(list.playOrder, PlayOrder.chronological);
      });

      test('creates list with all optional fields', () async {
        final list = await service.createList(
          name: 'Test List',
          description: 'A test list',
          imageUrl: 'https://example.com/image.jpg',
          tags: ['test', 'demo'],
          isCollaborative: true,
          allowedCollaborators: ['collaborator_pubkey'],
          thumbnailEventId: 'thumbnail_event_id',
          playOrder: PlayOrder.shuffle,
        );

        expect(list, isNotNull);
        expect(list!.name, 'Test List');
        expect(list.description, 'A test list');
        expect(list.imageUrl, 'https://example.com/image.jpg');
        expect(list.isPublic, isTrue);
        expect(list.tags, ['test', 'demo']);
        expect(list.isCollaborative, isTrue);
        expect(list.allowedCollaborators, ['collaborator_pubkey']);
        expect(list.thumbnailEventId, 'thumbnail_event_id');
        expect(list.playOrder, PlayOrder.shuffle);
      });

      test('rejects a private collaborative list', () async {
        final list = await service.createList(
          name: 'Private Collaboration',
          isPublic: false,
          isCollaborative: true,
        );

        expect(list, isNull);
        expect(service.lists, isEmpty);
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test(
        'rapidly created lists get unique ids and keep their data',
        () async {
          for (var i = 0; i < 10; i++) {
            await service.createList(name: 'List $i');
          }

          expect(service.lists, hasLength(10));
          expect(service.lists.map((l) => l.id).toSet(), hasLength(10));
          expect(
            service.lists.map((l) => l.name).toSet(),
            hasLength(10),
            reason:
                'an ID collision makes the post-publish update '
                'overwrite a sibling list',
          );
        },
      );

      test('adds created list to lists collection', () async {
        expect(service.lists, isEmpty);

        await service.createList(name: 'Test List');

        expect(service.lists.length, 1);
        expect(service.lists.first.name, 'Test List');
      });

      test('publishes empty public list to Nostr on creation', () async {
        final list = await service.createList(name: 'Empty Public List');

        // An unpublished list exists only on this device, so even empty
        // lists publish immediately.
        verify(
          () => mockAuth.createAndSignEvent(
            kind: 30005,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);
        verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
        expect(service.getListById(list!.id)!.nostrEventId, isNotNull);
      });

      test(
        'does not double-publish a list created during a relay sync',
        () async {
          // A create's confirmed publish and a background sync's backfill both
          // target the new list. They must run on the same operation lane so the
          // backfill cannot publish a second event for the coordinate while the
          // create is still in flight.
          final release = Completer<void>();
          final publishedDTags = <String>[];
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments[0] as Event;
            publishedDTags.add(
              event.tags.firstWhere((tag) => tag.first == 'd').last,
            );
            await release.future;
            return _accepted(event);
          });

          final createFuture = service.createList(name: 'Race List');
          await pumpEventQueue();

          final syncFuture = service.fetchUserListsFromRelays();
          await pumpEventQueue();

          release.complete();
          final created = await createFuture;
          await syncFuture;

          expect(publishedDTags.where((dTag) => dTag == created!.id).length, 1);
        },
      );

      test('publishes again when a video is added', () async {
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        await service.addVideoToList(list!.id, 'test_video_id');

        verify(() => mockNostr.publishEvent(any())).called(1);
      });

      test('keeps a local list when confirmed publication fails', () async {
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) => Future<PublishOutcome>.value(
            _rejected(invocation.positionalArguments[0] as Event),
          ),
        );

        final list = await service.createList(name: 'Unlucky List');

        expect(list, isNotNull);
        expect(list!.nostrEventId, isNull);
        expect(service.getListById(list.id), isNotNull);
      });

      test('keeps a local list when event signing fails', () async {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final list = await service.createList(name: 'Unsigned List');

        expect(list, isNotNull);
        expect(list!.nostrEventId, isNull);
        expect(service.getListById(list.id), isNotNull);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('publishes a private list with its items encrypted', () async {
        final list = await service.createList(
          name: 'Private List',
          isPublic: false,
        );

        expect(list, isNotNull);
        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.kind, 30005);

        // The list exists and is named on the relay; what is in it is not.
        expect(published.tags, contains(equals(['d', list!.id])));
        expect(published.tags, contains(equals(['title', 'Private List'])));
        expect(
          published.tags.any(
            (dynamic tag) =>
                (tag as List<dynamic>).isNotEmpty &&
                (tag.first == 'e' || tag.first == 'a'),
          ),
          isFalse,
          reason: 'a private list must not publish its items as tags',
        );
        expect(_unseal(published.content), isNotNull);
      });

      test('does not expose a private list thumbnail as metadata', () async {
        await service.createList(
          name: 'Private Thumbnail',
          isPublic: false,
          thumbnailEventId: 'private_video_thumbnail',
        );

        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(
          published.tags.any(
            (tag) => tag.isNotEmpty && tag.first == 'thumbnail',
          ),
          isFalse,
        );
      });

      test('seals the item tags into the encrypted content', () async {
        final list = await service.createList(
          name: 'Private List',
          isPublic: false,
        );
        await service.addVideoToList(list!.id, 'video_event_id');

        // The republish after an item change is fire-and-forget, so it takes
        // the unconfirmed path.
        final published =
            verify(() => mockNostr.publishEvent(captureAny())).captured.last
                as Event;
        expect(jsonDecode(_unseal(published.content)!), [
          ['e', 'video_event_id'],
        ]);
      });

      test('encrypts to the list owner, not to a third party', () async {
        await service.createList(name: 'Private List', isPublic: false);

        final recipient =
            verify(
                  () => mockSigner.nip44Encrypt(captureAny(), any()),
                ).captured.single
                as String;
        expect(recipient, _ownerPubkey);
      });

      test('does not encrypt with a signer for another account', () async {
        when(mockSigner.getPublicKey).thenAnswer((_) async => _otherPubkey);

        final list = await service.createList(
          name: 'Wrong Signer',
          isPublic: false,
        );

        expect(list, isNotNull);
        expect(list!.nostrEventId, isNull);
        verifyNever(() => mockSigner.nip44Encrypt(any(), any()));
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('keeps a local private list it could not encrypt', () async {
        when(
          () => mockSigner.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => null);

        final list = await service.createList(
          name: 'Private List',
          isPublic: false,
        );

        // It remains usable offline, with a null event id so a later complete
        // sync can retry the encrypted backup.
        expect(list, isNotNull);
        expect(list!.nostrEventId, isNull);
        expect(service.getListById(list.id), isNotNull);
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
      });

      test('rejects an item mutation beyond the NIP-44 limit', () async {
        final list = await service.createList(
          name: 'Bounded Private List',
          isPublic: false,
        );
        clearInteractions(mockSigner);
        clearInteractions(mockAuth);
        clearInteractions(mockNostr);

        final result = await service.addVideoToList(
          list!.id,
          List<String>.filled(70000, 'v').join(),
        );

        expect(result, isFalse);
        expect(service.getListById(list.id)!.videoEventIds, isEmpty);
        verifyNever(() => mockSigner.nip44Encrypt(any(), any()));
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('does not publish when user not authenticated', () async {
        when(() => mockAuth.isAuthenticated).thenReturn(false);

        await service.createList(name: 'Test List');

        // Should not attempt to publish
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('saves list to SharedPreferences', () async {
        await service.createList(name: 'Test List');

        // Should have saved lists to prefs
        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, contains('Test List'));
      });

      test('assigns unique IDs to multiple lists', () async {
        final list1 = await service.createList(name: 'List 1');

        // Wait a bit to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 5));

        final list2 = await service.createList(name: 'List 2');

        expect(list1!.id, isNot(equals(list2!.id)));
      });

      test('sets createdAt and updatedAt to same time', () async {
        final list = await service.createList(name: 'Test List');

        expect(list!.createdAt, list.updatedAt);
      });
    });

    group('updateList()', () {
      test('updates list name', () async {
        final list = await service.createList(name: 'Original Name');
        final originalUpdatedAt = list!.updatedAt;

        // Wait a bit to ensure updatedAt changes
        await Future.delayed(const Duration(milliseconds: 10));

        final result = await service.updateList(
          listId: list.id,
          name: 'Updated Name',
        );

        expect(result, isTrue);

        final updatedList = service.getListById(list.id);
        expect(updatedList!.name, 'Updated Name');
        expect(updatedList.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });

      test('updates list description', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(
          listId: list!.id,
          description: 'New description',
        );

        final updatedList = service.getListById(list.id);
        expect(updatedList!.description, 'New description');
      });

      test('updates multiple fields at once', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(
          listId: list!.id,
          name: 'Updated Name',
          description: 'Updated description',
          imageUrl: 'https://example.com/new-image.jpg',
          tags: ['updated', 'tags'],
          playOrder: PlayOrder.reverse,
        );

        final updatedList = service.getListById(list.id);
        expect(updatedList!.name, 'Updated Name');
        expect(updatedList.description, 'Updated description');
        expect(updatedList.imageUrl, 'https://example.com/new-image.jpg');
        expect(updatedList.tags, ['updated', 'tags']);
        expect(updatedList.playOrder, PlayOrder.reverse);
      });

      test('publishes update to Nostr for public list with videos', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'test_video_id');
        reset(mockNostr); // Clear previous invocations

        // Re-setup mocks after reset
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _accepted(invocation.positionalArguments[0] as Event);
        });

        await service.updateList(listId: list.id, name: 'Updated Name');

        verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
      });

      test('republishes a private list when it is renamed', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: false,
        );
        reset(mockNostr); // Clear previous invocations
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        await service.updateList(listId: list!.id, name: 'Updated Name');

        // The title is public metadata even on a private list, so the relay
        // copy goes stale unless the rename is republished.
        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.tags, contains(equals(['title', 'Updated Name'])));
      });

      test('flags a failed rename for backfill retry', () async {
        final list = await service.createList(name: 'Original Name');
        final originalEventId = list!.nostrEventId;
        expect(originalEventId, isNotNull);

        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _rejected(invocation.positionalArguments[0] as Event),
        );

        final result = await service.updateList(
          listId: list.id,
          name: 'Updated Name',
        );

        expect(result, isFalse);
        final stored = service.getListById(list.id);
        // The rename is kept locally and flagged for backfill. The previous
        // event id must stay as the marker that relays may still hold this
        // coordinate, so later redaction/deletion can retire it.
        expect(stored!.name, 'Updated Name');
        expect(stored.nostrEventId, originalEventId);
        expect(stored.pendingRepublish, isTrue);
      });

      test(
        'redacts the plaintext event after a failed rename then privacy flip',
        () async {
          final list = await service.createList(name: 'Public List');
          final plaintextEventId = service.getListById(list!.id)!.nostrEventId;
          expect(plaintextEventId, isNotNull);

          reset(mockNostr);
          when(() => mockNostr.signer).thenReturn(mockSigner);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _rejected(invocation.positionalArguments[0] as Event),
          );

          final renamed = await service.updateList(
            listId: list.id,
            name: 'Renamed Locally',
          );

          expect(renamed, isFalse);
          final pending = service.getListById(list.id)!;
          expect(pending.nostrEventId, plaintextEventId);
          expect(pending.pendingRepublish, isTrue);

          clearInteractions(mockNostr);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _accepted(invocation.positionalArguments[0] as Event),
          );
          when(() => mockNostr.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final flipped = await service.updateList(
            listId: list.id,
            isPublic: false,
          );

          expect(flipped, isTrue);
          final redaction =
              verify(() => mockNostr.publishEvent(captureAny())).captured.single
                  as Event;
          expect(redaction.kind, EventKind.eventDeletion);
          expect(redaction.tags, contains(equals(['e', plaintextEventId])));
          expect(redaction.tags, contains(equals(['k', '30005'])));
        },
      );

      test('returns false for non-existent list', () async {
        final result = await service.updateList(
          listId: 'non_existent_list',
          name: 'New Name',
        );

        expect(result, isFalse);
      });

      test('saves updated list to SharedPreferences', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(listId: list!.id, name: 'Updated Name');

        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, contains('Updated Name'));
        expect(savedLists, isNot(contains('Test List')));
      });

      test('preserves unchanged fields', () async {
        final list = await service.createList(
          name: 'Test List',
          description: 'Original description',
          tags: ['original', 'tags'],
        );

        await service.updateList(listId: list!.id, name: 'Updated Name');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.description, 'Original description');
        expect(updatedList.tags, ['original', 'tags']);
      });

      test('replaces the public event when a list becomes private', () async {
        final list = await service.createList(name: 'Public List');
        await service.addVideoToList(list!.id, 'video_event_id');
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.updateList(
          listId: list.id,
          isPublic: false,
        );

        expect(result, isTrue);
        expect(service.getListById(list.id)!.isPublic, isFalse);

        // Kind 30005 is addressable: republishing under the same d-tag
        // replaces the public copy, with the items moved out of plain tags
        // into sealed content.
        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.kind, 30005);
        expect(published.tags, contains(equals(['d', list.id])));
        expect(
          published.tags.any(
            (dynamic tag) =>
                (tag as List<dynamic>).isNotEmpty && tag.first == 'e',
          ),
          isFalse,
        );
        expect(jsonDecode(_unseal(published.content)!), [
          ['e', 'video_event_id'],
        ]);
      });

      test('redacts the plaintext event when a list becomes private', () async {
        final list = await service.createList(name: 'Public List');
        final plaintextEventId = service.getListById(list!.id)!.nostrEventId;
        expect(plaintextEventId, isNotNull);
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        await service.updateList(listId: list.id, isPublic: false);

        // The replacement only reaches relays that accepted it, so the ones
        // that did not are asked to drop the plaintext event instead. It has
        // to be an `e` tag on the old event id: NIP-09 honours an `a` tag on
        // the coordinate for every version up to the request, which would
        // take the sealed replacement down with the original.
        final redaction =
            verify(() => mockNostr.publishEvent(captureAny())).captured.single
                as Event;
        expect(redaction.kind, EventKind.eventDeletion);
        expect(redaction.tags, contains(equals(['e', plaintextEventId])));
        expect(redaction.tags, contains(equals(['k', '30005'])));
        expect(
          redaction.tags.any(
            (dynamic tag) =>
                (tag as List<dynamic>).isNotEmpty && tag.first == 'a',
          ),
          isFalse,
        );
      });

      test('commits privacy when only some relays accept it', () async {
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _partiallyAccepted(invocation.positionalArguments[0] as Event),
        );
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.updateList(
          listId: list!.id,
          isPublic: false,
        );

        // One relay already holds the sealed copy. Reading public locally
        // would let the next edit publish plain item tags over it, so the
        // flip commits and the relays that rejected it get the redaction.
        expect(result, isTrue);
        expect(service.getListById(list.id)!.isPublic, isFalse);
        verify(() => mockNostr.publishEvent(any())).called(1);
      });

      test('keeps a list private when its redaction fails', () async {
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );
        when(
          () => mockNostr.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        final result = await service.updateList(
          listId: list!.id,
          isPublic: false,
        );

        // NIP-09 is a request relays may ignore anyway, so the flip cannot
        // depend on it — the sealed replacement is already accepted.
        expect(result, isTrue);
        expect(service.getListById(list.id)!.isPublic, isFalse);
      });

      test('unsets the description when the edit clears it', () async {
        final list = await service.createList(
          name: 'Described',
          description: 'Original',
          isPublic: false,
        );

        final result = await service.updateList(
          listId: list!.id,
          description: '',
        );

        expect(result, isTrue);
        expect(service.getListById(list.id)!.description, isNull);
      });

      test('leaves the description alone when it is not passed', () async {
        final list = await service.createList(
          name: 'Described',
          description: 'Original',
          isPublic: false,
        );

        await service.updateList(listId: list!.id, name: 'Renamed');

        expect(service.getListById(list.id)!.description, equals('Original'));
      });

      test('keeps the Nostr event id when a list becomes private', () async {
        final list = await service.createList(name: 'Public List');
        expect(service.getListById(list!.id)!.nostrEventId, isNotNull);
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        await service.updateList(listId: list.id, isPublic: false);

        // A private list is still published, just with its items sealed, so
        // the event id identifies a real event rather than a deleted one.
        expect(service.getListById(list.id)!.nostrEventId, isNotNull);
        expect(service.myLists.map((l) => l.id), contains(list.id));
      });

      test(
        'keeps a list public when the private republish is rejected',
        () async {
          final list = await service.createList(name: 'Public List');
          reset(mockNostr);
          when(() => mockNostr.signer).thenReturn(mockSigner);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _rejected(invocation.positionalArguments[0] as Event),
          );

          final result = await service.updateList(
            listId: list!.id,
            isPublic: false,
          );

          // Relays still hold the public copy with its items in plain tags, so
          // showing the list as private would understate what is exposed. No
          // relay took the sealed replacement either, so there is nothing the
          // redaction could usefully retire.
          expect(result, isFalse);
          expect(service.getListById(list.id)!.isPublic, isTrue);
          verifyNever(() => mockNostr.publishEvent(any()));
        },
      );

      test('does not make a collaborative list private', () async {
        final list = await service.createList(
          name: 'Collaborative',
          isCollaborative: true,
        );

        final result = await service.updateList(
          listId: list!.id,
          isPublic: false,
        );

        expect(result, isFalse);
        final stored = service.getListById(list.id)!;
        expect(stored.isPublic, isTrue);
        expect(stored.isCollaborative, isTrue);
      });

      test('rejects a visibility change atomically while signed out', () async {
        final list = await service.createList(name: 'Public List');
        when(() => mockAuth.isAuthenticated).thenReturn(false);

        final result = await service.updateList(
          listId: list!.id,
          name: 'Should Not Stick',
          isPublic: false,
        );

        expect(result, isFalse);
        final stored = service.getListById(list.id)!;
        expect(stored.name, 'Public List');
        expect(stored.isPublic, isTrue);
      });

      test('publishes a private list before marking it public', () async {
        final list = await service.createList(
          name: 'Private List',
          isPublic: false,
        );

        final result = await service.updateList(
          listId: list!.id,
          isPublic: true,
        );

        expect(result, isTrue);
        expect(service.getListById(list.id)!.isPublic, isTrue);
        // Creating the private list published it too, so the transition is
        // the second event, and it unseals the items back into plain tags.
        final publication =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.last
                as Event;
        expect(publication.kind, 30005);
        expect(_unseal(publication.content), isNull);
      });

      test('keeps a list private when publication is rejected', () async {
        final list = await service.createList(
          name: 'Private List',
          description: 'Original',
          isPublic: false,
        );
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _rejected(invocation.positionalArguments[0] as Event),
        );

        final result = await service.updateList(
          listId: list!.id,
          name: 'Renamed',
          isPublic: true,
        );

        // The visibility change is the relay's to confirm, so it does not
        // stick. The rename is this device's, so losing it to an unreachable
        // relay would be data loss the user never asked for.
        expect(result, isFalse);
        final stored = service.getListById(list.id)!;
        expect(stored.isPublic, isFalse);
        expect(stored.name, equals('Renamed'));
      });

      test(
        'keeps a rename when the relay rejects a public list update',
        () async {
          final list = await service.createList(name: 'Public List');
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _rejected(invocation.positionalArguments[0] as Event),
          );

          final result = await service.updateList(
            listId: list!.id,
            name: 'Renamed',
            description: 'Written offline',
          );

          expect(result, isFalse);
          final stored = service.getListById(list.id)!;
          expect(stored.name, equals('Renamed'));
          expect(stored.description, equals('Written offline'));
          expect(stored.isPublic, isTrue);
        },
      );

      test('confirms relay acceptance before rolling an update back', () async {
        // publishEvent queues a failed send and replays it on reconnect, so a
        // caller that rolls local state back on its result can undo an event
        // the relays still receive. The confirmed path must be used instead.
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        await service.updateList(listId: list!.id, name: 'Renamed');

        verify(() => mockNostr.publishEventAwaitOk(any())).called(1);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('keeps the published event id on a public update', () async {
        final list = await service.createList(name: 'Public List');
        final publishedId = service.getListById(list!.id)!.nostrEventId;
        expect(publishedId, isNotNull);

        await service.updateList(listId: list.id, name: 'Renamed');

        final stored = service.getListById(list.id)!;
        expect(stored.name, equals('Renamed'));
        expect(stored.nostrEventId, isNotNull);
      });

      test('keeps a video added while the update was publishing', () async {
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);

        // Held open so the add lands inside the update's publish, which under
        // publishEventAwaitOk runs to a 15s deadline rather than a socket
        // write.
        final publishGate = Completer<void>();
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          await publishGate.future;
          return _accepted(invocation.positionalArguments[0] as Event);
        });
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final pendingUpdate = service.updateList(
          listId: list!.id,
          name: 'Renamed',
        );
        final pendingAdd = service.addVideoToList(
          list.id,
          'video_added_mid_publish',
        );
        await pumpEventQueue();
        publishGate.complete();

        expect(await pendingUpdate, isTrue);
        expect(await pendingAdd, isTrue);
        final stored = service.getListById(list.id)!;
        expect(stored.name, equals('Renamed'));
        expect(stored.videoEventIds, contains('video_added_mid_publish'));
      });

      test('serializes an add behind a private transition', () async {
        final list = await service.createList(name: 'Public List');
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);

        final privacyGate = Completer<void>();
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          await privacyGate.future;
          return _accepted(invocation.positionalArguments[0] as Event);
        });
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final pendingPrivacy = service.updateList(
          listId: list!.id,
          isPublic: false,
        );
        await pumpEventQueue();
        final pendingAdd = service.addVideoToList(
          list.id,
          'added_during_privacy_change',
        );
        await pumpEventQueue();
        verifyNever(() => mockNostr.publishEvent(any()));

        privacyGate.complete();
        expect(await pendingPrivacy, isTrue);
        expect(await pendingAdd, isTrue);

        // The flip also fires a kind 5 redaction of the plaintext event
        // through the same unconfirmed path, so pick the list event out.
        final addEvent = verify(
          () => mockNostr.publishEvent(captureAny()),
        ).captured.cast<Event>().singleWhere((event) => event.kind == 30005);
        expect(
          addEvent.tags.any(
            (tag) => tag.isNotEmpty && (tag.first == 'e' || tag.first == 'a'),
          ),
          isFalse,
        );
        expect(jsonDecode(_unseal(addEvent.content)!), [
          ['e', 'added_during_privacy_change'],
        ]);
      });
    });

    group('deleteOwnedList()', () {
      test('publishes NIP-09 deletion for owned kind 30005 list', () async {
        final list = await service.createList(name: 'Owned Public List');
        // Creation publishes the kind 30005 event; reset so the capture
        // below only sees the deletion event.
        reset(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isTrue);
        expect(service.getListById(list.id), isNull);

        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.kind, EventKind.eventDeletion);
        expect(published.content, 'Deleted curated list ${list.id}');
        expect(
          published.tags,
          contains(equals(['a', '30005:$_ownerPubkey:${list.id}'])),
        );
        expect(published.tags, contains(equals(['k', '30005'])));
      });

      test(
        'a deleted list is not resurrected by a later relay event',
        () async {
          final list = await service.createList(name: 'Doomed List');
          final listId = list!.id;
          reset(mockNostr);
          when(() => mockNostr.signer).thenReturn(mockSigner);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _accepted(invocation.positionalArguments[0] as Event),
          );

          expect(await service.deleteOwnedList(listId), isTrue);
          expect(service.getListById(listId), isNull);

          // NIP-09 is advisory. A relay that never saw the deletion, or chose
          // not to honour it, keeps serving the original kind 30005 event.
          when(
            () => mockNostr.subscribe(any()),
          ).thenAnswer((_) => Stream.value(_listEvent(listId, 'Doomed List')));

          await service.fetchUserListsFromRelays(force: true);

          expect(service.getListById(listId), isNull);
        },
      );

      test('records the tombstone before exposing local removal', () async {
        final list = await service.createList(name: 'Doomed List');
        final listId = list!.id;
        reset(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        var removalWasProtected = false;
        service.setOnListUnsubscribed((removedListId) {
          final tombstones = prefs.getStringList(
            CuratedListService.deletedListCoordinatesStorageKey,
          );
          removalWasProtected =
              service.getListById(removedListId) == null &&
              (tombstones?.contains('$_ownerPubkey:$removedListId') ?? false);
        });

        expect(await service.deleteOwnedList(listId), isTrue);

        expect(removalWasProtected, isTrue);
      });

      test(
        'the deletion survives a new service over the same storage',
        () async {
          final list = await service.createList(name: 'Doomed List');
          final listId = list!.id;
          reset(mockNostr);
          when(() => mockNostr.signer).thenReturn(mockSigner);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _accepted(invocation.positionalArguments[0] as Event),
          );
          expect(await service.deleteOwnedList(listId), isTrue);

          when(
            () => mockNostr.subscribe(any()),
          ).thenAnswer((_) => Stream.value(_listEvent(listId, 'Doomed List')));

          final relaunched = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: prefs,
          );
          await relaunched.fetchUserListsFromRelays(force: true);

          expect(relaunched.getListById(listId), isNull);
        },
      );

      test(
        'a re-created default list is not blocked by its own tombstone',
        () async {
          // The tombstone and the default-deleted flag are two separate pref
          // writes, so a launch killed between them leaves the tombstone set and
          // the flag clear. initialize() then re-creates "My List" on the same
          // coordinate, and without lifting the tombstone the new list's own
          // relay events would be discarded for the life of the install.
          SharedPreferences.setMockInitialValues({
            CuratedListService.deletedListCoordinatesStorageKey: <String>[
              '$_ownerPubkey:${CuratedListService.defaultListId}',
            ],
          });
          final relaunched = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: await SharedPreferences.getInstance(),
          );
          await relaunched.initialize();
          final defaultList = relaunched.getDefaultList();
          expect(defaultList, isNotNull);

          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) => Stream.value(_listEvent(defaultList!.id, 'My List')),
          );
          await relaunched.fetchUserListsFromRelays(force: true);

          expect(relaunched.getDefaultList(), isNotNull);
        },
      );

      test(
        "deleting one list does not suppress another owner's same id",
        () async {
          final list = await service.createList(name: 'Doomed List');
          final listId = list!.id;
          reset(mockNostr);
          when(() => mockNostr.signer).thenReturn(mockSigner);
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
            (invocation) async =>
                _accepted(invocation.positionalArguments[0] as Event),
          );
          expect(await service.deleteOwnedList(listId), isTrue);

          // A `d` tag is only unique per pubkey, so the tombstone has to be
          // keyed by owner. Someone else's list that happens to share the
          // identifier is a different coordinate entirely.
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_otherPubkey);
          when(mockSigner.getPublicKey).thenAnswer((_) async => _otherPubkey);
          when(() => mockNostr.subscribe(any())).thenAnswer(
            (_) =>
                Stream.value(_listEvent(listId, 'Someone Else', _otherPubkey)),
          );

          await service.fetchUserListsFromRelays(force: true);

          expect(service.getListById(listId), isNotNull);
          expect(service.getListById(listId)!.pubkey, _otherPubkey);
        },
      );

      test('keeps local list when publish fails', () async {
        final list = await service.createList(name: 'Owned Public List');
        reset(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) => Future<PublishOutcome>.value(
            _rejected(invocation.positionalArguments[0] as Event),
          ),
        );

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isFalse);
        expect(service.getListById(list.id), isNotNull);
      });

      test('publishes a deletion for an owned private list', () async {
        final list = await service.createList(
          name: 'Owned Private List',
          isPublic: false,
        );
        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isTrue);
        expect(service.getListById(list.id), isNull);

        // A private list lives on relays too now, so dropping it locally
        // without asking them to drop it would leave it behind.
        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.kind, EventKind.eventDeletion);
        expect(
          published.tags,
          contains(equals(['a', '30005:$_ownerPubkey:${list.id}'])),
        );
      });

      test(
        'deletes the requested list when an earlier one goes first',
        () async {
          final earlier = await service.createList(
            name: 'Earlier',
            isPublic: false,
          );
          final target = await service.createList(name: 'Target');
          final later = await service.createList(
            name: 'Later',
            isPublic: false,
          );
          reset(mockNostr);

          // Held open so the second delete lands inside the deletion publish,
          // which under publishEventAwaitOk can run to a 15s deadline.
          final deletionGate = Completer<void>();
          when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            await deletionGate.future;
            return _accepted(invocation.positionalArguments[0] as Event);
          });

          // Both deletes publish a NIP-09 request now that private lists live
          // on relays too, so the second cannot be awaited before the gate
          // opens — starting it here still lands it inside the first publish.
          final pendingDelete = service.deleteOwnedList(target!.id);
          final pendingEarlierDelete = service.deleteOwnedList(earlier!.id);
          deletionGate.complete();

          expect(await pendingEarlierDelete, isTrue);
          expect(await pendingDelete, isTrue);
          expect(service.getListById(target.id), isNull);
          expect(service.getListById(later!.id), isNotNull);
        },
      );

      test('publishes a deletion for the default list', () async {
        await service.initialize();
        final defaultList = service.getDefaultList();
        expect(defaultList, isNotNull);
        clearInteractions(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        final result = await service.deleteOwnedList(defaultList!.id);

        expect(result, isTrue);
        expect(service.hasDefaultList(), isFalse);
        expect(
          prefs.getBool(CuratedListService.defaultListDeletedStorageKey),
          isTrue,
        );
        final published =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.kind, EventKind.eventDeletion);
        expect(
          published.tags,
          contains(
            equals([
              'a',
              '30005:$_ownerPubkey:${CuratedListService.defaultListId}',
            ]),
          ),
        );
      });

      test('deletes the relay coordinate after a failed rename', () async {
        final list = await service.createList(name: 'Public List');
        final originalEventId = service.getListById(list!.id)!.nostrEventId;
        expect(originalEventId, isNotNull);

        reset(mockNostr);
        when(() => mockNostr.signer).thenReturn(mockSigner);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _rejected(invocation.positionalArguments[0] as Event),
        );

        final renamed = await service.updateList(
          listId: list.id,
          name: 'Renamed Locally',
        );

        expect(renamed, isFalse);
        final pending = service.getListById(list.id)!;
        expect(pending.nostrEventId, originalEventId);
        expect(pending.pendingRepublish, isTrue);

        clearInteractions(mockNostr);
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async =>
              _accepted(invocation.positionalArguments[0] as Event),
        );

        final deleted = await service.deleteOwnedList(list.id);

        expect(deleted, isTrue);
        expect(service.getListById(list.id), isNull);
        final deletion =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(deletion.kind, EventKind.eventDeletion);
        expect(
          deletion.tags,
          contains(equals(['a', '30005:$_ownerPubkey:${list.id}'])),
        );
      });

      test('returns false for missing and unowned list', () async {
        await service.initialize();
        final missingResult = await service.deleteOwnedList('missing-list');
        final now = DateTime(2026);
        final unownedList = CuratedList(
          id: 'unowned-list',
          name: 'Unowned List',
          pubkey: _otherPubkey,
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );
        await service.subscribeToList(unownedList.id, unownedList);

        final unownedResult = await service.deleteOwnedList(unownedList.id);

        expect(missingResult, isFalse);
        expect(unownedResult, isFalse);
        expect(service.hasDefaultList(), isTrue);
        expect(service.getListById(unownedList.id), isNotNull);
      });
    });

    group('getListById()', () {
      test('returns list when it exists', () async {
        final list = await service.createList(name: 'Test List');

        final retrieved = service.getListById(list!.id);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, list.id);
        expect(retrieved.name, list.name);
      });

      test('returns null when list does not exist', () {
        final retrieved = service.getListById('non_existent_list');

        expect(retrieved, isNull);
      });

      test('returns correct list when multiple lists exist', () async {
        await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 3');

        final retrieved = service.getListById(list2!.id);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, list2.id);
        expect(retrieved.name, 'List 2');
      });
    });

    group('lists getter', () {
      test('returns immutable list', () async {
        await service.createList(name: 'Test List');

        final lists = service.lists;

        // Should not be able to modify the returned list
        expect(
          () => lists.add(
            CuratedList(
              id: 'fake_id',
              name: 'Fake List',
              videoEventIds: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
          throwsUnsupportedError,
        );
      });

      test('returns all lists', () async {
        await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 3');

        expect(service.lists.length, 3);
        expect(service.lists.map((l) => l.name), [
          'List 1',
          'List 2',
          'List 3',
        ]);
      });

      test('returns empty list initially', () {
        expect(service.lists, isEmpty);
      });
    });
  });
}
