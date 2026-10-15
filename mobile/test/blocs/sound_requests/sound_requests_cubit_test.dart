import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

void main() {
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
}
