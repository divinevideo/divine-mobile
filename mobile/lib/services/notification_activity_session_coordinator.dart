import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:uuid/uuid.dart';

/// Sends only while the captured owner and lifecycle update remain current.
typedef NotificationActivitySend = Future<void> Function(
  String owner,
  NotificationActivityUpdate update,
  bool Function() isCurrent,
);

/// Reports visits and presence independently of analytics and inbox read state.
class NotificationActivitySessionCoordinator {
  NotificationActivitySessionCoordinator({
    required NotificationActivitySend send,
  }) : _send = send;

  static const heartbeatInterval = Duration(seconds: 60);
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const _maximumSequence = 2147483647;

  final NotificationActivitySend _send;
  String? _owner;
  String? _sessionId;
  int _sequence = 0;
  int _visit = 0;
  bool _ready = false;
  bool _foreground = false;
  bool _disposed = false;
  bool _sending = false;
  int _retryCount = 0;
  NotificationActivityUpdate? _pending;
  Timer? _heartbeat;
  Timer? _retry;

  /// Changes signing readiness without inventing a visit on reconnection.
  void setAccount({required String? owner, required bool ready}) {
    if (_disposed) return;
    final changedOwner = owner != _owner;
    final becameReady = ready && !_ready;
    if (changedOwner) {
      _stopTimers();
      _pending = null;
      _owner = owner;
      _sessionId = owner == null ? null : const Uuid().v4();
      _sequence = 0;
      _visit = _foreground ? 1 : 0;
    }
    _ready = ready && owner != null;
    if (!_ready) {
      _stopTimers();
      _pending = null;
    } else if (_foreground && (changedOwner || becameReady)) {
      _emit(NotificationActivityState.foreground);
      _startHeartbeat();
    } else if (becameReady && _visit > 0) {
      _emit(NotificationActivityState.background);
    }
  }

  /// Applies real visibility transitions; transient inactive states stay outside.
  void setForeground(bool foreground) {
    if (_disposed || foreground == _foreground) return;
    _foreground = foreground;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (foreground) {
      if (_visit == _maximumSequence) return;
      _visit++;
    }
    if (!_ready) return;
    if (foreground) {
      _emit(NotificationActivityState.foreground);
      _startHeartbeat();
    } else if (_sequence > 0) {
      _emit(NotificationActivityState.background);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      if (_ready && _foreground) _emit(NotificationActivityState.foreground);
    });
  }

  void _emit(NotificationActivityState state) {
    final sessionId = _sessionId;
    if (_disposed || !_ready || sessionId == null) return;
    // Exhausting an integer sequence cannot grant a new visit allowance.
    if (_sequence == _maximumSequence) {
      _stopTimers();
      return;
    }
    _retry?.cancel();
    _retry = null;
    _retryCount = 0;
    // Offline visits still advance their epoch, even without emitted updates.
    _sequence = _visit > _sequence ? _visit : _sequence + 1;
    _pending = NotificationActivityUpdate(
      sessionId: sessionId,
      sequence: _sequence,
      visit: _visit,
      state: state,
    );
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_sending || _disposed || !_ready) return;
    _sending = true;
    try {
      while (!_disposed && _ready) {
        final update = _pending;
        final owner = _owner;
        if (update == null || owner == null) return;
        bool isCurrent() =>
            !_disposed &&
            _ready &&
            owner == _owner &&
            identical(update, _pending);
        try {
          await _send(owner, update, isCurrent);
          if (isCurrent()) _pending = null;
        } on Object {
          if (!isCurrent()) continue;
          if (_retryCount < _retryDelays.length) {
            _retry = Timer(_retryDelays[_retryCount++], () {
              _retry = null;
              unawaited(_drain());
            });
          }
          return;
        }
      }
    } finally {
      _sending = false;
    }
  }

  void _stopTimers() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _retry?.cancel();
    _retry = null;
  }

  /// Retires signing callbacks and stops all scheduled network work.
  void dispose() {
    _disposed = true;
    _pending = null;
    _stopTimers();
  }
}
