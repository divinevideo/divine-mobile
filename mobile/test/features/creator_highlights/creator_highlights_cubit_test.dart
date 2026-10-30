import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_cubit.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_repository.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _card = CreatorHighlight(
  owner: _owner,
  localDate: '2026-10-30',
  createdToday: 1,
  creationDaysThisWeek: 2,
  views: null,
  topVideo: null,
  celebrate: true,
);

class _Repository implements CreatorHighlightsRepository {
  final pending = Completer<CreatorHighlight?>();
  final next = Completer<CreatorHighlight?>();
  int loads = 0;
  final presented = <(String, String)>[];

  @override
  Future<CreatorHighlight?> load(String owner) {
    loads++;
    return loads == 1 ? pending.future : next.future;
  }

  @override
  Future<void> markPresented(String owner, String localDate) async {
    presented.add((owner, localDate));
  }
}

void main() {
  group('refresh', () {
    test(
      'a request crossing midnight retries before publishing dated copy',
      () async {
        var now = DateTime(2026, 10, 30, 23, 59);
        final repository = _Repository();
        final cubit = CreatorHighlightsCubit(
          repository: repository,
          owner: _owner,
          now: () => now,
        );
        final cards = <CreatorHighlight?>[];
        final subscription = cubit.stream.listen(
          (state) => cards.add(state.card),
        );
        final first = cubit.refresh();
        now = DateTime(2026, 10, 31);
        final midnight = cubit.refresh();
        repository.pending.complete(_card);
        await pumpEventQueue();
        expect(repository.loads, 2);
        expect(cubit.state.card, isNull);
        const next = CreatorHighlight(
          owner: _owner,
          localDate: '2026-10-31',
          createdToday: 0,
          creationDaysThisWeek: 2,
          views: null,
          topVideo: null,
          celebrate: true,
        );
        repository.next.complete(next);
        await Future.wait([first, midnight]);
        expect(cubit.state.card, next);
        expect(
          cards.whereType<CreatorHighlight>().every(
            (card) => card.localDate == '2026-10-31',
          ),
          isTrue,
        );
        await subscription.cancel();
        await cubit.close();
      },
    );

    test('refresh immediately withholds a previous-day card', () async {
      var now = DateTime(2026, 10, 30, 23, 59);
      final repository = _Repository();
      final cubit = CreatorHighlightsCubit(
        repository: repository,
        owner: _owner,
        now: () => now,
      );
      repository.pending.complete(_card);
      await cubit.refresh();
      expect(cubit.state.card, _card);
      now = DateTime(2026, 10, 31);
      final load = cubit.refresh();
      expect(cubit.state.card, isNull);
      repository.next.complete(_card);
      await load;
      expect(
        cubit.state.card,
        isNull,
        reason: 'A stale source cannot reintroduce yesterday as today.',
      );
      await cubit.close();
    });

    test('coalesces refreshes and exposes the loaded account card', () async {
      final repository = _Repository();
      final cubit = CreatorHighlightsCubit(
        repository: repository,
        owner: _owner,
      );
      final first = cubit.refresh();
      final second = cubit.refresh();
      repository.pending.complete(_card);
      await Future.wait([first, second]);
      expect(repository.loads, 1);
      expect(cubit.state.card, _card);
      await cubit.close();
    });

    test('closing an old account discards its pending result', () async {
      final repository = _Repository();
      final cubit = CreatorHighlightsCubit(
        repository: repository,
        owner: _owner,
      );
      final load = cubit.refresh();
      await cubit.close();
      repository.pending.complete(_card);
      await load;
      expect(cubit.state.card, isNull);
      expect(repository.presented, isEmpty);
    });

    test(
      'failure leaves notifications usable without a fabricated card',
      () async {
        final repository = _Repository();
        final cubit = CreatorHighlightsCubit(
          repository: repository,
          owner: _owner,
          now: () => DateTime(2026, 10, 30),
        );
        final load = cubit.refresh();
        repository.pending.completeError(StateError('Source unavailable'));
        await load;
        expect(cubit.state.card, isNull);
        expect(cubit.state.loading, isFalse);
        await cubit.close();
      },
    );
  });

  group('presented', () {
    test(
      'presentation acknowledges only the loaded owner and date once',
      () async {
        final repository = _Repository();
        final cubit = CreatorHighlightsCubit(
          repository: repository,
          owner: _owner,
          now: () => DateTime(2026, 10, 30),
        );
        repository.pending.complete(_card);
        await cubit.refresh();
        await cubit.presented(_card);
        await cubit.presented(_card);
        expect(repository.presented, [(_owner, '2026-10-30')]);
        expect(
          cubit.state.card?.celebrate,
          isFalse,
          reason: 'Remounts must not replay a consumed celebration.',
        );
        await cubit.close();
      },
    );
  });
}
