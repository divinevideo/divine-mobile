import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:rxdart/rxdart.dart';

/// Processes events that share a key one at a time, in arrival order, while
/// events with different keys run concurrently.
///
/// Meant for events that name a target: `droppable()` checks only whether a
/// handler is running and never reads the event, so an action on one target
/// is lost while another target's is in flight (#8168). Nothing is dropped
/// while the bloc is open. Unlike `sequential()`, `close()` does not wait for
/// the in-flight handler, and events still queued behind it never run. Each
/// key keeps a group open until the bloc closes, so key by something bounded,
/// such as the comments of one thread.
EventTransformer<E> sequentialByKey<E>(Object? Function(E event) keyOf) {
  return (events, mapper) =>
      events.groupBy(keyOf).flatMap((group) => sequential<E>()(group, mapper));
}
