// ABOUTME: Tests for sound library reconciliation across devices.
// ABOUTME: Pins LWW, tombstone handling, and the resurrection guard.

import 'package:creator_sync/creator_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/signer/signer_failure.dart';
import 'package:test/test.dart';

class _MockIndexClient extends Mock implements SyncIndexClient {}

class _MockSigner extends Mock implements NostrSigner {}

class _MockNostrClient extends Mock implements NostrClient {}

/// A remote signer that bounded itself and gave up, like Keycast's
/// `RpcTimeoutException`.
class _SignerGaveUp implements TransientSignerFailure, Exception {}

class _FakeLocalSoundStore implements LocalSoundStore {
  final Map<String, Map<String, dynamic>> sounds = {};

  /// Set to simulate a library this build cannot decode.
  bool unreadable = false;

  @override
  Future<Map<String, Map<String, dynamic>>> readAll() async {
    if (unreadable) {
      throw LocalStoreUnreadableException('unreadable');
    }
    return Map<String, Map<String, dynamic>>.from(sounds);
  }

  @override
  Future<void> upsert(String id, Map<String, dynamic> body) async {
    sounds[id] = body;
  }

  @override
  Future<void> remove(String id) async => sounds.remove(id);
}

void main() {
  group(SoundSyncRepository, () {
    const idA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const idB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    late _MockIndexClient index;
    late InMemorySyncStateStore state;
    late _FakeLocalSoundStore local;
    late SoundSyncRepository repository;

    setUpAll(() {
      registerFallbackValue(const SyncItemRef(SyncItemKind.sound, 'x'));
      registerFallbackValue(SyncIndexEntry.tombstone());
    });

    setUp(() {
      index = _MockIndexClient();
      state = InMemorySyncStateStore();
      local = _FakeLocalSoundStore();
      repository = SoundSyncRepository(
        index: index,
        state: state,
        local: local,
      );
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer((_) async => []);
      when(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).thenAnswer((_) async => 9999);
    });

    RemoteSyncRecord record(
      String id,
      int createdAt, {
      Map<String, dynamic>? body,
    }) => RemoteSyncRecord(
      ref: SyncItemRef(SyncItemKind.sound, id),
      entry: body == null
          ? SyncIndexEntry.tombstone()
          : SyncIndexEntry.item(body: body),
      createdAt: createdAt,
    );

    test('pulls a remote sound absent locally', () async {
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer(
        (_) async => [
          record(idA, 1000, body: {'label': 'intro'}),
        ],
      );

      final outcome = await repository.reconcile();

      expect(local.sounds[idA], equals({'label': 'intro'}));
      expect(outcome.pulled, equals(1));
      // A pulled item must be recorded with a hash of its own body, not a
      // tombstone hash — otherwise the push loop below would immediately
      // see it as unpublished and echo it straight back to the relay.
      verifyNever(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      );
    });

    test(
      'records the created_at of a pulled item, not a placeholder',
      () async {
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer(
          (_) async => [
            record(idA, 7777, body: {'label': 'intro'}),
          ],
        );

        await repository.reconcile();

        expect(
          (await state.readApplied(
            SyncItemKind.sound,
          ))['divine:sync:sound:$idA']!.createdAt,
          equals(7777),
        );
      },
    );

    test('pushes a local sound never published', () async {
      local.sounds[idB] = {'label': 'outro'};

      final outcome = await repository.reconcile();

      final captured = verify(
        () => index.publish(
          captureAny(),
          captureAny(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).captured;
      expect((captured[0] as SyncItemRef).id, equals(idB));
      expect((captured[1] as SyncIndexEntry).body, equals({'label': 'outro'}));
      expect(outcome.pushed, equals(1));
    });

    test(
      'passes null latestKnownRemote for a sound with no prior applied '
      'entry',
      () async {
        local.sounds[idB] = {'label': 'outro'};

        await repository.reconcile();

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );

    test(
      'passes the prior per-item created_at as latestKnownRemote when '
      'republishing an edit',
      () async {
        local.sounds[idA] = {'label': 'edited offline'};
        await state.writeApplied(SyncItemKind.sound, {
          'divine:sync:sound:$idA': SyncItemState(
            createdAt: 1500,
            bodyHash: syncBodyHash(const {'label': 'stale published body'}),
          ),
        });

        await repository.reconcile();

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, equals(1500));
      },
    );

    test('applies a newer remote edit over the local copy', () async {
      local.sounds[idA] = {'label': 'old'};
      await state.writeApplied(SyncItemKind.sound, {
        'divine:sync:sound:$idA': SyncItemState(
          createdAt: 1000,
          bodyHash: syncBodyHash(const {'label': 'old'}),
        ),
      });
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer(
        (_) async => [
          record(idA, 2000, body: {'label': 'new'}),
        ],
      );

      await repository.reconcile();

      expect(local.sounds[idA], equals({'label': 'new'}));
      // The applied hash for a pulled edit must be its own body's hash —
      // a wrong hash (e.g. a tombstone hash) would make the push loop
      // below immediately echo this same record back to the relay.
      verifyNever(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      );
    });

    test('ignores a remote record it has already applied', () async {
      local.sounds[idA] = {'label': 'current'};
      await state.writeApplied(SyncItemKind.sound, {
        'divine:sync:sound:$idA': SyncItemState(
          createdAt: 2000,
          bodyHash: syncBodyHash(const {'label': 'current'}),
        ),
      });
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer(
        (_) async => [
          record(idA, 2000, body: {'label': 'echo'}),
        ],
      );

      await repository.reconcile();

      expect(local.sounds[idA], equals({'label': 'current'}));
      verifyNever(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      );
    });

    test('records the created_at the publish actually stamped', () async {
      local.sounds[idB] = {'label': 'outro'};
      when(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).thenAnswer((_) async => 4_242_424_242);

      await repository.reconcile();

      expect(
        (await state.readApplied(
          SyncItemKind.sound,
        ))['divine:sync:sound:$idB']!.createdAt,
        equals(4_242_424_242),
      );
    });

    test('republishes a local edit whose earlier publish failed', () async {
      // Body drifted from what was last published: the edit never landed.
      local.sounds[idA] = {'label': 'edited offline'};
      await state.writeApplied(SyncItemKind.sound, {
        'divine:sync:sound:$idA': SyncItemState(
          createdAt: 1000,
          bodyHash: syncBodyHash(const {'label': 'stale published body'}),
        ),
      });

      final outcome = await repository.reconcile();

      final captured = verify(
        () => index.publish(
          any(),
          captureAny(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).captured;
      expect(
        (captured.single as SyncIndexEntry).body,
        equals({'label': 'edited offline'}),
      );
      expect(outcome.pushed, equals(1));
    });

    test('does not republish when the local body already matches', () async {
      local.sounds[idA] = {'label': 'in sync'};
      await state.writeApplied(SyncItemKind.sound, {
        'divine:sync:sound:$idA': SyncItemState(
          createdAt: 1000,
          bodyHash: syncBodyHash(const {'label': 'in sync'}),
        ),
      });

      final outcome = await repository.reconcile();

      verifyNever(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      );
      expect(outcome.pushed, equals(0));
    });

    test('removes a locally-present sound on a remote tombstone', () async {
      local.sounds[idA] = {'label': 'doomed'};
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer((_) async => [record(idA, 3000)]);

      final outcome = await repository.reconcile();

      expect(local.sounds.containsKey(idA), isFalse);
      expect(outcome.deleted, equals(1));
    });

    test('does not resurrect a sound deleted on another device', () async {
      local.sounds[idA] = {'label': 'doomed'};
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer((_) async => [record(idA, 3000)]);

      await repository.reconcile();
      // Second pass: the tombstone is already applied and the local copy
      // is gone, so nothing should be republished.
      when(
        () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
      ).thenAnswer((_) async => []);
      await repository.reconcile();

      verifyNever(
        () => index.publish(
          any(),
          any(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      );
    });

    test(
      'republishes a tombstone for a sound whose earlier delete never '
      'landed, and does not repeat it on a later pass',
      () async {
        // The sound is already gone locally — as it would be after a
        // failed publishLocalDeletion — but `applied` still carries the
        // real body hash from when it was last successfully synced.
        await state.writeApplied(SyncItemKind.sound, {
          'divine:sync:sound:$idA': SyncItemState(
            createdAt: 1000,
            bodyHash: syncBodyHash(const {'label': 'doomed'}),
          ),
        });

        final outcome = await repository.reconcile();

        final captured = verify(
          () => index.publish(
            captureAny(),
            captureAny(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect((captured[0] as SyncItemRef).id, equals(idA));
        expect((captured[1] as SyncIndexEntry).deleted, isTrue);
        expect(captured[2], equals(1000));
        expect(outcome.deletionsRetried, equals(1));
        expect(
          (await state.readApplied(
            SyncItemKind.sound,
          ))['divine:sync:sound:$idA']!.bodyHash,
          equals(SyncItemState.tombstoneHash),
        );

        // Second pass: the retry landed, so nothing should republish. The
        // first pass's publish call above was already consumed by the
        // `verify(...).captured` call, so any further matching call here
        // would be a fresh, unverified interaction — exactly what
        // `verifyNever` catches.
        await repository.reconcile();

        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      },
    );

    test(
      'does not retry a delete for a sound tombstoned by a remote record '
      'this same pass',
      () async {
        local.sounds[idA] = {'label': 'doomed'};
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer((_) async => [record(idA, 3000)]);

        final outcome = await repository.reconcile();

        expect(outcome.deletionsRetried, equals(0));
        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      },
    );

    test(
      'does not retry a delete for a sound pulled from remote this same '
      'pass',
      () async {
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer(
          (_) async => [
            record(idA, 1000, body: {'label': 'intro'}),
          ],
        );

        final outcome = await repository.reconcile();

        expect(outcome.pulled, equals(1));
        expect(outcome.deletionsRetried, equals(0));
        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      },
    );

    test(
      'aborts rather than tombstoning a library it could not read',
      () async {
        // Seed applied state for two synced sounds, then make the local
        // library unreadable. Reading that as an empty library makes both
        // look user-deleted, and the delete-retry loop publishes a
        // tombstone for each — which every other device then applies.
        local.sounds[idA] = {'label': 'intro'};
        local.sounds[idB] = {'label': 'outro'};
        await repository.reconcile();
        clearInteractions(index);

        local.unreadable = true;

        await expectLater(
          repository.reconcile(),
          throwsA(isA<LocalStoreUnreadableException>()),
        );
        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      },
    );

    test(
      'still tombstones a sound the user genuinely deleted',
      () async {
        // The counterpart to the test above: an empty-but-readable library
        // must keep retrying the deletion the push loop can never see.
        local.sounds[idA] = {'label': 'intro'};
        await repository.reconcile();
        clearInteractions(index);

        local.sounds.remove(idA);

        final outcome = await repository.reconcile();

        expect(outcome.deletionsRetried, equals(1));
      },
    );

    test(
      're-adding a tombstoned sound survives a repeated tombstone fetch',
      () async {
        local.sounds[idA] = {'label': 'doomed'};
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer((_) async => [record(idA, 3000)]);

        await repository.reconcile();
        expect(local.sounds.containsKey(idA), isFalse);

        // The user re-adds the sound locally. Production never passes
        // `since`, so the relay keeps returning the same tombstone.
        local.sounds[idA] = {'label': 'reborn'};

        final outcome = await repository.reconcile();

        expect(local.sounds[idA], equals({'label': 'reborn'}));
        final captured = verify(
          () => index.publish(
            any(),
            captureAny(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(
          (captured.single as SyncIndexEntry).body,
          equals({'label': 'reborn'}),
        );
        expect(outcome.pushed, equals(1));
      },
    );

    test(
      'persists pull progress across a publish failure so a later local '
      'edit is not overwritten by the relay echo',
      () async {
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer(
          (_) async => [
            record(idA, 2000, body: {'label': 'from relay'}),
          ],
        );
        local.sounds[idB] = {'label': 'outro'};
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenThrow(SyncIndexException('relay down'));

        await expectLater(
          repository.reconcile(),
          throwsA(isA<SyncIndexException>()),
        );
        expect(local.sounds[idA], equals({'label': 'from relay'}));

        // The user edits the pulled sound locally.
        local.sounds[idA] = {'label': 'my edit'};

        // Second pass: the relay still has the same record for A (fetch
        // is never called with `since`), but publishing now succeeds.
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenAnswer((_) async => 9999);

        await repository.reconcile();

        expect(local.sounds[idA], equals({'label': 'my edit'}));
      },
    );

    test('publishLocalChange publishes an item entry', () async {
      local.sounds[idA] = {'label': 'fresh'};

      await repository.publishLocalChange(idA);

      final captured = verify(
        () => index.publish(
          captureAny(),
          captureAny(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).captured;
      expect((captured[1] as SyncIndexEntry).deleted, isFalse);
    });

    test(
      'publishLocalChange passes null latestKnownRemote for a sound with '
      'no prior applied entry',
      () async {
        local.sounds[idA] = {'label': 'fresh'};

        await repository.publishLocalChange(idA);

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );

    test(
      'publishLocalChange passes the prior per-item created_at as '
      'latestKnownRemote when republishing an edit',
      () async {
        local.sounds[idA] = {'label': 'edited offline'};
        await state.writeApplied(SyncItemKind.sound, {
          'divine:sync:sound:$idA': SyncItemState(
            createdAt: 1500,
            bodyHash: syncBodyHash(const {'label': 'stale published body'}),
          ),
        });

        await repository.publishLocalChange(idA);

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, equals(1500));
      },
    );

    test(
      'publishLocalChange is a no-op when the sound is not stored locally',
      () async {
        await repository.publishLocalChange(idA);

        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      },
    );

    test('publishLocalDeletion publishes a tombstone', () async {
      await repository.publishLocalDeletion(idA);

      final captured = verify(
        () => index.publish(
          captureAny(),
          captureAny(),
          latestKnownRemote: any(named: 'latestKnownRemote'),
        ),
      ).captured;
      expect((captured[1] as SyncIndexEntry).deleted, isTrue);
    });

    test(
      'publishLocalDeletion passes null latestKnownRemote for a sound '
      'with no prior applied entry',
      () async {
        await repository.publishLocalDeletion(idA);

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );

    test(
      'publishLocalDeletion passes the prior per-item created_at as '
      'latestKnownRemote when the item was previously applied',
      () async {
        await state.writeApplied(SyncItemKind.sound, {
          'divine:sync:sound:$idA': SyncItemState(
            createdAt: 2500,
            bodyHash: syncBodyHash(const {'label': 'old'}),
          ),
        });

        await repository.publishLocalDeletion(idA);

        final captured = verify(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: captureAny(named: 'latestKnownRemote'),
          ),
        ).captured;
        expect(captured.single, equals(2500));
      },
    );

    test(
      'does not report a relay failure to the crash reporter (reconcile)',
      () async {
        final sites = <String>[];
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenThrow(SyncIndexException('relay down'));

        await expectLater(
          repository.reconcile(),
          throwsA(isA<SyncIndexException>()),
        );
        // Network/relay failures are expected on flaky connections and
        // must not flood Crashlytics — see error_handling.md.
        expect(sites, isEmpty);
      },
    );

    test(
      'reports a non-relay failure through the reporter port (reconcile)',
      () async {
        final sites = <String>[];
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenThrow(StateError('unexpected'));

        await expectLater(repository.reconcile(), throwsA(isA<StateError>()));
        expect(sites, equals([CreatorSyncReportableSites.reconcileSounds]));
      },
    );

    test(
      'does not report a relay failure to the crash reporter '
      '(publishLocalChange)',
      () async {
        final sites = <String>[];
        local.sounds[idA] = {'label': 'fresh'};
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenThrow(SyncIndexException('relay down'));

        await expectLater(
          repository.publishLocalChange(idA),
          throwsA(isA<SyncIndexException>()),
        );
        expect(sites, isEmpty);
      },
    );

    test(
      'reports a non-relay failure through the reporter port '
      '(publishLocalChange)',
      () async {
        final sites = <String>[];
        local.sounds[idA] = {'label': 'fresh'};
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenThrow(StateError('unexpected'));

        await expectLater(
          repository.publishLocalChange(idA),
          throwsA(isA<StateError>()),
        );
        expect(
          sites,
          equals([CreatorSyncReportableSites.publishSoundChange]),
        );
      },
    );

    test(
      'does not report a relay failure to the crash reporter '
      '(publishLocalDeletion)',
      () async {
        final sites = <String>[];
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenThrow(SyncIndexException('relay down'));

        await expectLater(
          repository.publishLocalDeletion(idA),
          throwsA(isA<SyncIndexException>()),
        );
        expect(sites, isEmpty);
      },
    );

    test(
      'reports a non-relay failure through the reporter port '
      '(publishLocalDeletion)',
      () async {
        final sites = <String>[];
        repository = SoundSyncRepository(
          index: index,
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );
        when(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        ).thenThrow(StateError('unexpected'));

        await expectLater(
          repository.publishLocalDeletion(idA),
          throwsA(isA<StateError>()),
        );
        expect(
          sites,
          equals([CreatorSyncReportableSites.publishSoundDeletion]),
        );
      },
    );

    test(
      'does not report a remote signer that gave up while publishing a '
      'change, and records nothing so the next reconcile retries',
      () async {
        const pubkey =
            'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
        registerFallbackValue(Event(pubkey, 30078, const [], ''));
        final signer = _MockSigner();
        when(signer.getPublicKey).thenAnswer((_) async => pubkey);
        when(
          () => signer.signEvent(any()),
        ).thenAnswer((_) async => throw _SignerGaveUp());
        final nostrClient = _MockNostrClient();
        final sites = <String>[];
        local.sounds[idA] = {'label': 'fresh'};
        repository = SoundSyncRepository(
          index: SyncIndexClient(
            client: nostrClient,
            signer: signer,
            cipher: SyncCipher(await AesGcm.with256bits().newSecretKey()),
          ),
          state: state,
          local: local,
          errorReporter: (_, _, {required site}) => sites.add(site),
        );

        await expectLater(
          repository.publishLocalChange(idA),
          throwsA(isA<SyncIndexException>()),
        );
        expect(sites, isEmpty);
        expect(await state.readApplied(SyncItemKind.sound), isEmpty);
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      },
    );
  });
}
