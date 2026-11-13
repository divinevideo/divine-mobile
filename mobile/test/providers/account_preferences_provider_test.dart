import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Session extends NostrSession {
  _Session(this.initial);
  final NostrSessionReadiness initial;
  @override
  NostrSessionReadiness build() => initial;
}

class _HeldDatabase extends AppDatabase {
  _HeldDatabase() : super.test(NativeDatabase.memory());

  late final _HeldAccountSyncDao _heldAccountSyncDao = _HeldAccountSyncDao(
    this,
  );

  @override
  _HeldAccountSyncDao get accountSyncDao => _heldAccountSyncDao;
}

class _HeldAccountSyncDao extends AccountSyncDao {
  _HeldAccountSyncDao(super.attachedDatabase);

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> writeState(
    String owner,
    String namespace,
    Map<String, Map<String, String>> sections,
  ) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await super.writeState(owner, namespace, sections);
  }
}

class _HeldRestoreDatabase extends AppDatabase {
  _HeldRestoreDatabase() : super.test(NativeDatabase.memory());

  late final _HeldRestoreDao _heldAccountSyncDao = _HeldRestoreDao(this);

  @override
  _HeldRestoreDao get accountSyncDao => _heldAccountSyncDao;
}

/// Holds the first durable-state read, which is the repository's restore.
class _HeldRestoreDao extends AccountSyncDao {
  _HeldRestoreDao(super.attachedDatabase);

  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<AccountSyncRecord>> readState(
    String owner,
    String namespace,
  ) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.readState(owner, namespace);
  }
}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

