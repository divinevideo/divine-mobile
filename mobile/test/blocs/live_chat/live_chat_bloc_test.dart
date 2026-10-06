import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/repositories/live_chat_repository.dart';

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

void main() {
  group('LiveChatBloc', () {
    late _MockLiveChatRepository mockRepository;
    late StreamController<List<LiveChatMessage>> messagesController;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const sessionAddress = '30313:$hostPubkey:session-abc';
    const nextSessionAddress = '30313:$hostPubkey:session-def';
    final firstMessage = LiveChatMessage(
      id: '1' * 64,
      sessionAddress: sessionAddress,
      pubkey: hostPubkey,
      content: 'First message',
      createdAt: DateTime.utc(2026, 4, 6, 12),
    );
    final secondMessage = LiveChatMessage(
      id: '2' * 64,
      sessionAddress: nextSessionAddress,
      pubkey: hostPubkey,
      content: 'Second message',
      createdAt: DateTime.utc(2026, 4, 6, 12, 1),
    );
    final sentMessage = LiveChatMessage(
      id: '3' * 64,
      sessionAddress: sessionAddress,
      pubkey: hostPubkey,
      content: 'Hello room',
      createdAt: DateTime.utc(2026, 4, 6, 12, 2),
    );

    setUp(() {
      mockRepository = _MockLiveChatRepository();
      messagesController = StreamController<List<LiveChatMessage>>.broadcast(
        sync: true,
      );

      when(
        () => mockRepository.watchChatMessages(sessionAddress: sessionAddress),
      ).thenAnswer((_) => messagesController.stream);
      when(
        () => mockRepository.watchChatMessages(
          sessionAddress: nextSessionAddress,
        ),
      ).thenAnswer((_) => const Stream<List<LiveChatMessage>>.empty());
      when(
        () => mockRepository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        ),
      ).thenAnswer((_) async => sentMessage);
    });

    tearDown(() async {
      await messagesController.close();
    });

    test('start subscribes to chat updates and exposes ready state', () async {
      final bloc = LiveChatBloc(liveChatRepository: mockRepository);

      bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
      await _flush();

      messagesController.add(<LiveChatMessage>[firstMessage]);
      await _flush();

      expect(bloc.state.status, LiveChatStatus.ready);
      expect(bloc.state.sessionAddress, sessionAddress);
      expect(bloc.state.messages, <LiveChatMessage>[firstMessage]);

      verify(
        () => mockRepository.watchChatMessages(sessionAddress: sessionAddress),
      ).called(1);

      await bloc.close();
    });

    test('send request trims content and publishes the message', () async {
      final bloc = LiveChatBloc(liveChatRepository: mockRepository);

      bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
      await _flush();

      messagesController.add(<LiveChatMessage>[firstMessage]);
      await _flush();

      bloc.add(const LiveChatMessageSendRequested('  Hello room  '));
      await _flush();

      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.errorMessage, isNull);
      expect(
        bloc.state.messages,
        <LiveChatMessage>[firstMessage, sentMessage],
      );
      verify(
        () => mockRepository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        ),
      ).called(1);

      await bloc.close();
    });

    test(
      'drops duplicate send requests while a publish is in flight',
      () async {
        final publishCompleter = Completer<LiveChatMessage?>();
        when(
          () => mockRepository.publishMessage(
            sessionAddress: sessionAddress,
            content: 'Hello room',
          ),
        ).thenAnswer((_) => publishCompleter.future);

        final bloc = LiveChatBloc(liveChatRepository: mockRepository);

        bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
        await _flush();

        messagesController.add(<LiveChatMessage>[firstMessage]);
        await _flush();

        bloc
          ..add(const LiveChatMessageSendRequested('Hello room'))
          ..add(const LiveChatMessageSendRequested('Hello room'));
        await _flush();

        verify(
          () => mockRepository.publishMessage(
            sessionAddress: sessionAddress,
            content: 'Hello room',
          ),
        ).called(1);

        publishCompleter.complete(sentMessage);
        await _flush();

        expect(bloc.state.isSending, isFalse);
        expect(
          bloc.state.messages,
          <LiveChatMessage>[firstMessage, sentMessage],
        );

        await bloc.close();
      },
    );

    test(
      'session switches clear stale messages and ignore late updates for the old session',
      () async {
        final bloc = LiveChatBloc(liveChatRepository: mockRepository);

        bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
        await _flush();

        messagesController.add(<LiveChatMessage>[firstMessage]);
        await _flush();
        expect(bloc.state.messages, <LiveChatMessage>[firstMessage]);

        bloc.add(const LiveChatStarted(sessionAddress: nextSessionAddress));
        await _flush();

        expect(bloc.state.sessionAddress, nextSessionAddress);
        expect(bloc.state.messages, isEmpty);

        bloc.add(
          LiveChatMessagesUpdated(
            sessionAddress: sessionAddress,
            messages: <LiveChatMessage>[firstMessage],
          ),
        );
        await _flush();

        expect(bloc.state.sessionAddress, nextSessionAddress);
        expect(bloc.state.messages, isEmpty);

        bloc.add(
          LiveChatMessagesUpdated(
            sessionAddress: nextSessionAddress,
            messages: <LiveChatMessage>[secondMessage],
          ),
        );
        await _flush();

        expect(bloc.state.messages, <LiveChatMessage>[secondMessage]);

        await bloc.close();
      },
    );
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
