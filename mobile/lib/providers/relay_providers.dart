// ABOUTME: Relay & connection-status Riverpod providers split from app_providers.dart
// ABOUTME: Connection monitoring, relay capability, statistics, and the two app-shell
// ABOUTME: side-effect bridges that translate Nostr-relay state into local stats and resets

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart'
    show NostrClient, RelayConnectionStatus, RelayRemoveSource, RelayState;
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'relay_providers.g.dart';

/// Current configured relay URLs.
///
/// Updated by [relaySetChangeBridge] from the active relay status map so UI
/// that only needs the relay set can react without constructing its own client.
final configuredRelayUrlsProvider =
    NotifierProvider<ConfiguredRelayUrls, List<String>>(
      ConfiguredRelayUrls.new,
    );

class ConfiguredRelayUrls extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  void setUrls(List<String> urls) {
    state = List.unmodifiable(urls);
  }
}

final _relaySetChangeCoordinatorProvider = Provider<_RelaySetChangeCoordinator>(
  (ref) {
    final coordinator = _RelaySetChangeCoordinator();
    ref.onDispose(coordinator.dispose);
    return coordinator;
  },
);

class _RelaySetChangeCoordinator {
  Timer? _debounceTimer;
  _RelayClientAttachment? _attachment;
  _RelayResetTransaction? _pendingTransaction;
  var _nextAttachmentGeneration = 0;
  var _nextTransactionVersion = 0;
  var _operationInProgress = false;
  var _rescheduleAfterOperation = false;
  var _disposed = false;

  void attach({
    required NostrClient client,
    required String? identityPubkey,
    required VideoEventService videoEventService,
    required NostrInitializationInProgress initializationTracker,
  }) {
    final scope = _RelayIntentScope(
      defaultRelayUrl: client.defaultRelayUrl,
      identityPubkey: identityPubkey,
    );
    final currentAttachment = _attachment;
    if (currentAttachment != null &&
        identical(currentAttachment.client, client)) {
      _attachment = currentAttachment.copyWith(
        videoEventService: videoEventService,
        initializationTracker: initializationTracker,
        scope: scope,
      );
      _discardPendingTransactionOutside(scope);
      return;
    }

    _attachment = _RelayClientAttachment(
      client: client,
      videoEventService: videoEventService,
      initializationTracker: initializationTracker,
      scope: scope,
      generation: ++_nextAttachmentGeneration,
    );

    if (_discardPendingTransactionOutside(scope)) return;

    if (_operationInProgress) {
      _rescheduleAfterOperation = true;
    } else if (!(_debounceTimer?.isActive ?? false)) {
      _scheduleReset();
    }
  }

  bool _discardPendingTransactionOutside(_RelayIntentScope scope) {
    final transaction = _pendingTransaction;
    if (transaction == null || transaction.scope == scope) return false;

    Log.info(
      'Discarding pending relay reset at environment or identity boundary',
      name: 'RelaySetChangeBridge',
      category: LogCategory.relay,
    );
    _pendingTransaction = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _rescheduleAfterOperation = false;
    return true;
  }

  bool isClientInitializing(NostrClient client) {
    final attachment = _attachment;
    return !client.isInitialized ||
        (attachment?.initializationTracker.isClientInitializing(client) ??
            false);
  }

