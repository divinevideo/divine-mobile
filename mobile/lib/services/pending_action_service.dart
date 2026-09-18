// ABOUTME: Service for managing offline social actions with automatic sync on reconnect
// ABOUTME: Queues likes, reposts, and follows when offline and syncs when online

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

// Re-export types from db_client for convenience
export 'package:db_client/db_client.dart'
    show PendingAction, PendingActionStatus, PendingActionType;

/// Callback type for executing a pending action
typedef ActionExecutor = Future<void> Function(PendingAction action);

/// Configuration for retry behavior
class PendingActionRetryConfig {
  const PendingActionRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.resyncDelay = const Duration(seconds: 30),
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration resyncDelay;
}

/// Service for managing offline social actions with automatic sync on reconnect.
///
/// This service handles:
/// - Queuing actions when offline (likes, reposts, follows)
/// - Automatic sync when connectivity is restored
/// - Cancellation of opposite actions (e.g., like then unlike on same target)
/// - Exponential backoff retry for failed syncs
/// - Persistent storage via Drift database
class PendingActionService extends ChangeNotifier {
  PendingActionService({
    required ConnectionStatusService connectionStatusService,
    required PendingActionsDao pendingActionsDao,
    required String userPubkey,
    PendingActionRetryConfig? retryConfig,
  }) : _connectionStatusService = connectionStatusService,
       _dao = pendingActionsDao,
       _userPubkey = userPubkey,
       _retryConfig = retryConfig ?? const PendingActionRetryConfig();

  final ConnectionStatusService _connectionStatusService;
  final PendingActionsDao _dao;
  final String _userPubkey;
  final PendingActionRetryConfig _retryConfig;

  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _disposed = false;
  StreamSubscription<List<PendingAction>>? _dbSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _syncRetryTimer;

  /// Owns the retry backoff timers so [dispose] can cancel them. Without an
  /// owner the backoff keeps running after teardown and re-invokes the
  /// executor against a disposed service (#8457).
  final AsyncScope _async = AsyncScope(debugName: 'PendingActionService');

  /// Executors for different action types
  final Map<PendingActionType, ActionExecutor> _executors = {};

  /// Stream controller for pending actions
  final _pendingActionsController = BehaviorSubject<List<PendingAction>>.seeded(
    const [],
  );

  /// In-memory cache of pending actions
  List<PendingAction> _cachedPendingActions = [];
  List<PendingAction> _cachedAllActions = [];

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Stream of pending actions (reactive)
  Stream<List<PendingAction>> get pendingActionsStream =>
      _pendingActionsController.stream;

  /// Get current pending actions
  List<PendingAction> get pendingActions => _cachedPendingActions;

  /// Get all actions (including syncing/failed)
  List<PendingAction> get allActions => _cachedAllActions;

