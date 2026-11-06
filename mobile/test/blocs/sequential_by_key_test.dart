import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/sequential_by_key.dart';

class _Work {
  _Work(this.key, this.label);

  final String key;
  final String label;
  final Completer<void> gate = Completer<void>();
}

/// Runs each [_Work] until its gate opens, logging when it starts and ends.
class _KeyedBloc extends Bloc<_Work, int> {
  _KeyedBloc(List<String> log) : super(0) {
    on<_Work>((work, emit) async {
      log.add('start ${work.label}');
      await work.gate.future;
      log.add('end ${work.label}');
      emit(state + 1);
    }, transformer: sequentialByKey((work) => work.key));
  }
}

void main() {
  group('sequentialByKey', () {
    late List<String> log;
    late List<_Work> created;
    late _KeyedBloc bloc;

    _Work work(String key, String label) {
      final work = _Work(key, label);
      created.add(work);
      return work;
    }

    setUp(() {
      log = [];
      created = [];
      bloc = _KeyedBloc(log);
    });

    // Release every gate so no handler is left pending after the test.
    tearDown(() async {
      for (final work in created) {
        if (!work.gate.isCompleted) work.gate.complete();
      }
      if (!bloc.isClosed) await bloc.close();
    });

    test('runs an event for another key while one is in flight', () async {
      final a = work('a', 'a1');
      final b = work('b', 'b1');

      bloc
        ..add(a)
        ..add(b);
      await pumpEventQueue();
      b.gate.complete();
      await pumpEventQueue();

      expect(log, ['start a1', 'start b1', 'end b1']);
    });

    test('runs events for the same key one at a time, in order', () async {
      final first = work('a', 'a1');
      final second = work('a', 'a2');

      bloc
        ..add(first)
        ..add(second);
      await pumpEventQueue();
      expect(log, ['start a1']);

      first.gate.complete();
      second.gate.complete();
      await pumpEventQueue();

      expect(log, ['start a1', 'end a1', 'start a2', 'end a2']);
    });

    test('drops no event queued behind one in flight', () async {
      final works = [for (var i = 1; i <= 3; i++) work('a', 'a$i')];

      works.forEach(bloc.add);
      await pumpEventQueue();
      for (final work in works) {
        work.gate.complete();
      }
      await pumpEventQueue();

      expect(bloc.state, 3);
    });

    test('discards an event still queued when the bloc closes', () async {
      final inFlight = work('a', 'a1');
      final queued = work('a', 'a2')..gate.complete();

      bloc
        ..add(inFlight)
        ..add(queued);
      await pumpEventQueue();
      await bloc.close();
      inFlight.gate.complete();
      await pumpEventQueue();

      expect(log, ['start a1', 'end a1']);
    });
  });
}