  void recordMembershipChange({
    required NostrClient client,
    required Set<String> previousRelaySet,
    required Set<String> currentRelaySet,
    required bool changeRequiresReset,
  }) {
    if (_disposed) return;
    final attachment = _attachment;
    if (attachment == null || !identical(attachment.client, client)) return;

    var transaction = _pendingTransaction;
    if (transaction != null && transaction.scope != attachment.scope) {
      _pendingTransaction = null;
      transaction = null;
    }

    if (transaction == null) {
      if (!changeRequiresReset) {
        Log.info(
          'Relay set change originated during active client initialization; '
          'skipping forced reconnect '
          '(relayCount=${currentRelaySet.length})',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
        return;
      }
      transaction = _RelayResetTransaction(
        scope: attachment.scope,
        sourceClient: client,
        targetRelaySet: Set.of(currentRelaySet),
        version: ++_nextTransactionVersion,
      );
      _pendingTransaction = transaction;
    } else if (identical(transaction.sourceClient, client)) {
      // Keep the latest complete target from the client where the reset intent
      // originated. Startup-stage changes from that same generation belong to
      // the batch but cannot clear its sticky reset requirement.
      _updateTransactionTarget(transaction, currentRelaySet);
    } else if (changeRequiresReset) {
      // A real edit can race with replacement. Merge its delta into the target
      // retained from the previous generation instead of replacing that target
      // with the replacement's potentially stale startup snapshot.
      final target = Set.of(transaction.targetRelaySet);
      target
        ..removeAll(previousRelaySet.difference(currentRelaySet))
        ..addAll(currentRelaySet.difference(previousRelaySet));
      _updateTransactionTarget(transaction, target);
    } else {
      // Ignore startup-only membership snapshots from a replacement client.
      // The retained target is reconciled onto it when the debounce fires.
      return;
    }

    if (_operationInProgress) {
      _rescheduleAfterOperation = true;
    } else {
      _scheduleReset();
    }
  }

  void _updateTransactionTarget(
    _RelayResetTransaction transaction,
    Set<String> targetRelaySet,
  ) {
    if (_setsEqual(transaction.targetRelaySet, targetRelaySet)) return;
    transaction
      ..targetRelaySet = Set.of(targetRelaySet)
      ..version = ++_nextTransactionVersion
      ..reconciliationRetryUsed = false;
  }

  void _scheduleReset() {
    if (_disposed || _pendingTransaction == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _debounceTimer = null;
      unawaited(_performReset());
    });
  }

  Future<void> _performReset() async {
    if (_disposed || _pendingTransaction == null) return;
    if (_operationInProgress) {
      _rescheduleAfterOperation = true;
      return;
    }

    final attachment = _attachment;
    final transaction = _pendingTransaction;
    if (attachment == null || transaction == null) return;

    if (isClientInitializing(attachment.client)) {
      Log.info(
        'Active client initialization overlaps relay reset debounce; '
        'deferring forced reconnect '
        '(relayCount=${transaction.targetRelaySet.length})',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );
      _scheduleReset();
      return;
    }

    final transactionVersion = transaction.version;
    _operationInProgress = true;

    try {
      if (!identical(transaction.sourceClient, attachment.client)) {
        final reconciliation = await _reconcileRelaySet(
          attachment: attachment,
          transaction: transaction,
          transactionVersion: transactionVersion,
        );
        if (reconciliation.status == _RelayReconciliationStatus.superseded) {
          _rescheduleAfterOperation = _pendingTransaction != null;
          return;
        }
        if (reconciliation.status == _RelayReconciliationStatus.incomplete) {
          Log.error(
            'Failed to reconcile replacement relay set: '
            '${reconciliation.error}',
            name: 'RelaySetChangeBridge',
            category: LogCategory.relay,
          );
          _handleReconciliationFailure(transaction, transactionVersion);
          return;
        }
      }

      if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
        _rescheduleAfterOperation = _pendingTransaction != null;
        return;
      }

      Log.info(
        'Debounce elapsed - forcing WebSocket reconnection and feed reset',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );

      try {
        await attachment.client.forceReconnectAll();
        Log.info(
          'Successfully reconnected all relay WebSockets',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
      } catch (e) {
        Log.error(
          'Failed to reconnect relays: $e',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
      }

      if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
        _rescheduleAfterOperation = _pendingTransaction != null;
        return;
      }

      try {
        await attachment.videoEventService.resetAndResubscribeAll();
      } catch (e) {
        Log.error(
          'Failed to reset relay-backed feeds: $e',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
      }

      if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
        _rescheduleAfterOperation = _pendingTransaction != null;
        return;
      }

      _pendingTransaction = null;
    } finally {
      _operationInProgress = false;
      if (_rescheduleAfterOperation && _pendingTransaction != null) {
        _rescheduleAfterOperation = false;
        _scheduleReset();
      } else {
        _rescheduleAfterOperation = false;
      }
    }
  }

