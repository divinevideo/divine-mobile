import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

class _Repository extends Mock implements ConcordRepository {}

void main() {
  group('ChatCubit start', () {
    test(
      'reuses shared room initialization without restarting its subscription',
      () async {
        final repo = _Repository();
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        when(() => repo.changes).thenAnswer((_) => changes.stream);
        when(() => repo.pendingIds).thenReturn([]);
        when(() => repo.timeline(now: any(named: 'now')))
            .thenReturn(FoldedThread([], {}));
        var starts = 0;
        final cubit = ChatCubit(
          repo,
          initialize: () async {
            starts++;
          },
        );
        await cubit.start();
        expect(starts, 1);
        expect(cubit.state.loadFailed, isFalse);
        expect(cubit.state.loading, isFalse);
        await cubit.close();
        verifyNever(repo.close);
      },
    );
  });

  group('ChatCubit markRead', () {
    test(
      'read acknowledgement preserves the rendered snapshot on later arrivals',
      () async {
        final repo = _Repository();
        List<ChatMessage>? read;
        final first = ChatMessage(
          id: '01' * 32,
          channelId: 'general',
          author: '02' * 32,
          body: 'seen',
          createdAt: 1,
        );
        final second = ChatMessage(
          id: '03' * 32,
          channelId: 'general',
          author: '02' * 32,
          body: 'arrived later',
          createdAt: 2,
        );
        when(() => repo.pendingIds).thenReturn([]);
        when(() => repo.timeline(now: 2))
            .thenReturn(FoldedThread([first, second], {}));
        final cubit = ChatCubit(
          repo,
          onRead: (messages) async {
            read = messages;
          },
        );
        addTearDown(cubit.close);
        cubit.refresh(now: 2);
        await cubit.markRead([first]);
        expect(read?.map((m) => m.body), ['seen']);
      },
    );

    late Completer<void> gate;

    blocTest<ChatCubit, ChatState>(
      'reports a read write that fails after the room closed',
      setUp: () => gate = Completer<void>(),
      build: () => ChatCubit(
        _Repository(),
        onRead: (_) async {
          await gate.future;
          throw StateError('write unavailable');
        },
      ),
      act: (cubit) async {
        final marking = cubit.markRead([
          ChatMessage(
            id: '01' * 32,
            channelId: 'general',
            author: '02' * 32,
            body: 'seen',
            createdAt: 1,
          ),
        ]);
        await cubit.close();
        gate.complete();
        await marking;
      },
      errors: () => [isA<StateError>()],
    );
  });
}
