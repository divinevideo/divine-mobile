// ABOUTME: Unit tests for PendingActionService
// ABOUTME: Tests offline action queuing, sync on reconnect, and action
// ABOUTME: cancellation using Drift database

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/pending_action_service.dart';

class MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class MockPendingActionsDao extends Mock implements PendingActionsDao {}

class _ThrowOncePendingActionsDao extends PendingActionsDao {
  _ThrowOncePendingActionsDao(super.attachedDatabase);

  var _shouldThrow = true;

  @override
  Future<bool> updateStatus(
    String id,
    PendingActionStatus status, {
    String? lastError,
    int? retryCount,
  }) {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('database unavailable');
    }
    return super.updateStatus(
      id,
      status,
      lastError: lastError,
      retryCount: retryCount,
    );
  }
}

class _CountingPendingActionsDao extends PendingActionsDao {
  _CountingPendingActionsDao(super.attachedDatabase);

  int getPendingActionsCalls = 0;

  @override
  Future<List<PendingAction>> getPendingActions(String userPubkey) {
    getPendingActionsCalls++;
    return super.getPendingActions(userPubkey);
  }
}

class _TerminalActionException implements TerminalSocialActionException {
  const _TerminalActionException();
}

void main() {
  late PendingActionService service;
  late MockConnectionStatusService mockConnectionService;
  late StreamController<bool> connectivityEdges;
  late AppDatabase database;
  late PendingActionsDao dao;

  const testUserPubkey = 'test_user_pubkey_123';

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(PendingActionType.like);
  });

  setUp(() async {
    // Create in-memory database for testing
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.pendingActionsDao;

    mockConnectionService = MockConnectionStatusService();

    // Default to online
    when(() => mockConnectionService.isOnline).thenReturn(true);

    // The service subscribes to connectivity *edges* rather than to every
    // notification, so that a relay dial cannot trigger a sync (#8331).
    connectivityEdges = StreamController<bool>.broadcast();
    when(
      () => mockConnectionService.statusStream,
    ).thenAnswer((_) => connectivityEdges.stream);

    service = PendingActionService(
      connectionStatusService: mockConnectionService,
      pendingActionsDao: dao,
      userPubkey: testUserPubkey,
      retryConfig: const PendingActionRetryConfig(
        maxRetries: 1,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
    );

    await service.initialize();
  });

  tearDown(() async {
    service.dispose();
    await connectivityEdges.close();
    await database.close();
  });

  group('PendingActionService', () {
    group('initialization', () {
      test('initializes successfully', () async {
        expect(service.isInitialized, isTrue);
        expect(service.pendingActions, isEmpty);
      });

      test('loads existing actions from database on init', () async {
        // Queue an action
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(service.pendingActions.length, equals(1));

        // Set offline to prevent auto-sync when new service initializes
        when(() => mockConnectionService.isOnline).thenReturn(false);

        // Create a new service instance to simulate app restart
        final newService = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: dao,
          userPubkey: testUserPubkey,
        );
        await newService.initialize();

        expect(newService.pendingActions.length, equals(1));
        expect(newService.pendingActions.first.targetId, equals('event123'));

        newService.dispose();
      });
    });

    group('queueAction', () {
      test('queues a like action', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
          addressableId: '34236:author123:video1',
          targetKind: 34236,
        );

        expect(service.pendingActions.length, equals(1));

        final action = service.pendingActions.first;
        expect(action.type, equals(PendingActionType.like));
        expect(action.targetId, equals('event123'));
        expect(action.authorPubkey, equals('author123'));
        expect(action.addressableId, equals('34236:author123:video1'));
        expect(action.targetKind, equals(34236));
        expect(action.status, equals(PendingActionStatus.pending));
      });

      test('queues a follow action', () async {
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey123',
        );

        expect(service.pendingActions.length, equals(1));

        final action = service.pendingActions.first;
        expect(action.type, equals(PendingActionType.follow));
        expect(action.targetId, equals('pubkey123'));
      });

      test('cancels opposite actions on same target', () async {
        // Queue a like
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        expect(service.pendingActions.length, equals(1));

        // Queue an unlike on same target - should cancel out
        await service.queueAction(
          type: PendingActionType.unlike,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        expect(service.pendingActions.length, equals(0));
      });

      test('cancels follow/unfollow on same target', () async {
        // Queue a follow
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey123',
        );
        expect(service.pendingActions.length, equals(1));

        // Queue an unfollow on same target - should cancel out
        await service.queueAction(
          type: PendingActionType.unfollow,
          targetId: 'pubkey123',
        );
        expect(service.pendingActions.length, equals(0));
      });

      test('allows multiple actions on different targets', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event1',
          authorPubkey: 'author1',
        );
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event2',
          authorPubkey: 'author2',
        );
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey1',
        );

        expect(service.pendingActions.length, equals(3));
      });
    });

    group('hasPendingAction', () {
      test('returns true when action exists', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(
          service.hasPendingAction('event123', PendingActionType.like),
          isTrue,
        );
      });

      test('returns false when action does not exist', () {
        expect(
          service.hasPendingAction('event123', PendingActionType.like),
          isFalse,
        );
      });

      test('returns false for different action type on same target', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(
          service.hasPendingAction('event123', PendingActionType.unlike),
          isFalse,
        );
      });
    });

    group('cancelAction', () {
      test('removes action from queue', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        final actionId = service.pendingActions.first.id;
        await service.cancelAction(actionId);

        expect(service.pendingActions, isEmpty);
      });
    });

    group('syncPendingActions', () {
      test('skips sync when offline', () async {
        when(() => mockConnectionService.isOnline).thenReturn(false);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register a mock executor that would fail if called
        var executorCalled = false;
        service.registerExecutor(PendingActionType.like, (_) async {
          executorCalled = true;
        });

        await service.syncPendingActions();

        expect(executorCalled, isFalse);
        expect(service.pendingActions.length, equals(1));
      });

      test('syncs actions when online', () async {
        when(() => mockConnectionService.isOnline).thenReturn(true);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register executor
        final executedActions = <PendingAction>[];
        service.registerExecutor(PendingActionType.like, (action) async {
          executedActions.add(action);
        });

        await service.syncPendingActions();

        expect(executedActions.length, equals(1));
        expect(executedActions.first.targetId, equals('event123'));
        expect(service.pendingActions, isEmpty);
      });

      test('retries an online action queued after initialization', () async {
        service.dispose();
        service = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: dao,
          userPubkey: testUserPubkey,
          retryConfig: const PendingActionRetryConfig(
            maxRetries: 0,
            initialDelay: Duration.zero,
            maxDelay: Duration.zero,
            resyncDelay: Duration.zero,
          ),
        );
        await service.initialize();

        var calls = 0;
        final completed = Completer<void>();
        service.addListener(() {
          if (calls >= 2 &&
              !service.isSyncing &&
              service.pendingActions.isEmpty &&
              !completed.isCompleted) {
            completed.complete();
          }
        });
        service.registerExecutor(PendingActionType.like, (_) async {
          calls++;
          if (calls == 1) throw Exception('Network error');
        });

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        await completed.future;

        expect(
          calls,
          equals(2),
          reason: 'a transient failure must retain the existing retry cadence',
        );
      });

      test(
        'does not run twice when called again during the DAO read',
        () async {
          // Regression for a TOCTOU window (#6934). _isSyncing used to be set
          // only AFTER `await _dao.getPendingActions(...)`, so two calls
          // arriving inside that suspension point both cleared the guard and
          // both ran the loop — publishing every queued action twice. The 30s
          // ConnectionStatusService loop produced exactly such a pair, 100ms
          // apart. The guard is now claimed before the first await.
          when(() => mockConnectionService.isOnline).thenReturn(true);

          await service.queueAction(
            type: PendingActionType.like,
            targetId: 'event123',
            authorPubkey: 'author123',
          );

          final gate = Completer<void>();
          var executorCalls = 0;
          service.registerExecutor(PendingActionType.like, (_) async {
            executorCalls++;
            await gate.future;
          });

          // No yield between the two calls. An async body runs synchronously up
          // to its first await, so the fixed version claims _isSyncing before
          // suspending on the DAO read and the second call bails out. With the
          // flag set after that await instead, both calls clear the guard and
          // both run the loop — which is the bug. Yielding here would hide it,
          // because the first call would have set the flag either way.
          final first = service.syncPendingActions();
          final second = service.syncPendingActions();

          gate.complete();
          await Future.wait([first, second]);

          expect(
            executorCalls,
            equals(1),
            reason: 'a concurrent call must not re-publish the queued action',
          );
        },
      );

      test('releases the sync guard when the DAO throws', () async {
        // _syncAction catches executor failures, so they cannot escape the
        // sync loop. A DAO failure while marking an action as syncing does
        // escape, and used to leave _isSyncing true because the reset lived
        // only on the success path.
        final mockDao = MockPendingActionsDao();
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: 'event123',
          userPubkey: testUserPubkey,
          authorPubkey: 'author123',
        );
        var pendingReads = 0;
        when(
          () => mockDao.resetSyncingToPending(testUserPubkey),
        ).thenAnswer((_) async => 0);
        when(
          () => mockDao.getPendingActions(testUserPubkey),
        ).thenAnswer((_) async => pendingReads++ == 0 ? const [] : [action]);
        when(
          () => mockDao.getAllActions(testUserPubkey),
        ).thenAnswer((_) async => const []);
        when(
          () => mockDao.watchPendingActions(testUserPubkey),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockDao.updateStatus(action.id, PendingActionStatus.syncing),
        ).thenThrow(StateError('database unavailable'));

        final failingService = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: mockDao,
          userPubkey: testUserPubkey,
        );
        addTearDown(failingService.dispose);
        await failingService.initialize();
        failingService.registerExecutor(PendingActionType.like, (_) async {});

        await expectLater(
          failingService.syncPendingActions(),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          failingService.syncPendingActions(),
          throwsA(isA<StateError>()),
        );

        verify(
          () => mockDao.updateStatus(action.id, PendingActionStatus.syncing),
        ).called(2);
      });

      test('retries after a DAO error releases the sync guard', () async {
        when(() => mockConnectionService.isOnline).thenReturn(false);

        service.dispose();
        service = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: _ThrowOncePendingActionsDao(database),
          userPubkey: testUserPubkey,
          retryConfig: const PendingActionRetryConfig(
            maxRetries: 0,
            initialDelay: Duration.zero,
            maxDelay: Duration.zero,
            resyncDelay: Duration.zero,
          ),
        );
        await service.initialize();

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        when(() => mockConnectionService.isOnline).thenReturn(true);
        var executorCalls = 0;
        service.registerExecutor(PendingActionType.like, (_) async {
          executorCalls++;
        });

        await expectLater(service.syncPendingActions(), throwsStateError);

        expect(service.isSyncing, isFalse);
        await pumpEventQueue();
        expect(executorCalls, equals(1));
        expect(service.pendingActions, isEmpty);
      });

      test('marks action as failed after max retries', () async {
        when(() => mockConnectionService.isOnline).thenReturn(true);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register executor that always fails
        service.registerExecutor(PendingActionType.like, (_) async {
          throw Exception('Network error');
        });

        // Run sync - it will fail
        await service.syncPendingActions();

        // After failure, action should still exist with updated retry count
        final allActions = service.allActions;
        expect(allActions.length, equals(1));
        expect(allActions.first.retryCount, greaterThan(0));
      });

      test('terminalizes account-policy failures without retrying', () async {
        when(() => mockConnectionService.isOnline).thenReturn(true);
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        var attempts = 0;
        service.registerExecutor(PendingActionType.like, (_) async {
          attempts++;
          throw const _TerminalActionException();
        });

        await service.syncPendingActions();

        expect(attempts, 1);
        expect(service.pendingActions, isEmpty);
        expect(service.allActions.single.status, PendingActionStatus.failed);
        expect(service.allActions.single.retryCount, 0);
      });
    });

    group('connectivity edges', () {
      test('regaining connectivity syncs the queue exactly once', () async {
        when(() => mockConnectionService.isOnline).thenReturn(false);
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        expect(
          service.pendingActions,
          hasLength(1),
          reason: 'queued while offline',
        );

        var executorCalls = 0;
        service.registerExecutor(PendingActionType.like, (_) async {
          executorCalls++;
        });

        when(() => mockConnectionService.isOnline).thenReturn(true);
        connectivityEdges.add(true);
        await pumpEventQueue();

        expect(executorCalls, equals(1));
        expect(service.pendingActions, isEmpty);
      });
    });

    group('dispose during an in-flight sync', () {
      // The service is owned by a keepAlive Riverpod provider that watches auth
      // state, so any sign-out or account switch disposes it. When a retry
      // backoff is in flight at that moment the sync method is suspended inside
      // AsyncScope and its continuation runs after dispose (#8457).
      late PendingActionService disposableService;

      Future<void> setUpDisposableService({
        required ActionExecutor executor,
      }) async {
        disposableService = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: dao,
          userPubkey: testUserPubkey,
          retryConfig: const PendingActionRetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 20),
            maxDelay: Duration(milliseconds: 40),
            resyncDelay: Duration(milliseconds: 20),
          ),
        );
        await disposableService.initialize();
        disposableService.registerExecutor(PendingActionType.like, executor);
        await disposableService.queueAction(
          type: PendingActionType.like,
          targetId: 'event_dispose',
          authorPubkey: 'author_dispose',
        );
      }

      test('stops invoking the executor once disposed mid-backoff', () async {
        var executorCalls = 0;
        var disposed = false;
        var callsAfterDispose = 0;
        final firstExecutorCall = Completer<void>();

        await setUpDisposableService(
          executor: (_) async {
            executorCalls++;
            if (!firstExecutorCall.isCompleted) firstExecutorCall.complete();
            if (disposed) callsAfterDispose++;
            throw Exception('connection refused');
          },
        );

        unawaited(disposableService.syncPendingActions());
        await firstExecutorCall.future.timeout(const Duration(seconds: 2));
        expect(executorCalls, 1, reason: 'first attempt ran before dispose');

        disposableService.dispose();
        disposed = true;

        // Long enough for the whole retry ladder to have fired if cancellation
        // regresses; the executor signal above, not this window, gates dispose.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          callsAfterDispose,
          0,
          reason: 'a disposed service must not publish to relays',
        );
      });

      // Note: _scheduleSyncRetry's own `_disposed` guard and the finally
      // block's guard are redundant by design, so removing either one alone
      // leaves behaviour unchanged and this test green. It pins the pair.
      // Detecting one redundant guard would need white-box assertions, which
      // .claude/rules/testing.md steers away from.
      test('does not reschedule itself after dispose', () async {
        // The resurrected timer re-enters syncPendingActions every
        // resyncDelay. Once the AsyncScope is disposed the retry
        // short-circuits before the executor, so the only visible trace of the
        // loop is the DAO read at the top of each pass.
        final countingDao = _CountingPendingActionsDao(database);
        final firstExecutorCall = Completer<void>();
        final service = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: countingDao,
          userPubkey: testUserPubkey,
          retryConfig: const PendingActionRetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 20),
            maxDelay: Duration(milliseconds: 40),
            resyncDelay: Duration(milliseconds: 20),
          ),
        );
        await service.initialize();
        service.registerExecutor(
          PendingActionType.like,
          (_) async {
            if (!firstExecutorCall.isCompleted) firstExecutorCall.complete();
            throw Exception('connection refused');
          },
        );
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event_dispose',
          authorPubkey: 'author_dispose',
        );

        final escapedErrors = <Object>[];
        await runZonedGuarded(
          () async {
            unawaited(service.syncPendingActions());
            await firstExecutorCall.future.timeout(const Duration(seconds: 2));
            service.dispose();
          },
          (error, _) => escapedErrors.add(error),
        );

        // Snapshot immediately after dispose, before any wait. A resurrected
        // timer fires one resyncDelay later, so any window opened before this
        // line absorbs the very read the assertion is looking for.
        //
        // The resurrected loop is bounded to a single pass here: the cancelled
        // _syncAction rethrows before updating status, leaving the row
        // `syncing`, which getPendingActions excludes — so the next pass sees
        // no work and stops. One extra read is the whole signal.
        final readsAtDispose = countingDao.getPendingActionsCalls;

        // 100ms is five turns of the 20ms resync loop if it is resurrected.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          countingDao.getPendingActionsCalls,
          readsAtDispose,
          reason: 'the finally block must not resurrect the sync retry timer',
        );
        expect(
          escapedErrors,
          isEmpty,
          reason: 'notifyListeners must not fire through a disposed notifier',
        );
      });
    });

    group('pendingActionsStream', () {
      test('emits updates when actions are added', () async {
        final emissions = <List<PendingAction>>[];
        final subscription = service.pendingActionsStream.listen(emissions.add);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Allow stream to emit
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emissions.isNotEmpty, isTrue);
        expect(emissions.last.length, equals(1));

        await subscription.cancel();
      });
    });

    group('clearAll', () {
      test('removes all pending actions', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event1',
          authorPubkey: 'author1',
        );
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey1',
        );

        expect(service.allActions.length, equals(2));

        await service.clearAll();

        expect(service.allActions, isEmpty);
        expect(service.pendingActions, isEmpty);
      });
    });
  });

  group('PendingAction model', () {
    test('creates action with correct default values', () {
      final action = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
        authorPubkey: 'author123',
      );

      expect(action.id, isNotEmpty);
      expect(action.type, equals(PendingActionType.like));
      expect(action.targetId, equals('event123'));
      expect(action.status, equals(PendingActionStatus.pending));
      expect(action.retryCount, equals(0));
    });

    test('isPositiveAction returns correct values', () {
      expect(
        PendingAction.create(
          type: PendingActionType.like,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unlike,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isFalse,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.follow,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
    });

    test('oppositeType returns correct type', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'test',
        userPubkey: testUserPubkey,
      );
      expect(like.oppositeType, equals(PendingActionType.unlike));

      final follow = PendingAction.create(
        type: PendingActionType.follow,
        targetId: 'test',
        userPubkey: testUserPubkey,
      );
      expect(follow.oppositeType, equals(PendingActionType.unfollow));
    });

    test('cancels returns true for opposite actions on same target', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );
      final unlike = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );

      expect(like.cancels(unlike), isTrue);
      expect(unlike.cancels(like), isTrue);
    });

    test('cancels returns false for different targets', () {
      final like1 = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );
      final unlike2 = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: 'event456',
        userPubkey: testUserPubkey,
      );

      expect(like1.cancels(unlike2), isFalse);
    });
  });
}