  Future<_RelayReconciliationResult> _reconcileRelaySet({
    required _RelayClientAttachment attachment,
    required _RelayResetTransaction transaction,
    required int transactionVersion,
  }) async {
    final client = attachment.client;
    final targetRelaySet = Set.of(transaction.targetRelaySet);
    try {
      final currentRelaySet = client.configuredRelays.toSet();
      final additions = <String>[];
      for (final relay in targetRelaySet.difference(currentRelaySet)) {
        if (await client.isUserRemovedRelay(relay)) {
          targetRelaySet.remove(relay);
        } else {
          additions.add(relay);
        }
      }
      final removals = currentRelaySet.difference(targetRelaySet).toList();

      if (additions.isNotEmpty) {
        final addedCount = await client.addRelays(additions);
        if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
          return const _RelayReconciliationResult.superseded();
        }
        if (addedCount != additions.length) {
          return _RelayReconciliationResult.incomplete(
            'added $addedCount of ${additions.length} relays',
          );
        }
      }
      for (final relay in removals) {
        final removed = await client.removeRelay(
          relay,
          source: RelayRemoveSource.automatic,
        );
        if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
          return const _RelayReconciliationResult.superseded();
        }
        if (!removed) {
          return _RelayReconciliationResult.incomplete(
            'could not remove relay $relay',
          );
        }
      }

      final reconciledRelaySet = client.configuredRelays.toSet();
      if (!_setsEqual(reconciledRelaySet, targetRelaySet)) {
        return const _RelayReconciliationResult.incomplete(
          'configured relay set does not match the target',
        );
      }
      return const _RelayReconciliationResult.complete();
    } catch (e) {
      if (!_operationIsCurrent(attachment, transaction, transactionVersion)) {
        return const _RelayReconciliationResult.superseded();
      }
      return _RelayReconciliationResult.incomplete(e.toString());
    }
  }

  bool _operationIsCurrent(
    _RelayClientAttachment attachment,
    _RelayResetTransaction transaction,
    int transactionVersion,
  ) {
    final currentAttachment = _attachment;
    return currentAttachment != null &&
        identical(currentAttachment.client, attachment.client) &&
        currentAttachment.generation == attachment.generation &&
        currentAttachment.scope == attachment.scope &&
        identical(_pendingTransaction, transaction) &&
        transaction.version == transactionVersion;
  }

  void _handleReconciliationFailure(
    _RelayResetTransaction transaction,
    int transactionVersion,
  ) {
    if (!identical(_pendingTransaction, transaction) ||
        transaction.version != transactionVersion) {
      _rescheduleAfterOperation = _pendingTransaction != null;
      return;
    }
    if (!transaction.reconciliationRetryUsed) {
      transaction.reconciliationRetryUsed = true;
      _rescheduleAfterOperation = true;
      return;
    }

    Log.error(
      'Relay target remains pending after bounded reconciliation retry',
      name: 'RelaySetChangeBridge',
      category: LogCategory.relay,
    );
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
  }
}

@immutable
class _RelayIntentScope {
  const _RelayIntentScope({
    required this.defaultRelayUrl,
    required this.identityPubkey,
  });

  final String defaultRelayUrl;
  final String? identityPubkey;

  @override
  bool operator ==(Object other) {
    return other is _RelayIntentScope &&
        other.defaultRelayUrl == defaultRelayUrl &&
        other.identityPubkey == identityPubkey;
  }

  @override
  int get hashCode => Object.hash(defaultRelayUrl, identityPubkey);
}

class _RelayClientAttachment {
  const _RelayClientAttachment({
    required this.client,
    required this.videoEventService,
    required this.initializationTracker,
    required this.scope,
    required this.generation,
  });

  final NostrClient client;
  final VideoEventService videoEventService;
  final NostrInitializationInProgress initializationTracker;
  final _RelayIntentScope scope;
  final int generation;

