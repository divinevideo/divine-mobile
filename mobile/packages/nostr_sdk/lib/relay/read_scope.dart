// ABOUTME: Groups the reads an owner starts so it can end them all at once,
// ABOUTME: before their deadlines, when it stops (#9472).

import 'dart:async';

/// The reads started inside [run], which their owner can end together, before
/// their deadlines, with [end].
///
/// A read takes the scope of the zone it starts in, so every read anywhere in
/// [run]'s call chain belongs to it, however deep, without a parameter on each
/// read method and each mock of one. The innermost scope wins when they nest.
///
/// Ending a scope ends each of its reads still in flight as its deadline would,
/// with a `CLOSE` to every relay it asked, and makes each read started in it
/// later end before asking any relay.
final class ReadScope {
  static final Object _zoneKey = Object();

  final Set<void Function()> _onEnd = {};
  bool _ended = false;

  /// The scope of the reads started in the current zone, if any.
  static ReadScope? get current => Zone.current[_zoneKey] as ReadScope?;

  /// Whether [end] has been called.
  bool get isEnded => _ended;

  /// Runs [body] so the reads it starts belong to this scope.
  R run<R>(R Function() body) => runZoned(body, zoneValues: {_zoneKey: this});

  /// Ends every read of this scope, now and from now on.
  void end() {
    if (_ended) return;
    _ended = true;
    final callbacks = [..._onEnd];
    _onEnd.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  /// Calls [callback] when this scope ends, at once if it already has, and
  /// returns a function that cancels the call.
  void Function() onEnd(void Function() callback) {
    if (_ended) {
      callback();
      return _noop;
    }
    _onEnd.add(callback);
    return () => _onEnd.remove(callback);
  }

  static void _noop() {
    // Nothing to cancel: the scope had already ended.
  }
}
