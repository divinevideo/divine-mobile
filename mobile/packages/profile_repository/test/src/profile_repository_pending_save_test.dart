// ABOUTME: Tests the offline-tolerant pending-save slot on ProfileRepository
// ABOUTME: (#3161): enqueue delegation + drivePendingSave orchestration
// ABOUTME: outcomes, using a real in-memory PendingProfileSavesDao.

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements Client {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockEvent extends Mock implements Event {
  @override
  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true);

  @override
  List<List<String>> get tags => const [];
}

const _testNameServer = 'https://names.test.example';

void main() {
  group('ProfileRepository pending-save slot (#3161)', () {
    late _MockNostrClient nostrClient;
    late _MockHttpClient httpClient;
    late _MockUserProfilesDao userProfilesDao;
    late AppDatabase db;
    late PendingProfileSavesDao slotDao;
    late ProfileRepository repository;
    late _MockEvent event;

    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    /// Every relay answers the publish seed's read, and none holds a Kind 0,
    /// so a save composes from an empty seed.
    void stubRelaysHoldNoProfile() {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => nostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);
    }

    setUpAll(() {
      registerFallbackValue(Uri.parse(_testNameServer));
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(
        UserProfile(
          pubkey: pubkey,
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'eventId',
        ),
      );
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      httpClient = _MockHttpClient();
      userProfilesDao = _MockUserProfilesDao();
      db = AppDatabase.test(NativeDatabase.memory());
      slotDao = db.pendingProfileSavesDao;
      repository = ProfileRepository(
        nostrClient: nostrClient,
        userProfilesDao: userProfilesDao,
        httpClient: httpClient,
        pendingProfileSavesDao: slotDao,
        nameServerBaseUrl: _testNameServer,
      );

      event = _MockEvent();
      when(() => event.kind).thenReturn(0);
      when(() => event.pubkey).thenReturn(pubkey);
      when(() => event.createdAt).thenReturn(1704067200);
      when(() => event.id).thenReturn('e' * 64);
      when(() => event.content).thenReturn('{"display_name":"Alice"}');

      // The publish seed is resolved from the signing key when the caller
      // supplies no profile, so the client's pubkey is load-bearing here.
      when(() => nostrClient.publicKey).thenReturn(pubkey);

      // Nothing cached and nothing on relays → the seed resolves to null and
      // the publish composes from an empty map. These tests are about the
      // pending-save slot mechanics, not about seeding.
      when(
        () => userProfilesDao.getProfile(any()),
      ).thenAnswer((_) async => null);
      when(() => userProfilesDao.upsertProfile(any())).thenAnswer((_) async {});

      // Default: a confirmed publish.
      when(
        () => nostrClient.sendProfileAwaitOk(
          profileContent: any(named: 'profileContent'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: event));

      // Default claim wiring (overridden per-test as needed).
      when(
        () => nostrClient.createNip98AuthHeader(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => 'Nostr header');
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => Response('{}', 200));
    });

    tearDown(() => db.close());

    PendingProfileSave payload({String? username}) => PendingProfileSave(
      pubkey: pubkey,
      displayName: 'Alice',
      username: username,
    );

    Future<void> seedSlot({
      required bool claimConfirmed,
      String? username,
    }) {
      return slotDao.upsert(
        PendingProfileSaveEntry(
          userPubkey: pubkey,
          payloadJson: payload(username: username).encode(),
          claimConfirmed: claimConfirmed,
          queuedAt: DateTime.utc(2026, 7, 13),
        ),
      );
    }

    group('enqueuePendingSave', () {
      test('persists the payload + claimConfirmed to the slot', () async {
        await repository.enqueuePendingSave(
          payload(username: 'alice'),
          claimConfirmed: true,
        );

        final entry = await slotDao.get(pubkey);
        expect(entry, isNotNull);
        expect(entry!.claimConfirmed, isTrue);
        expect(entry.status, PendingProfileSaveStatus.pending);
        final decoded = PendingProfileSave.decode(entry.payloadJson);
        expect(decoded.username, 'alice');
        expect(decoded.displayName, 'Alice');
      });

      test('latest enqueue replaces the previous slot', () async {
        await repository.enqueuePendingSave(
          payload(username: 'old'),
          claimConfirmed: false,
        );
        await repository.enqueuePendingSave(
          payload(username: 'new'),
          claimConfirmed: true,
        );

        final entry = await slotDao.get(pubkey);
        expect(PendingProfileSave.decode(entry!.payloadJson).username, 'new');
        expect(entry.claimConfirmed, isTrue);
      });
    });

    group('drivePendingSave', () {
      setUp(stubRelaysHoldNoProfile);

      test('returns noPendingSave when the slot is empty', () async {
        expect(
          await repository.drivePendingSave(pubkey),
          PendingSaveDriveOutcome.noPendingSave,
        );
      });

      test(
        'confirmed even when the profile cache write fails (G3) — the '
        'first (only) upsert throws yet the slot still clears',
        () async {
          // The single post-publish cache write inside saveProfileEvent throws.
          // A relay already confirmed the kind-0, so the drive must still
          // report confirmed and clear the slot — a cache hiccup can never
          // strand a landed publish into an endless re-publish (#3161 review).
          when(() => userProfilesDao.upsertProfile(any())).thenAnswer((
            _,
          ) async {
            throw Exception('cache boom');
          });
          await seedSlot(claimConfirmed: true);

          final outcome = await repository.drivePendingSave(pubkey);

          expect(outcome, PendingSaveDriveOutcome.confirmed);
          expect(await slotDao.get(pubkey), isNull);
        },
      );

      test(
        'a newer save enqueued mid-publish is not cleared by the older drive '
        'and is driven on its own (generation guard)',
        () async {
          // Gate A's publish so a newer save B can slip in while A awaits the
          // relay round-trip.
          final publishGate = Completer<PublishResult>();
          when(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) => publishGate.future);

          final genA = await repository.enqueuePendingSave(
            payload(),
            claimConfirmed: true,
          );

          // Start driving A; it parks on the gated publish.
          final driveA = repository.drivePendingSave(
            pubkey,
            expectedGeneration: genA,
          );
          await pumpEventQueue();

          // B replaces the row while A is mid-publish.
          final genB = await repository.enqueuePendingSave(
            payload(username: 'bob'),
            claimConfirmed: true,
          );
          expect(genB, isNot(genA));

          // A's publish confirms — its generation-guarded clear must miss B.
          publishGate.complete(PublishSuccess(event: event));
          expect(await driveA, PendingSaveDriveOutcome.confirmed);

          final surviving = await slotDao.get(pubkey);
          expect(surviving, isNotNull, reason: 'B must not be cleared by A');
          expect(surviving!.generation, genB);
          expect(
            PendingProfileSave.decode(surviving.payloadJson).username,
            'bob',
          );

          // B is still deliverable on its own.
          final driveB = await repository.drivePendingSave(pubkey);
          expect(driveB, PendingSaveDriveOutcome.confirmed);
          expect(await slotDao.get(pubkey), isNull);
        },
      );

      test(
        'a superseded expectedGeneration bails without touching the newer row',
        () async {
          final genA = await repository.enqueuePendingSave(
            payload(),
            claimConfirmed: true,
          );
          await repository.enqueuePendingSave(
            payload(username: 'bob'),
            claimConfirmed: true,
          );

          final outcome = await repository.drivePendingSave(
            pubkey,
            expectedGeneration: genA,
          );

          expect(outcome, PendingSaveDriveOutcome.noPendingSave);
          expect(await slotDao.get(pubkey), isNotNull);
          verifyNever(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          );
        },
      );

      test(
        'confirmed publish clears the slot (claim already confirmed)',
        () async {
          await seedSlot(claimConfirmed: true);

          final outcome = await repository.drivePendingSave(pubkey);

          expect(outcome, PendingSaveDriveOutcome.confirmed);
          expect(await slotDao.get(pubkey), isNull);
          // Claim endpoint is never hit when already confirmed.
          verifyNever(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          );
        },
      );

      test(
        'claims first when not yet confirmed, then publishes + clears',
        () async {
          await seedSlot(claimConfirmed: false, username: 'alice');

          final outcome = await repository.drivePendingSave(pubkey);

          expect(outcome, PendingSaveDriveOutcome.confirmed);
          expect(await slotDao.get(pubkey), isNull);
          verify(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).called(1);
        },
      );

      test(
        'permanentFailure when the claim is taken — publish not attempted',
        () async {
          when(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => Response('{"error":"taken"}', 409));

          await seedSlot(claimConfirmed: false, username: 'alice');

          final outcome = await repository.drivePendingSave(pubkey);

          expect(outcome, PendingSaveDriveOutcome.permanentFailure);
          expect(await slotDao.get(pubkey), isNotNull); // slot kept
          verifyNever(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          );
        },
      );

      test('retryableFailure on no connected relays — slot kept', () async {
        when(
          () => nostrClient.sendProfileAwaitOk(
            profileContent: any(named: 'profileContent'),
          ),
        ).thenAnswer((_) async => const PublishNoRelays());

        await seedSlot(claimConfirmed: true);

        final outcome = await repository.drivePendingSave(pubkey);

        expect(outcome, PendingSaveDriveOutcome.retryableFailure);
        expect(await slotDao.get(pubkey), isNotNull);
      });

      test(
        'retryableFailure when relays reject the publish — slot kept',
        () async {
          when(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => const PublishFailed());

          await seedSlot(claimConfirmed: true);

          expect(
            await repository.drivePendingSave(pubkey),
            PendingSaveDriveOutcome.retryableFailure,
          );
          expect(await slotDao.get(pubkey), isNotNull);
        },
      );

      test('permanentFailure when the claim is reserved', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('{"error":"reserved"}', 403));

        await seedSlot(claimConfirmed: false, username: 'alice');

        expect(
          await repository.drivePendingSave(pubkey),
          PendingSaveDriveOutcome.permanentFailure,
        );
      });

      test(
        'permanentFailure when a queued username has an invalid format',
        () async {
          await seedSlot(claimConfirmed: false, username: 'alice_example');

          expect(
            await repository.drivePendingSave(pubkey),
            PendingSaveDriveOutcome.permanentFailure,
          );
          expect(await slotDao.get(pubkey), isNotNull);
          verifyNever(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          );
          verifyNever(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          );
        },
      );

      test(
        'retryableFailure when the claim hits a network error — slot kept',
        () async {
          when(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenThrow(Exception('offline'));

          await seedSlot(claimConfirmed: false, username: 'alice');

          expect(
            await repository.drivePendingSave(pubkey),
            PendingSaveDriveOutcome.retryableFailure,
          );
          expect(await slotDao.get(pubkey), isNotNull);
          verifyNever(
            () => nostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          );
        },
      );

      test(
        'retryableFailure when the claim returns a 4xx error — slot kept',
        () async {
          when(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => Response('{"error":"bad format"}', 400));

          await seedSlot(claimConfirmed: false, username: 'alice');

          expect(
            await repository.drivePendingSave(pubkey),
            PendingSaveDriveOutcome.retryableFailure,
          );
          expect(await slotDao.get(pubkey), isNotNull);
        },
      );
    });

    group('watchPendingSave (dao wired)', () {
      test('emits the queued slot', () async {
        await seedSlot(claimConfirmed: true);
        expect(
          repository.watchPendingSave(pubkey),
          emits(isA<PendingProfileSaveEntry>()),
        );
      });
    });

    group('no pending-save dao wired (queue methods are safe no-ops)', () {
      late ProfileRepository repoNoSlot;

      setUp(() {
        repoNoSlot = ProfileRepository(
          nostrClient: nostrClient,
          userProfilesDao: userProfilesDao,
          httpClient: httpClient,
        );
      });

      test('enqueue / clear / reset are no-ops and get returns null', () async {
        await repoNoSlot.enqueuePendingSave(
          payload(username: 'alice'),
          claimConfirmed: true,
        );
        await repoNoSlot.clearPendingSave(pubkey);
        await repoNoSlot.resetInterruptedPendingSave(pubkey);
        expect(await repoNoSlot.getPendingSave(pubkey), isNull);
      });

      test('watchPendingSave emits nothing', () async {
        expect(repoNoSlot.watchPendingSave(pubkey), emitsDone);
      });

      test('drivePendingSave returns noPendingSave', () async {
        expect(
          await repoNoSlot.drivePendingSave(pubkey),
          PendingSaveDriveOutcome.noPendingSave,
        );
      });
    });
  });
}
