// ABOUTME: Fences fresh list sessions across incomplete account cleanup.
// ABOUTME: Preserves list data, deletion intent and continuing-session leases.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/curated_list_publish_stubs.dart';
import '../test_setup.dart';

class _OldAuth extends Mock implements AuthService {}

class _Relay extends Mock implements NostrClient {}

class _ArchiveAuth implements AuthService {
  final calls = <String>[];
  @override
  Future<void> archiveCurrentSignerInfo() async {
    calls.add('archive');
  }

  @override
  Future<void> restoreSignerInfoForCurrentAccount() async {
    calls.add('restore');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Keys extends SecureKeyStorage {
  _Keys(this.target, this.primary);
  final SecureKeyContainer target;
  SecureKeyContainer? primary;
  SecureKeyContainer? restored;
  @override
  Future<void> initialize() async {}
  @override
  Future<SecureKeyContainer?> getIdentityKeyContainer(String npub) async =>
      target;
  @override
  Future<bool> switchToIdentity(String npub) async {
    primary = target;
    return true;
  }

  @override
  Future<SecureKeyContainer?> getKeyContainer() async => primary;
  @override
  Future<void> restorePrimaryKeyContainer(SecureKeyContainer? value) async {
    restored = value;
    primary = value;
  }

  @override
  void dispose() {}
}

class _OldKey implements SecureKeyContainer {
  @override
  String get npub => NostrKeyUtils.encodePubKey(publicKeyHex);
  @override
  final String publicKeyHex =
      '2222222222222222222222222222222222222222222222222222222222222222';
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadbackBackend extends InMemorySharedPreferencesStore {
  _ReadbackBackend() : super.withData({});
  bool refuseRead = false;
  @override
  Future<Map<String, Object>> getAll() async {
    if (refuseRead) throw StateError('Synthetic durable readback unavailable');
    return super.getAll();
  }
}

void main() {
  setupTestEnvironment();
  const owner =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const video =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const eventId =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  setUpAll(() => registerFallbackValue(<nostr.Filter>[]));
  group('failed account switch', () {
    for (final deleted in [false, true]) {
      testWidgets(
        deleted
            ? 'real failed account switch preserves owner My List deletion tombstone'
            : 'real failed account switch preserves populated relay My List',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'current_user_pubkey_hex': owner,
          });
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.test(NativeDatabase.memory());
          addTearDown(db.close);
          final controller = AccountSwitchController();
          final oldAuth = _OldAuth();
          final archived = _ArchiveAuth();
          final client = _Relay();
          final oldKey = _OldKey();
          final target = SecureKeyContainer.fromPrivateKeyHex('1' * 64);
          final keys = _Keys(target, oldKey);
          final timeline = <String>[];
          final published = <Event>[];
          var relayVideoIds = <String>[video];
          final row = CuratedList(
            id: CuratedListService.defaultListId,
            pubkey: owner,
            name: 'Populated My List',
            isPublic: false,
            videoEventIds: const [video],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            nostrEventId: eventId,
          );
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode(deleted ? [] : [row.toJson()]),
          );
          if (deleted) {
            await prefs.setBool(
              CuratedListService.defaultListDeletedStorageKey,
              true,
            );
            await prefs.setStringList(
              PrefsCuratedListStore.deletedCoordinatesStorageKey,
              ['$owner:${CuratedListService.defaultListId}'],
            );
          }
          when(() => oldAuth.isAuthenticated).thenReturn(true);
          when(() => oldAuth.currentPublicKeyHex).thenReturn(owner);
          stubListPublishing(client: client, auth: oldAuth, pubkey: owner);
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            published.add(event);
            timeline.add('confirmed-publish');
            final plaintext = unsealForTest(event.content);
            final tags = plaintext == null
                ? event.tags
                : jsonDecode(plaintext) as List<dynamic>;
            relayVideoIds = tags
                .where((dynamic t) => t is List && t.isNotEmpty && t[0] == 'e')
                .map<String>((dynamic t) => t[1] as String)
                .toList();
            return acceptedOutcome(event);
          });
          when(() => client.subscribe(any())).thenAnswer((i) {
            timeline.add('relay-query');
            return const Stream<Event>.empty();
          });
          final cleanup = UserDataCleanupService(prefs);
          var sweepCount = 0;
          var sweepErasedLists = false;
          var sweepErasedDefaultFlag = false;
          cleanup.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
              }) async {
                sweepCount++;
                timeline.add(
                  'cleanup-database-refusal-after-shared-cache-sweep',
                );
                sweepErasedLists = !prefs.containsKey(
                  CuratedListService.listsStorageKey,
                );
                sweepErasedDefaultFlag = !prefs.containsKey(
                  CuratedListService.defaultListDeletedStorageKey,
                );
                expect(userPubkey, owner);
                expect(deleteUserData, isFalse);
                expect(sweepErasedLists, isTrue);
                expect(sweepErasedDefaultFlag, isTrue);
                throw const UserDataCleanupException(
                  'Synthetic database unavailable after cache sweep',
                );
              };
          var authCount = 0;
          var incomingDisposed = false;
          final scope = DeviceScope(
            database: db,
            sharedPreferences: prefs,
            feedModePersistence: FeedModePersistenceRegistry(
              sharedPreferences: prefs,
            ),
            switchController: controller,
            appVersion: 'external-diagnostic',
            documentsPath: '/documents',
            crashReporting: CrashReportingService(),
            startupPerformance: StartupPerformanceService(
              crashReporting: CrashReportingService(),
            ),
            logMessageBatcher: LogMessageBatcher(),
            accountOverrides: [
              secureKeyStorageProvider.overrideWithValue(keys),
              pushNotificationSyncProvider.overrideWithValue(null),
              nostrServiceProvider.overrideWithValue(client),
              authServiceProvider.overrideWith((ref) {
                if (authCount++ == 0) return oldAuth;
                final incoming = AuthService(
                  backgroundActivityManager: BackgroundActivityManager(),
                  userDataCleanupService: cleanup,
                  keyStorage: keys,
                  profileCheckIndexerUrl: 'unsupported://diagnostic.invalid',
                );
                ref.onDispose(() {
                  incomingDisposed = true;
                  unawaited(incoming.dispose());
                });
                return incoming;
              }),
            ],
          );
          final initial = buildAccountContainer(scope);
          await tester.pumpWidget(
            ContainerSwapHost(
              initialContainer: initial,
              controller: controller,
              child: const SizedBox(),
            ),
          );
          final listener = initial.listen(curatedListsStateProvider, (_, _) {});
          await initial.read(curatedListsStateProvider.future);
          final retired = initial
              .read(curatedListsStateProvider.notifier)
              .service!;
          await tester.pump();
          timeline.clear();
          published.clear();
          final account = KnownAccount(
            pubkeyHex: target.publicKeyHex,
            authSource: AuthenticationSource.automatic,
            addedAt: DateTime.utc(2026),
            lastUsedAt: DateTime.utc(2026),
          );
          await expectLater(
            swapAccount(
              deviceScope: scope,
              controller: controller,
              currentAuthService: archived,
              account: account,
            ),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(controller.currentContainer, same(initial));
          expect(keys.restored, same(oldKey));
          expect(incomingDisposed, isTrue);
          expect(archived.calls, ['archive', 'restore']);
          expect(sweepCount, 1);
          expect(retired.isCurrentSession, isFalse);
          final pending = PendingAccountCleanup.read(prefs);
          expect(pending, isNotNull);
          expect(pending!.userPubkey, owner);
          await expectLater(
            initial.read(curatedListsStateProvider.future),
            throwsA(isA<CuratedListAccountBoundaryException>()),
          );
          final rebuilt = initial
              .read(curatedListsStateProvider.notifier)
              .service!;
          expect(rebuilt, isNot(same(retired)));
          expect(rebuilt.isCurrentSession, isTrue);
          expect(rebuilt.isInitialized, isFalse);
          expect(rebuilt.isReadyForMutations, isFalse);
          expect(await rebuilt.createList(name: 'Must remain blocked'), isNull);
          expect(
            await rebuilt.subscribeToList('$owner:my_vine_list', row),
            isFalse,
          );
          expect(published, isEmpty);
          expect(timeline, [
            'cleanup-database-refusal-after-shared-cache-sweep',
          ]);
          await tester.pump();
          final tombstone =
              prefs.getStringList(
                PrefsCuratedListStore.deletedCoordinatesStorageKey,
              ) ??
              [];
          listener.close();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          if (deleted) {
            expect(
              tombstone,
              contains('$owner:${CuratedListService.defaultListId}'),
              reason: 'Failed account switch must not undo a confirmed owner deletion',
            );
          } else {
            expect(
              relayVideoIds,
              [video],
              reason: 'Failed account switch must not replace an existing populated addressable list with an empty list',
            );
          }
        },
      );
    }
  });

  group('fresh account cleanup initialization fence', () {
    Future<
      ({
        CuratedListService service,
        _Relay client,
        _OldAuth auth,
        SharedPreferences prefs,
      })
    >
    subject({bool cached = false}) async {
      final prefs = await SharedPreferences.getInstance();
      final client = _Relay();
      final auth = _OldAuth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      stubListPublishing(client: client, auth: auth, pubkey: owner);
      when(() => client.subscribe(any()))
          .thenAnswer((_) => const Stream<Event>.empty());
      if (cached) {
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            CuratedList(
              id: CuratedListService.defaultListId,
              pubkey: owner,
              name: 'Existing list',
              isPublic: false,
              videoEventIds: const [video],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              nostrEventId: eventId,
            ).toJson(),
          ]),
        );
      }
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return (service: service, client: client, auth: auth, prefs: prefs);
    }

    test('already initialized same-owner continuing list session preserves accepted live deferral', () async {
      SharedPreferences.setMockInitialValues({});
      final x = await subject(cached: true);
      await x.service.initialize();
      await pumpEventQueue();
      expect(x.service.isInitialized, isTrue);
      clearInteractions(x.client);
      await const PendingAccountCleanup(
        userPubkey: owner,
        isIdentityChange: true,
        deleteUserData: false,
      ).record(x.prefs);
      await x.service.initialize();
      expect(x.service.isInitialized, isTrue);
      expect(x.service.isCurrentSession, isTrue);
      expect(x.service.isReadyForMutations, isTrue);
      expect(x.service.getDefaultList()!.videoEventIds, [video]);
      expect(PendingAccountCleanup.read(x.prefs)!.userPubkey, owner);
      x.service.dispose();
    });
    for (final record in [
      (
        'same-owner',
        jsonEncode({
          'version': 1,
          'userPubkey': owner,
          'isIdentityChange': true,
          'deleteUserData': false,
        }),
      ),
      (
        'owner-mismatch',
        jsonEncode({
          'version': 1,
          'userPubkey': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'isIdentityChange': true,
          'deleteUserData': false,
        }),
      ),
      (
        'destructive',
        jsonEncode({
          'version': 1,
          'userPubkey': owner,
          'isIdentityChange': false,
          'deleteUserData': true,
        }),
      ),
      ('malformed', '{not-json'),
      ('wrong-storage-type', 42),
    ]) {
      test(
        'fresh ${record.$1} intent fences lists without clearing raw evidence',
        () async {
          SharedPreferences.setMockInitialValues({
            PendingAccountCleanup.storageKey: record.$2,
          });
          final x = await subject(cached: true);
          final original = x.prefs.get(PendingAccountCleanup.storageKey);
          expect(x.service.isReadyForMutations, isFalse);
          await x.service.initialize();
          expect(x.service.isInitialized, isFalse);
          expect(
            x.service.initializationError,
            isA<CuratedListAccountBoundaryException>(),
          );
          expect(x.service.getDefaultList()!.videoEventIds, [video]);
          expect(await x.service.createList(name: 'Blocked'), isNull);
          await x.service.fetchUserListsFromRelays(force: true);
          verifyNever(() => x.client.subscribe(any()));
          verifyNever(() => x.client.publishEventAwaitOk(any()));
          expect(x.prefs.get(PendingAccountCleanup.storageKey), original);
          x.service.dispose();
        },
      );
    }
    test('unknown durable readback blocks even if optimistic marker removal looks absent', () async {
      final original = SharedPreferencesStorePlatform.instance;
      final backend = _ReadbackBackend();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = backend;
      try {
        final prefs = await SharedPreferences.getInstance();
        backend.refuseRead = true;
        await expectLater(
          const PendingAccountCleanup(
            userPubkey: owner,
            isIdentityChange: true,
            deleteUserData: false,
          ).record(prefs),
          throwsA(isA<StateError>()),
        );
        await prefs.remove(PendingAccountCleanup.storageKey);
        expect(prefs.containsKey(PendingAccountCleanup.storageKey), isFalse);
        expect(PendingAccountCleanup.readbackUnknown(prefs), isTrue);
        final x = await subject(cached: true);
        await x.service.initialize();
        expect(x.service.isReadyForMutations, isFalse);
        expect(x.service.isInitialized, isFalse);
        verifyNever(() => x.client.subscribe(any()));
        verifyNever(() => x.client.publishEventAwaitOk(any()));
        x.service.dispose();
      } finally {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = original;
      }
    });
    test('verified cleanup retry permits a fresh session and leaves the old lease retired', () async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': owner,
      });
      final prefs = await SharedPreferences.getInstance();
      await const PendingAccountCleanup(
        userPubkey: owner,
        isIdentityChange: true,
        deleteUserData: false,
      ).record(prefs);
      final blocked = await subject(cached: true);
      await blocked.service.initialize();
      expect(blocked.service.isReadyForMutations, isFalse);
      final cleanup = UserDataCleanupService(prefs);
      var completed = 0;
      cleanup.onDatabaseCleanup =
          ({
            userPubkey,
            deleteUserData = false,
            preserveActiveSession = false,
          }) async {
            expect(userPubkey, owner);
            expect(deleteUserData, isFalse);
            completed++;
          };
      await cleanup.clearUserSpecificData(
        userPubkey: owner,
        isIdentityChange: true,
      );
      expect(completed, 1);
      expect(PendingAccountCleanup.read(prefs), isNull);
      expect(PendingAccountCleanup.readbackUnknown(prefs), isFalse);
      expect(blocked.service.isCurrentSession, isFalse);
      final next = await subject(cached: true);
      await next.service.initialize();
      await pumpEventQueue();
      expect(next.service.isInitialized, isTrue);
      expect(next.service.isReadyForMutations, isTrue);
      expect(blocked.service.isCurrentSession, isFalse);
      verifyNever(() => next.client.publishEventAwaitOk(any()));
      blocked.service.dispose();
      next.service.dispose();
    });
    test(
      'ordinary marker-free initialization retains default creation behavior',
      () async {
        SharedPreferences.setMockInitialValues({});
        final x = await subject();
        await x.service.initialize();
        await pumpEventQueue();
        expect(x.service.isInitialized, isTrue);
        expect(x.service.isReadyForMutations, isTrue);
        expect(x.service.getDefaultList(), isNotNull);
        verify(() => x.client.publishEventAwaitOk(any())).called(1);
        x.service.dispose();
      },
    );
  });
}