/// A client whose session [isReadyForActiveClient] accepts for [owner].
_Client _readyClient(NostrSigner signer, String owner) {
  final client = _Client();
  when(() => client.signer).thenReturn(signer);
  when(() => client.hasKeys).thenReturn(true);
  when(() => client.publicKey).thenReturn(owner);
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Event('0'.padLeft(64, '0'), 1, [], ''));
  });

  group('account preference provider lifecycle', () {
    test(
      'identity-known edits survive readiness; signed-out bridge quarantines old projection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final client = _Client();
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        final pubkey = (await signer.getPublicKey())!;
        final events = StreamController<Event>.broadcast();
        final statuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        when(() => client.signer).thenReturn(signer);
        when(() => client.hasKeys).thenReturn(true);
        when(() => client.publicKey).thenReturn(pubkey);
        when(() => client.subscribe(any())).thenAnswer((_) => events.stream);
        when(() => client.relayStatusStream).thenAnswer((_) => statuses.stream);
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: true),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            nostrServiceProvider.overrideWithValue(client),
            nostrSessionProvider.overrideWith(
              () =>
                  _Session(NostrSessionReadiness.identityKnown(pubkey: pubkey)),
            ),
          ],
        );
        final binding = container.listen(
          accountPreferenceSyncProvider,
          (_, _) {},
        );
        final language = container.read(languagePreferenceServiceProvider);
        final versions = <int>[];
        final version = container.listen(
          languagePreferenceVersionProvider,
          (_, next) => versions.add(next),
        );
        await pumpEventQueue();
        final before = container.read(accountPreferenceSyncProvider);
        await language.setContentLanguage('ja');
        expect(before!.value('content_language'), 'ja');
        verifyNever(() => client.subscribe(any()));
        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
            );
        await pumpEventQueue();
        expect(
          identical(container.read(accountPreferenceSyncProvider), before),
          isTrue,
        );
        expect(language.declaredContentLanguage, 'ja');
        verify(() => client.subscribe(any())).called(1);
        container
            .read(nostrSessionProvider.notifier)
            .update(const NostrSessionReadiness.signedOut());
        await pumpEventQueue();
        expect(container.read(accountPreferenceSyncProvider), isNull);
        expect(language.declaredContentLanguage, isNull);
        expect(versions, isNotEmpty);
        version.close();
        binding.close();
        container.dispose();
        await events.close();
        await statuses.close();
      },
    );

    for (final disposeFirst in [false, true]) {
      test(
        'forget drains local writes with provider disposed: $disposeFirst',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final signer = LocalNostrSigner('1'.padLeft(64, '0'));
          final owner = (await signer.getPublicKey())!;
          final key = 'account_state_divine/preferences/v1_${owner}_state';
          await prefs.setString(key, '{}');
          final database = _HeldDatabase();
          final client = _Client();
          when(() => client.signer).thenReturn(signer);
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              databaseProvider.overrideWithValue(database),
              nostrServiceProvider.overrideWithValue(client),
              nostrSessionProvider.overrideWith(
                () => _Session(
                  NostrSessionReadiness.identityKnown(pubkey: owner),
                ),
              ),
            ],
          );
          final binding = container.listen(accountDmStateProvider, (_, _) {});
          final repository = binding.read()!;
          Future<void>? cleanup;
          addTearDown(() async {
            if (!database.accountSyncDao.release.isCompleted) {
              database.accountSyncDao.release.complete();
            }
            await cleanup;
            binding.close();
            container.dispose();
            await repository.close();
            await database.close();
          });
          await database.accountSyncDao.entered.future;
          if (disposeFirst) {
            container
                .read(nostrSessionProvider.notifier)
                .update(
                  NostrSessionReadiness.tearingDown(pubkey: owner),
                );
            await container.pump();
            expect(container.read(accountDmStateProvider), isNull);
          }
          var databaseErased = false;
          final service = container.read(userDataCleanupServiceProvider);
          service.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
                bool forgetAccount = false,
              }) async {
                databaseErased = true;
                await database.accountSyncDao.clearAccount(userPubkey!);
              };
          cleanup = service
              .clearUserSpecificData(
                userPubkey: owner,
                forgetAccount: true,
              )
              .then((_) {});
          await pumpEventQueue();
          expect(databaseErased, isFalse);
          expect(prefs.containsKey(key), isTrue);
          database.accountSyncDao.release.complete();
          await cleanup;
          expect(databaseErased, isTrue);
          expect(prefs.containsKey(key), isFalse);
          expect(
            await database.accountSyncDao.readState(
              owner,
              'divine/dm-dismissals/v1',
            ),
            isEmpty,
          );
        },
      );
    }

    test(
      'initial signed-out state never exposes prior account language',
      () async {
        SharedPreferences.setMockInitialValues({'content_language': 'es'});
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            nostrSessionProvider.overrideWith(
              () => _Session(const NostrSessionReadiness.signedOut()),
            ),
          ],
        );
        final binding = container.listen(
          accountPreferenceSyncProvider,
          (_, _) {},
        );
        final language = container.read(languagePreferenceServiceProvider);
        await language.initialize();
        expect(language.declaredContentLanguage, isNull);
        binding.close();
        container.dispose();
      },
    );

    group('when a ready account repository is closed', () {
      late CrashReporter originalReporter;
      late _RecordingCrashReporter reporter;

      setUp(() {
        originalReporter = detachedFailureReporter;
        addTearDown(() => detachedFailureReporter = originalReporter);
        reporter = _RecordingCrashReporter();
        detachedFailureReporter = reporter;
      });

      test(
        'preference sync never starts a repository the barrier closed while '
        'it was binding',
        () async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final signer = LocalNostrSigner('1'.padLeft(64, '0'));
          final owner = (await signer.getPublicKey())!;
          final client = _readyClient(signer, owner);
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              nostrServiceProvider.overrideWithValue(client),
              nostrSessionProvider.overrideWith(
                () => _Session(
                  NostrSessionReadiness.nostrReady(
                    pubkey: owner,
                    client: client,
                  ),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final binding = container.listen(
            accountPreferenceSyncProvider,
            (_, _) {},
          );
          addTearDown(binding.close);
          expect(binding.read(), isNotNull);

          // Account erasure drains the owner's writers before its identity
          // clears, so this provider and its ready session outlive the close.
          await container.read(accountStateWriteBarrierProvider).stop(owner);
          await pumpEventQueue();

          expect(reporter.recordedErrors, isEmpty);
          verifyNever(() => client.subscribe(any()));
        },
      );

      for (final (name, provider) in [
        ('preference sync', accountPreferenceSyncProvider),
        ('conversation state', accountDmStateProvider),
      ]) {
        test(
          '$name does not start when the session turns ready after account '
          'erasure closed it',
          () async {
            SharedPreferences.setMockInitialValues({});
            final preferences = await SharedPreferences.getInstance();
            final database = AppDatabase.test(NativeDatabase.memory());
            addTearDown(database.close);
            final signer = LocalNostrSigner('1'.padLeft(64, '0'));
            final owner = (await signer.getPublicKey())!;
            final client = _readyClient(signer, owner);
            final container = ProviderContainer(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(preferences),
                databaseProvider.overrideWithValue(database),
                nostrServiceProvider.overrideWithValue(client),
                nostrSessionProvider.overrideWith(
                  () => _Session(
                    NostrSessionReadiness.identityKnown(pubkey: owner),
                  ),
                ),
              ],
            );
            addTearDown(container.dispose);
            final binding = container.listen(provider, (_, _) {});
            addTearDown(binding.close);
            await pumpEventQueue();

            // Erasure can begin before the relays connect; the identity is
            // still the owner's when the client then reports ready.
            await container.read(accountStateWriteBarrierProvider).stop(owner);
            container
                .read(nostrSessionProvider.notifier)
                .update(
                  NostrSessionReadiness.nostrReady(
                    pubkey: owner,
                    client: client,
                  ),
                );
            await pumpEventQueue();

            expect(binding.read(), isNotNull);
            expect(reporter.recordedErrors, isEmpty);
            verifyNever(() => client.subscribe(any()));
          },
        );
      }

      for (final closer in ['account erasure', 'session teardown']) {
        test(
          'conversation state start yields to $closer during its restore',
          () async {
            SharedPreferences.setMockInitialValues({});
            final preferences = await SharedPreferences.getInstance();
            final database = _HeldRestoreDatabase();
            addTearDown(database.close);
            final signer = LocalNostrSigner('1'.padLeft(64, '0'));
            final owner = (await signer.getPublicKey())!;
            final client = _readyClient(signer, owner);
            final container = ProviderContainer(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(preferences),
                databaseProvider.overrideWithValue(database),
                nostrServiceProvider.overrideWithValue(client),
                nostrSessionProvider.overrideWith(
                  () => _Session(
                    NostrSessionReadiness.nostrReady(
                      pubkey: owner,
                      client: client,
                    ),
                  ),
                ),
              ],
            );
            addTearDown(container.dispose);
            final binding = container.listen(accountDmStateProvider, (_, _) {});
            addTearDown(binding.close);
            // The ready session started sync, which now waits on the restore.
            await database.accountSyncDao.entered.future;

            var closing = Future<void>.value();
            if (closer == 'account erasure') {
              closing = container
                  .read(accountStateWriteBarrierProvider)
                  .stop(owner);
            } else {
              container
                  .read(nostrSessionProvider.notifier)
                  .update(NostrSessionReadiness.tearingDown(pubkey: owner));
              await container.pump();
              expect(container.read(accountDmStateProvider), isNull);
            }
            database.accountSyncDao.release.complete();
            await closing;
            await pumpEventQueue();

            expect(reporter.recordedErrors, isEmpty);
            verifyNever(() => client.subscribe(any()));
          },
        );
      }
    });
  });
}