  _RelayClientAttachment copyWith({
    required VideoEventService videoEventService,
    required NostrInitializationInProgress initializationTracker,
    required _RelayIntentScope scope,
  }) {
    return _RelayClientAttachment(
      client: client,
      videoEventService: videoEventService,
      initializationTracker: initializationTracker,
      scope: scope,
      generation: generation,
    );
  }
}

class _RelayResetTransaction {
  _RelayResetTransaction({
    required this.scope,
    required this.sourceClient,
    required this.targetRelaySet,
    required this.version,
  });

  final _RelayIntentScope scope;
  final NostrClient sourceClient;
  Set<String> targetRelaySet;
  int version;
  bool reconciliationRetryUsed = false;
}

enum _RelayReconciliationStatus { complete, incomplete, superseded }

class _RelayReconciliationResult {
  const _RelayReconciliationResult.complete()
    : status = _RelayReconciliationStatus.complete,
      error = null;

  const _RelayReconciliationResult.incomplete(this.error)
    : status = _RelayReconciliationStatus.incomplete;

  const _RelayReconciliationResult.superseded()
    : status = _RelayReconciliationStatus.superseded,
      error = null;

  final _RelayReconciliationStatus status;
  final String? error;
}

/// Connection status service for monitoring network connectivity
@Riverpod(keepAlive: true)
ConnectionStatusService connectionStatusService(Ref ref) {
  final service = ConnectionStatusService();
  ref.onDispose(service.dispose);
  return service;
}

/// Relay capability service for detecting NIP-11 Divine extensions
@Riverpod(keepAlive: true)
RelayCapabilityService relayCapabilityService(Ref ref) {
  // The service's dispose() only clears its cache, so the injected client is
  // closed here.
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final service = RelayCapabilityService(httpClient: httpClient);
  ref.onDispose(service.dispose);
  ref.onDispose(httpClient.close);
  return service;
}

