import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

class _Repo extends Mock implements ConcordRepository {}

class _Transport extends Mock implements SealedChatTransport {}

class _Errors extends BlocObserver {
  final errors = <Object>[];
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _Relay implements RelayGateway {
  final wraps = StreamController<Map<String, dynamic>>();

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      wraps.stream;

  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _NoLegacyCipher implements StreamCipher {
  @override
  String seal(String plaintext, String streamId) =>
      throw StateError('legacy not supported');

  @override
  String open(String ciphertext, String streamId) =>
      throw StateError('legacy not supported');
}

ConcordRepository _roomOn(_Relay relay) => ConcordRepository(
  relay: relay,
  store: InMemoryConcordStore('a' * 64),
  cipher: _NoLegacyCipher(),
  sealedTransport: SealedChatTransport(
    relay: relay,
    signer: (_) async => throw StateError('signer refused'),
  ),
);

ChatCubit _cubitOver(
  ConcordRepository repository, {
  required bool ownsRepository,
}) => ChatCubit(
  repository,
  sealedAuthor: '01' * 32,
  pocStreamForChannel: (_) => GroupKey('02' * 32, '03' * 32),
  channelIdFor: (_) => '04' * 32,
  ownsRepository: ownsRepository,
);

void main() {
  group('send', () {
    test(
      'clears a failed delivery notice when the pending message arrives',
      () async {
        final repo = _Repo();
        var pending = <String>['01' * 32];
        when(() => repo.pendingIds).thenAnswer((_) => pending);
        when(() => repo.sealedTransport).thenReturn(null);
        when(() => repo.timeline(now: any(named: 'now')))
            .thenReturn(FoldedThread([], {}));
        when(
          () => repo.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenThrow(StateError('relay unavailable'));
        final cubit = ChatCubit(repo);
        addTearDown(cubit.close);
        await cubit.send(
          communityId: 'community-test',
          channelId: 'general',
          author: '02' * 32,
          body: 'message',
          nowMilliseconds: 1700000000000,
        );
        expect(cubit.state.sendFailed, isTrue);
        expect(cubit.state.pendingIds, hasLength(1));
        pending = [];
        cubit.refresh(now: 1700000001);
        expect(cubit.state.pendingIds, isEmpty);
        expect(cubit.state.sendFailed, isFalse);
      },
    );
    test(
      'uses millisecond remainder and retains a draft on signer failure',
      () async {
        final previousObserver = Bloc.observer;
        final observer = _Errors();
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);
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
        expect(observer.errors, hasLength(1));
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

    for (final scenario in [
      'while the room is still loading',
      'after the room failed to load',
    ]) {
      test('is refused $scenario', () async {
        final repo = _Repo();
        when(() => repo.changes).thenAnswer((_) => const Stream.empty());
        when(() => repo.pendingIds).thenReturn([]);
        when(() => repo.sealedTransport).thenReturn(_Transport());
        when(() => repo.timeline(now: any(named: 'now')))
            .thenReturn(FoldedThread([], {}));
        when(
          () => repo.startChannel(
            channelId: any(named: 'channelId'),
            epoch: any(named: 'epoch'),
            streamSeedHex: any(named: 'streamSeedHex'),
            streamPubkey: any(named: 'streamPubkey'),
          ),
        ).thenThrow(StateError('relay unreachable'));
        when(repo.close).thenAnswer((_) async {});
        final cubit = _cubitOver(repo, ownsRepository: true);
        addTearDown(cubit.close);
        final failedToLoad = scenario == 'after the room failed to load';
        if (failedToLoad) await cubit.start();
        expect(
          (cubit.state.loading, cubit.state.loadFailed),
          failedToLoad ? (false, true) : (true, false),
        );

        final accepted = await cubit.send(
          communityId: 'community-test',
          channelId: 'general',
          author: '',
          body: 'too early',
          nowMilliseconds: 1700000315123,
        );

        expect(accepted, isFalse);
        verifyNever(
          () => repo.sendSealedMessage(
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            createdAt: any(named: 'createdAt'),
            ms: any(named: 'ms'),
            streamSeedHex: any(named: 'streamSeedHex'),
            streamPubkey: any(named: 'streamPubkey'),
          ),
        );
      });
    }
  });

  group('close', () {
    test('stops listening to the relay for a room the cubit owns', () async {
      final relay = _Relay();
      final cubit = _cubitOver(_roomOn(relay), ownsRepository: true);
      await cubit.start();
      expect(relay.wraps.hasListener, isTrue);

      await cubit.close();

      expect(relay.wraps.hasListener, isFalse);
    });

    test('leaves a room it was only handed still listening', () async {
      final relay = _Relay();
      final repository = _roomOn(relay);
      addTearDown(repository.close);
      final cubit = _cubitOver(repository, ownsRepository: false);
      await cubit.start();
      expect(relay.wraps.hasListener, isTrue);

      await cubit.close();

      expect(relay.wraps.hasListener, isTrue);
    });
  });
  group('error reporting', () {
    late BlocObserver previousObserver;
    late _Errors observer;
    late StreamController<void> changes;
    late _Repo repo;
    setUp(() {
      previousObserver = Bloc.observer;
      observer = _Errors();
      Bloc.observer = observer;
      changes = StreamController<void>.broadcast();
      repo = _Repo();
      when(() => repo.changes).thenAnswer((_) => changes.stream);
      when(() => repo.pendingIds).thenReturn([]);
      when(
        () => repo.timeline(now: any(named: 'now')),
      ).thenReturn(FoldedThread([], {}));
      when(
        () => repo.startChannel(
          channelId: any(named: 'channelId'),
          epoch: any(named: 'epoch'),
          streamSeedHex: any(named: 'streamSeedHex'),
          streamPubkey: any(named: 'streamPubkey'),
        ),
      ).thenAnswer((_) async {});
    });
    tearDown(() async {
      Bloc.observer = previousObserver;
      await changes.close();
    });

    test('reports a room that fails to start', () async {
      when(
        () => repo.startChannel(
          channelId: any(named: 'channelId'),
          epoch: any(named: 'epoch'),
          streamSeedHex: any(named: 'streamSeedHex'),
          streamPubkey: any(named: 'streamPubkey'),
        ),
      ).thenThrow(StateError('restore failed'));
      final cubit = _cubitOver(repo, ownsRepository: false);
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state.loadFailed, isTrue);
      expect(observer.errors, [isA<StateError>()]);
    });

    test('reports an error from a running room', () async {
      final cubit = _cubitOver(repo, ownsRepository: false);
      addTearDown(cubit.close);
      await cubit.start();
      changes.addError(StateError('room failed'));
      await pumpEventQueue();
      expect(cubit.state.loadFailed, isTrue);
      expect(observer.errors, [isA<StateError>()]);
    });

    test('reports a retry that fails', () async {
      when(
        () => repo.retryPending(messageId: any(named: 'messageId')),
      ).thenThrow(StateError('relay rejected'));
      final cubit = _cubitOver(repo, ownsRepository: false);
      addTearDown(cubit.close);
      await cubit.retry('05' * 32);
      expect(cubit.state.sendFailed, isTrue);
      expect(observer.errors, [isA<StateError>()]);
    });
  });
}
