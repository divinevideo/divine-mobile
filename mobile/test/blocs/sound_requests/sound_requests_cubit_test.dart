import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

void main() {
  group('interactions', () {
    test('switching accounts discards an old pending request result', () async {
      final first = _Repository();
      final second = _Repository();
      final pending = Completer<String>();
      when(() => first.ownerPubkey).thenReturn('first');
      when(() => second.ownerPubkey).thenReturn('second');
      for (final repo in [first, second]) {
        when(repo.watchState).thenAnswer((_) => const Stream.empty());
        when(repo.start).thenAnswer((_) async {});
      }
      when(() => first.request('address')).thenAnswer((_) => pending.future);
      final cubit = SoundRequestsCubit();
      addTearDown(cubit.close);
      await cubit.connect(first);
      final sending = cubit.request('address');
      await cubit.connect(second);
      pending.complete('old-request');
      await sending;
      expect(cubit.state.ownerPubkey, 'second');
      expect(cubit.state.operation, SoundRequestOperation.idle);
      expect(cubit.state.snapshot, const SoundRequestSnapshot());
    });

    test(
      'a background reconciliation error does not fail the last action',
      () async {
        final repo = _Repository();
        final updates = StreamController<SoundRequestSnapshot>();
        addTearDown(updates.close);
        when(() => repo.ownerPubkey).thenReturn('owner');
        when(repo.watchState).thenAnswer((_) => updates.stream);
        when(repo.start).thenAnswer((_) async {});
        when(() => repo.request('address')).thenAnswer((_) async => 'request');
        final cubit = SoundRequestsCubit();
        addTearDown(cubit.close);
        await cubit.connect(repo);
        expect(await cubit.request('address'), isTrue);
        updates.addError(const SoundRequestException('offline'));
        await pumpEventQueue();
        expect(cubit.state.target, 'address');
        expect(cubit.state.operation, SoundRequestOperation.sent);
      },
    );
  });
}