  /// Register an executor for a specific action type
  void registerExecutor(PendingActionType type, ActionExecutor executor) {
    _executors[type] = executor;
    Log.debug(
      'Registered executor for action type: $type',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.info(
      'Initializing PendingActionService',
      name: 'PendingActionService',
      category: LogCategory.system,
    );

    try {
      // Resume any actions that were syncing when app closed
      await _dao.resetSyncingToPending(_userPubkey);

      // Load initial data
      _cachedPendingActions = await _dao.getPendingActions(_userPubkey);
      _cachedAllActions = await _dao.getAllActions(_userPubkey);
      _emitPendingActions();

      // Subscribe to database changes
      _dbSubscription = _dao.watchPendingActions(_userPubkey).listen((actions) {
        _cachedPendingActions = actions;
        _emitPendingActions();
        _notifyIfAlive();
      });

      // Listen for connectivity changes.
      //
      // The status stream, not addListener: this notifier also fires for
      // dialling changes via setConnecting, and reacting to those would run a
      // sync on every relay reconnect attempt. The stream carries only the
      // online/offline edges (#8331).
      _connectivitySubscription = _connectionStatusService.statusStream.listen(
        (_) => _onConnectivityChange(),
      );

      _isInitialized = true;

      Log.info(
        'PendingActionService initialized with ${pendingActions.length} '
        'pending actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );

      // If online, try to sync any pending actions
      if (_connectionStatusService.isOnline && pendingActions.isNotEmpty) {
        _syncPendingActionsUnawaited();
      }
    } catch (e) {
      Log.error(
        'Failed to initialize PendingActionService: $e',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Queue an action for later sync
  ///
  /// If a conflicting action exists (e.g., liking then unliking same target),
  /// both actions are cancelled out.
  Future<void> queueAction({
    required PendingActionType type,
    required String targetId,
    String? authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    if (!_isInitialized) {
      throw StateError('PendingActionService not initialized');
    }

    // Find opposite action type
    final oppositeType = _getOppositeType(type);

    // Check for cancelling opposite action
    final existingAction = await _dao.findConflictingAction(
      _userPubkey,
      targetId,
      oppositeType,
    );

    if (existingAction != null) {
      // Actions cancel out - remove the existing one
      await _dao.deleteAction(existingAction.id);
      await _refreshCache();
      Log.info(
        'Action cancelled out: ${existingAction.type} on $targetId',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    // Create and save new action
    final action = PendingAction.create(
      type: type,
      targetId: targetId,
      userPubkey: _userPubkey,
      authorPubkey: authorPubkey,
      addressableId: addressableId,
      targetKind: targetKind,
    );

    await _dao.upsertAction(action);
    await _refreshCache();

    if (_connectionStatusService.isOnline) _scheduleSyncRetry();

    Log.info(
      'Queued action: ${action.type} on $targetId',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Check if there's a pending action for a target
  bool hasPendingAction(String targetId, PendingActionType type) {
    return _cachedPendingActions.any(
      (a) => a.targetId == targetId && a.type == type,
    );
  }

  /// Get pending action for a target if exists
  PendingAction? getPendingAction(String targetId, PendingActionType type) {
    try {
      return _cachedPendingActions.firstWhere(
        (a) => a.targetId == targetId && a.type == type,
      );
    } catch (_) {
      return null;
    }
  }

  /// Cancel a pending action
  Future<void> cancelAction(String actionId) async {
    await _dao.deleteAction(actionId);
    await _refreshCache();
    Log.info(
      'Cancelled action: $actionId',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Sync all pending actions
  Future<void> syncPendingActions() async {
    if (_isSyncing) {
      Log.debug(
        'Sync already in progress, skipping',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    if (!_connectionStatusService.isOnline) {
      Log.debug(
        'Offline, skipping sync',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    // Claim the slot before the first suspension point. The DAO read below
    // is an await, so two calls arriving close together could both clear the
    // guard above and run the loop, publishing every queued action twice.
    // The finally also releases the slot when a DAO operation escapes, which
    // would otherwise leave the service unable to sync again for the session.
    _isSyncing = true;
    var startedSync = false;
    var shouldRetry = pendingActions.isNotEmpty;
    try {
      final actions = await _dao.getPendingActions(_userPubkey);
      shouldRetry = actions.isNotEmpty;
      if (actions.isEmpty) {
        Log.debug(
          'No pending actions to sync',
          name: 'PendingActionService',
          category: LogCategory.system,
        );
        return;
      }

      startedSync = true;
      _notifyIfAlive();

      Log.info(
        'Starting sync of ${actions.length} pending actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );

      for (final action in actions) {
        if (!_connectionStatusService.isOnline) {
          Log.warning(
            'Lost connectivity during sync, pausing',
            name: 'PendingActionService',
            category: LogCategory.system,
          );
          break;
        }

        await _syncAction(action);
      }

      await _refreshCache();

      final remaining = await _dao.getPendingActions(_userPubkey);
      shouldRetry = remaining.isNotEmpty;
      Log.info(
        'Sync complete. Remaining pending: ${remaining.length}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } on AsyncCancelledException {
      // The service was disposed mid-sync. That is teardown, not failure: the
      // in-flight rows stay `syncing` and initialize()'s resetSyncingToPending
      // recovers them next session. Absorbing it here keeps a routine sign-out
      // from surfacing as an error, and keeps it from escaping the
      // fire-and-forget call in _syncPendingActionsUnawaited.
      Log.debug(
        'Sync abandoned - service disposed',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } finally {
      _isSyncing = false;
      // dispose() cannot cancel a sync already in flight, so this block can
      // run after teardown. Rescheduling here would resurrect the timer
      // dispose() just cancelled, and that retry re-enters this method and
      // reschedules again — an unbounded loop nothing owns (#8457).
      if (!_disposed) {
        if (shouldRetry && _connectionStatusService.isOnline) {
          _scheduleSyncRetry();
        } else {
          _cancelSyncRetry();
        }
        if (startedSync) _notifyIfAlive();
      }
    }
  }

  /// Clear completed actions older than specified duration
  Future<void> clearOldCompletedActions({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final deleted = await _dao.deleteOldCompleted(_userPubkey, olderThan);
    if (deleted > 0) {
      await _refreshCache();
      Log.debug(
        'Cleared $deleted old completed actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all data (for logout)
  Future<void> clearAll() async {
    _cancelSyncRetry();
    await _dao.clearAll(_userPubkey);
    _cachedPendingActions = [];
    _cachedAllActions = [];
    _emitPendingActions();
    _notifyIfAlive();
    Log.info(
      'Cleared all pending actions',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Dispose resources
  @override
  void dispose() {
    _disposed = true;
    // Cancel the in-flight retry backoff first: it is the one piece of work
    // that outlives this method otherwise, and its continuation would touch
    // every resource torn down below.
    _async.dispose();
    _cancelSyncRetry();
    if (_connectivitySubscription != null) {
      runDetached(
        _connectivitySubscription!.cancel(),
        'cancel the pending-action connectivity subscription',
        logName: 'PendingActionService',
        category: LogCategory.system,
      );
      _connectivitySubscription = null;
    }
    if (_dbSubscription != null) {
      runDetached(
        _dbSubscription!.cancel(),
        'cancel the pending-action database subscription',
        logName: 'PendingActionService',
        category: LogCategory.system,
      );
      _dbSubscription = null;
    }
    runDetached(
      _pendingActionsController.close(),
      'close the pending-action stream',
      logName: 'PendingActionService',
      category: LogCategory.system,
    );
    super.dispose();
  }

  // Private methods

  PendingActionType _getOppositeType(PendingActionType type) {
    switch (type) {
      case PendingActionType.like:
        return PendingActionType.unlike;
      case PendingActionType.unlike:
        return PendingActionType.like;
      case PendingActionType.repost:
        return PendingActionType.unrepost;
      case PendingActionType.unrepost:
        return PendingActionType.repost;
      case PendingActionType.follow:
        return PendingActionType.unfollow;
      case PendingActionType.unfollow:
        return PendingActionType.follow;
    }
  }

  Future<void> _refreshCache() async {
    _cachedPendingActions = await _dao.getPendingActions(_userPubkey);
    _cachedAllActions = await _dao.getAllActions(_userPubkey);
    _emitPendingActions();
  }

  void _emitPendingActions() {
    if (!_pendingActionsController.isClosed) {
      _pendingActionsController.add(_cachedPendingActions);
    }
  }

  void _onConnectivityChange() {
    if (_connectionStatusService.isOnline && pendingActions.isNotEmpty) {
      _cancelSyncRetry();
      Log.info(
        'Connectivity restored, triggering sync',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      _syncPendingActionsUnawaited();
    } else if (!_connectionStatusService.isOnline) {
      _cancelSyncRetry();
    }
  }

  void _scheduleSyncRetry() {
    // Keep the lifecycle check at the resource-creation boundary. Most callers
    // guard before reaching here, but queueAction resumes across DAO awaits and
    // can race teardown independently of syncPendingActions' finally block.
    if (_disposed) return;
    if (_syncRetryTimer?.isActive ?? false) return;
    _syncRetryTimer = Timer(_retryConfig.resyncDelay, () {
      _syncRetryTimer = null;
      _syncPendingActionsUnawaited();
    });
  }

  void _syncPendingActionsUnawaited() {
    unawaited(_syncPendingActionsAndLog());
  }

  Future<void> _syncPendingActionsAndLog() async {
    try {
      await syncPendingActions();
    } catch (e, stackTrace) {
      Log.error(
        'Failed to sync pending actions',
        name: 'PendingActionService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// `notifyListeners` for call sites that can resume after [dispose].
  ///
  /// `ChangeNotifier.notifyListeners` throws `A PendingActionService was used
  /// after being disposed` once disposed, and every caller here sits after an
  /// await.
  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  void _cancelSyncRetry() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  Future<void> _syncAction(PendingAction action) async {
    final executor = _executors[action.type];
    if (executor == null) {
      Log.error(
        'No executor registered for action type: ${action.type}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    // Mark as syncing
    await _dao.updateStatus(action.id, PendingActionStatus.syncing);

    try {
      await _async.retryWithBackoff(
        operation: () => executor(action),
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        debugName: 'Sync-${action.type}-${action.targetId}',
        retryWhen: _isRetriableError,
      );

      // Mark as completed
      await _dao.updateStatus(action.id, PendingActionStatus.completed);

      Log.info(
        'Successfully synced action: ${action.type} on ${action.targetId}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } on AsyncCancelledException {
      // Disposed mid-backoff. Leave the row in `syncing`: initialize()'s
      // resetSyncingToPending already recovers those next session, and writing
      // a status here would be a DAO write on behalf of a torn-down owner.
      rethrow;
    } on TerminalSocialActionException catch (e) {
      await _dao.updateStatus(
        action.id,
        PendingActionStatus.failed,
        lastError: e.toString(),
        retryCount: action.retryCount,
      );
      Log.warning(
        'Pending action rejected by terminal account policy: '
        '${action.type} on ${action.targetId}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } catch (e) {
      // Mark as failed or pending for retry
      final newRetryCount = action.retryCount + 1;
      final newStatus = newRetryCount >= PendingAction.maxRetries
          ? PendingActionStatus.failed
          : PendingActionStatus.pending;

      await _dao.updateStatus(
        action.id,
        newStatus,
        lastError: e.toString(),
        retryCount: newRetryCount,
      );

      Log.error(
        'Failed to sync action: ${action.type} on ${action.targetId} - $e',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
  }

  bool _isRetriableError(dynamic error) {
    if (error is TerminalSocialActionException) return false;
    final errorStr = error.toString().toLowerCase();

    // Network errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return true;
    }

    // Server errors are retriable
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }

    // Auth errors are not retriable
    if (errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('unauthorized')) {
      return false;
    }

    // Default to retriable
    return true;
  }
}