/// Relay statistics service for tracking per-relay metrics
@Riverpod(keepAlive: true)
RelayStatisticsService relayStatisticsService(Ref ref) {
  final service = RelayStatisticsService();
  ref.onDispose(service.dispose);
  return service;
}

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change
@riverpod
Stream<Map<String, RelayStatistics>> relayStatisticsStream(Ref ref) async* {
  final service = ref.watch(relayStatisticsServiceProvider);

  // Emit current state immediately
  yield service.getAllStatistics();

  // Create a stream controller to emit updates on notifyListeners
  final controller = StreamController<Map<String, RelayStatistics>>();

  void listener() {
    if (!controller.isClosed) {
      controller.add(service.getAllStatistics());
    }
  }

  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
    controller.close();
  });

  yield* controller.stream;
}

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Activated by `AppShellSideEffects` — the 3s counter timer is recurring
/// work a signed-out user should not pay for.
@Riverpod(keepAlive: true)
void relayStatisticsBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final statsService = ref.watch(relayStatisticsServiceProvider);

  // Track previous states to detect connection changes
  final Map<String, bool> previousStates = {};

  // Helper to process status updates (used for both initial state and stream)
  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    for (final entry in statuses.entries) {
      final url = entry.key;
      final status = entry.value;
      final wasConnected = previousStates[url] ?? false;
      final isConnected =
          status.isConnected || status.state == RelayState.authenticated;

      // Only record changes to avoid excessive updates
      if (isConnected && !wasConnected) {
        statsService.recordConnection(url);
      } else if (!isConnected && wasConnected) {
        statsService.recordDisconnection(url, reason: status.errorMessage);
      }

      previousStates[url] = isConnected;
    }

    // Prune entries for relays no longer in the status map
    previousStates.removeWhere((url, _) => !statuses.containsKey(url));
  }

  // Process current state immediately (relays may have connected before
  // the bridge started)
  processStatuses(nostrService.relayStatuses);

  // Listen to relay status stream for future connection changes
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  // Periodically sync per-relay SDK counters so each relay shows its own
  // real statistics (not identical values distributed from app-level totals).
  final syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
    final counters = nostrService.getRelayPoolCounters();
    for (final entry in counters.entries) {
      statsService.syncSdkCounters(
        entry.key,
        eventsReceived: entry.value.eventsReceived,
        queriesSent: entry.value.queriesSent,
        errors: entry.value.errors,
      );
    }
  });

  ref.onDispose(() {
    syncTimer.cancel();
    subscription.cancel();
  });
}

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.
@Riverpod(keepAlive: true)
void relaySetChangeBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final coordinator = ref.watch(_relaySetChangeCoordinatorProvider);

  Set<String> previousRelaySet = nostrService.relayStatuses.keys.toSet();
  var disposed = false;
  final initializationTracker = ref.read(
    nostrInitializationInProgressProvider.notifier,
  );
  void attachWithIdentity(String? identityPubkey) {
    coordinator.attach(
      client: nostrService,
      identityPubkey: identityPubkey,
      videoEventService: videoEventService,
      initializationTracker: initializationTracker,
    );
  }

  attachWithIdentity(ref.read(nostrSessionProvider).pubkey);
  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    attachWithIdentity(next.pubkey);
  });

  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    ref
        .read(configuredRelayUrlsProvider.notifier)
        .setUrls(statuses.keys.toList(growable: false));

    final currentRelaySet = statuses.keys.toSet();

    // Only trigger if the set of relay URLs has changed (not just status)
    if (!_setsEqual(currentRelaySet, previousRelaySet)) {
      Log.info(
        'Relay set changed: '
        '${previousRelaySet.length} -> ${currentRelaySet.length} relays',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );

      final priorRelaySet = previousRelaySet;
      previousRelaySet = currentRelaySet;

      final changeRequiresReset = !coordinator.isClientInitializing(
        nostrService,
      );

      // Debounce: collapse rapid changes into a single reset
      coordinator.recordMembershipChange(
        client: nostrService,
        previousRelaySet: priorRelaySet,
        currentRelaySet: currentRelaySet,
        changeRequiresReset: changeRequiresReset,
      );
    }
  }

  // Publish the initial relay set after provider initialization. Riverpod
  // disallows mutating another provider while this bridge is building.
  Timer.run(() {
    if (disposed) return;
    ref
        .read(configuredRelayUrlsProvider.notifier)
        .setUrls(nostrService.relayStatuses.keys.toList(growable: false));
  });

  // Listen to relay status stream for future updates
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  ref.onDispose(() {
    disposed = true;
    subscription.cancel();
  });
}

/// Helper to compare two sets for equality
bool _setsEqual<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// `connectivity_plus` reports, as a seam for tests.
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// A one-off `connectivity_plus` check, as a seam for tests.
final connectivityCheckProvider =
    Provider<Future<List<ConnectivityResult>> Function()>(
      (ref) => Connectivity().checkConnectivity,
    );

/// The one app-wide owner of connectivity-driven relay repair, so a pool that
/// collapsed during an offline window self-heals on every route, not only on
/// an app-foreground transition (#3161).
///
/// It subscribes once and never rebuilds: it watches only its two seams and
/// reads the current client when a repair fires. Re-subscribing replayed the
/// current state, which read as a reconnect and tore healthy sockets down
/// after every launch and sign-in (#8990). A repair waits while that client
/// is still initializing, and the transitions it emits drive the DM retry
/// sweep. keepAlive with no UI consumer: activated by `AppRootSideEffects`.
final connectivityRelayReconnectProvider =
    Provider<Stream<ConnectivityTransition>>((ref) {
      final monitor = ConnectivityTransitionMonitor(
        changes: ref.watch(connectivityChangesProvider),
        checkConnectivity: ref.watch(connectivityCheckProvider),
        repair: () async {
          await ref.read(nostrServiceProvider).forceReconnectAll();
          Log.info(
            'Reconnected relays after a connectivity change',
            name: 'ConnectivityRelayReconnect',
            category: LogCategory.relay,
          );
        },
        canRepair: () => !ref
            .read(nostrInitializationInProgressProvider.notifier)
            .isClientInitializing(ref.read(nostrServiceProvider)),
      )..start();
      ref.onDispose(monitor.dispose);
      return monitor.transitions;
    });
