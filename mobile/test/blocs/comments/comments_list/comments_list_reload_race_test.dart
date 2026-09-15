// ABOUTME: Pins that overlapping comment reloads do not orphan a relay
// ABOUTME: subscription, so closing the bloc tears every one of them down.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

String _validId(String suffix) {
  final hexSuffix = suffix.codeUnits
      .map((c) => c.toRadixString(16).padLeft(2, '0'))
      .join();
  return hexSuffix.padLeft(64, '0');
}

void main() {
  group('CommentsListBloc overlapping reloads', () {
    test('closing the bloc leaves no comment subscription listening', () async {
      final repo = _MockCommentsRepository();
      final controllers = <StreamController<Comment>>[];
      // Holds the first teardown open, which is the only window in which a
      // second reload can overlap the one that started it.
      final firstCancelGate = Completer<void>();
      var cancelCalls = 0;

      when(repo.stopWatchingComments).thenAnswer((_) async {});
      when(
        () => repo.loadComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          limit: any(named: 'limit'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) async => CommentThread.empty(_validId('root')));

      when(
        () => repo.watchComments(
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootAddressableId: any(named: 'rootAddressableId'),
          since: any(named: 'since'),
          onEose: any(named: 'onEose'),
          includeVideoReplies: any(named: 'includeVideoReplies'),
        ),
      ).thenAnswer((_) {
        late StreamController<Comment> controller;
        controller = StreamController<Comment>(
          onCancel: () {
            cancelCalls += 1;
            if (cancelCalls == 1) return firstCancelGate.future;
            return null;
          },
        );
        controllers.add(controller);
        return controller.stream;
      });
      addTearDown(() async {
        for (final controller in controllers) {
          if (!controller.isClosed) await controller.close();
        }
      });

      final bloc = CommentsListBloc(
        commentsRepository: repo,
        rootEventId: _validId('root'),
        rootEventKind: 34236,
        rootAuthorPubkey: _validId('author'),
      );

      bloc.add(const CommentsLoadRequested());
      await pumpEventQueue();

      // Second reload: begins tearing the first subscription down.
      bloc.add(const CommentsLoadRequested());
      await pumpEventQueue();

      // Third reload, overlapping the second.
      bloc.add(const CommentsLoadRequested());
      await pumpEventQueue();

      firstCancelGate.complete();
      await pumpEventQueue();

      await bloc.close();
      await pumpEventQueue();

      final stillListening = <int>[
        for (var i = 0; i < controllers.length; i++)
          if (controllers[i].hasListener && !controllers[i].isClosed) i,
      ];

      expect(
        stillListening,
        isEmpty,
        reason:
            'every comment subscription the bloc opened must be torn down by '
            'close(); a surviving one keeps delivering from the relay after '
            'the screen is gone',
      );
    });
  });
}
