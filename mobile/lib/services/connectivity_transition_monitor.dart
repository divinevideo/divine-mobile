// ABOUTME: Turns connectivity_plus reports into relay-pool repairs and the
// ABOUTME: online/offline transitions the DM retry sweep consumes.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:unified_logger/unified_logger.dart';

/// A network transition that matters to relay connections.
enum ConnectivityTransition {
  /// The device lost its last network interface.
  offline,

  /// The device regained a network, or switched interfaces while online, and
  /// a repair of the relay pool for it has finished, failed or hit its cap.
  online,
}

/// The one owner of connectivity-driven relay repair (#8990).
///
/// A report counts under #6046's rule: offline to online, or a change of
/// transports while online. The current state a fresh subscription replays,
/// and a duplicate report, count as nothing: repairing on them tore healthy
/// sockets down after every launch and sign-in. Offline is reported at once.
/// A repair waits two seconds so a burst of reports collapses into one, waits
/// again while `canRepair` says no, is bounded at fifteen seconds, and runs
/// once more if the network changes meanwhile; `online` follows the last one.
class ConnectivityTransitionMonitor {
  /// Creates a monitor; call [start] to begin listening.
  ConnectivityTransitionMonitor({
    required Stream<List<ConnectivityResult>> changes,
    required Future<List<ConnectivityResult>> Function() checkConnectivity,
    required Future<void> Function() repair,
    bool Function()? canRepair,
    Duration repairDebounce = const Duration(seconds: 2),
    Duration repairCap = const Duration(seconds: 15),
  }) : _changes = changes,
       _checkConnectivity = checkConnectivity,
       _repair = repair,
       _canRepair = canRepair ?? _always,
       _repairDebounce = repairDebounce,
       _repairCap = repairCap;

  final Stream<List<ConnectivityResult>> _changes;
  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Future<void> Function() _repair;
  final bool Function() _canRepair;
  final Duration _repairDebounce;
  final Duration _repairCap;

  final _transitions = StreamController<ConnectivityTransition>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Set<ConnectivityResult>? _current;
  Timer? _debounce;
  bool _repairing = false;
  bool _repairAgain = false;
  bool _disposed = false;

  /// Each transition once; a new listener hears only later ones.
  Stream<ConnectivityTransition> get transitions => _transitions.stream;

  /// Subscribes to reports and seeds the baseline from `checkConnectivity`.
  ///
  /// Whichever arrives first, the seed or a report, becomes the baseline, so
  /// a seed that never resolves cannot stop the monitor listening.
  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _changes.listen(_onReport);
    unawaited(_seed());
  }

  /// Stops listening and cancels a pending repair.
  Future<void> dispose() async {
    _disposed = true;
    _debounce?.cancel();
    _debounce = null;
    await _subscription?.cancel();
    await _transitions.close();
  }

  Future<void> _seed() async {
    try {
      final results = await _checkConnectivity();
      _current ??= results.toSet();
    } on Object catch (e) {
      Log.warning(
        'Connectivity seed failed; the first report becomes the baseline: $e',
        name: 'ConnectivityTransitionMonitor',
        category: LogCategory.relay,
      );
    }
  }

  void _onReport(List<ConnectivityResult> results) {
    final next = results.toSet();
    final previous = _current;
    _current = next;
    if (previous == null) return;
    final wasOnline = _isOnline(previous);
    final isOnline = _isOnline(next);
    if (wasOnline && !isOnline) {
      _debounce?.cancel();
      _debounce = null;
      _repairAgain = false;
      _transitions.add(ConnectivityTransition.offline);
    } else if (isOnline && (!wasOnline || !_sameTransports(previous, next))) {
      _scheduleRepair();
    }
  }

  void _scheduleRepair() {
    if (_repairing) {
      _repairAgain = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_repairDebounce, () {
      _debounce = null;
      if (_canRepair()) {
        unawaited(_runRepair());
      } else {
        _scheduleRepair();
      }
    });
  }

  Future<void> _runRepair() async {
    _repairing = true;
    try {
      await _repair().timeout(_repairCap);
    } on Object catch (e) {
      Log.warning(
        'Relay repair after a connectivity change did not finish: $e',
        name: 'ConnectivityTransitionMonitor',
        category: LogCategory.relay,
      );
    }
    _repairing = false;
    if (_disposed) return;
    if (_repairAgain) {
      _repairAgain = false;
      _scheduleRepair();
      return;
    }
    final current = _current;
    if (current != null && _isOnline(current)) {
      _transitions.add(ConnectivityTransition.online);
    }
  }

  static bool _always() => true;

  static bool _isOnline(Set<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  static bool _sameTransports(
    Set<ConnectivityResult> a,
    Set<ConnectivityResult> b,
  ) => a.length == b.length && a.containsAll(b);
}
