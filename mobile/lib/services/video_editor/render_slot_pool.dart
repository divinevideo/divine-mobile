// ABOUTME: Caps how many preview renders encode natively at the same time,
// ABOUTME: shared by the seam and speed renderers so they never stack up.

import 'dart:async';
import 'dart:collection';

/// Hands out a bounded number of native render slots.
///
/// The preview asks for seam and speed renders on every timeline change. Past
/// a couple of concurrent export sessions the platform encoder stops making
/// progress and `pro_video_editor` fails them with a stall (`progress=0.00`
/// after 20s), which is slower *and* lossier than encoding them a few at a
/// time. Sharing one pool between the seam and speed renderers keeps the
/// combined count under that ceiling.
///
/// Slots are handed out FIFO, except that [acquire] with `priority: true` goes
/// ahead of every non-priority waiter: a transition seam blocks the preview
/// behind its "rendering" overlay, while a speed body only replaces a clip
/// that already plays live-retimed.
class RenderSlotPool {
  /// Creates a pool of [maxConcurrent] slots.
  RenderSlotPool({this.maxConcurrent = 2})
    : assert(maxConcurrent > 0, 'a pool needs at least one slot');

  /// How many renders may hold a slot at the same time.
  final int maxConcurrent;

  int _active = 0;
  final _priorityWaiters = Queue<Completer<void>>();
  final _waiters = Queue<Completer<void>>();

  /// Number of slots currently held.
  int get activeCount => _active;

  /// Resolves once a slot is free. Every successful [acquire] must be paired
  /// with exactly one [release].
  Future<void> acquire({bool priority = false}) {
    if (_active < maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    (priority ? _priorityWaiters : _waiters).add(waiter);
    return waiter.future;
  }

  /// Hands this slot straight to the next waiter, or gives it back to the pool
  /// when nobody is queued. Passing it on keeps [activeCount] at the cap
  /// instead of dipping below it between renders.
  void release() {
    if (_priorityWaiters.isNotEmpty) {
      _priorityWaiters.removeFirst().complete();
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    if (_active > 0) _active--;
  }
}
