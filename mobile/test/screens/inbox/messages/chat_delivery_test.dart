import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

class _Repo extends Mock implements ConcordRepository {}

class _Transport extends Mock implements SealedChatTransport {}

void main() {
  test(
    'uses millisecond remainder and retains a draft on signer failure',
    () async {
      final repo = _Repo();
      when(() => repo.sealedTransport).thenReturn(_Transport());
      when(() => repo.pendingIds).thenReturn([]);
      when(() => repo.timeline(now: any(named: 'now')))
          .thenReturn(FoldedThread([], {}));
      when(
        () => repo.sendSealedMessage(
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          createdAt: any(named: 'createdAt'),
          ms: any(named: 'ms'),
          streamSeedHex: any(named: 'streamSeedHex'),
          streamPubkey: any(named: 'streamPubkey'),
        ),
      ).thenThrow(StateError('signer refused'));
      final cubit = ChatCubit(
        repo,
        sealedAuthor: '01' * 32,
        pocStreamForChannel: (_) => GroupKey('02' * 32, '03' * 32),
        channelIdFor: (_) => '04' * 32,
      );
      addTearDown(cubit.close);
      final accepted = await cubit.send(
        communityId: 'community-test',
        channelId: 'general',
        author: '',
        body: 'keep draft',
        nowMilliseconds: 1700000315123,
      );
      expect(accepted, isFalse);
      expect(cubit.state.sendFailed, isTrue);
      expect(cubit.state.sending, isFalse);
      verify(
        () => repo.sendSealedMessage(
          channelId: '04' * 32,
          author: '01' * 32,
          body: 'keep draft',
          createdAt: 1700000315,
          ms: 123,
          streamSeedHex: '02' * 32,
          streamPubkey: '03' * 32,
        ),
      ).called(1);
    },
  );
}
