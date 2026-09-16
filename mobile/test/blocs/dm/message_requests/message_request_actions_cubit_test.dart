// ABOUTME: Tests for MessageRequestActionsCubit - decline, mark-all-read,
// ABOUTME: and remove-all actions for message requests.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

const _me = '1111111111111111111111111111111111111111111111111111111111111111';
const _stranger =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _moderation =
    '3333333333333333333333333333333333333333333333333333333333333333';

DmConversation _conversation(String id, {required String peer}) =>
    DmConversation(
      id: id,
      participantPubkeys: [_me, peer],
      isGroup: false,
      createdAt: 0,
    );

void main() {
  group(MessageRequestActionsCubit, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(_me);
      when(() => mockDmRepository.getConversation(any())).thenAnswer(
        (invocation) async => _conversation(
          invocation.positionalArguments.first as String,
          peer: _stranger,
        ),
      );
    });

    MessageRequestActionsCubit createCubit() =>
        MessageRequestActionsCubit(dmRepository: mockDmRepository);

    test('reports removed but does not emit when closed mid-decline', () async {
      final completer = Completer<ConversationRemovalOutcome>();
      when(
        () => mockDmRepository.removeConversation(_testConversationId1),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      final future = cubit.declineRequest(_testConversationId1);
      // processing emitted synchronously; close before the delete resolves.
      await cubit.close();
      completer.complete(ConversationRemovalOutcome.removed);

      // The removal completed, so the caller sees `removed` even though the
      // guarded `success` emit was skipped. A state read would still show
      // `processing` and wrongly report failure (#7881 review, finding 5).
      expect(await future, DeclineRequestOutcome.removed);
      expect(cubit.state.status, MessageRequestActionsStatus.processing);
    });

    test('initial state has idle status', () async {
      final cubit = createCubit();

      expect(cubit.state.status, equals(MessageRequestActionsStatus.idle));

      await cubit.close();
    });

    group('declineRequest', () {
      test('reports removed when removeConversation succeeds', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenAnswer((_) async => ConversationRemovalOutcome.removed);

        final cubit = createCubit();
        expect(
          await cubit.declineRequest(_testConversationId1),
          DeclineRequestOutcome.removed,
        );

        await cubit.close();
      });

      test('reports failed when removeConversation throws', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenThrow(Exception('db failure'));

        final cubit = createCubit();
        // The failed outcome is what drives the caller's error snackbar; the
        // widget tests stub the mock, so this is the only coverage of the
        // real catch-returns-failed contract (#7881 review, finding 5).
        expect(
          await cubit.declineRequest(_testConversationId1),
          DeclineRequestOutcome.failed,
        );

        await cubit.close();
      });

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when removeConversation succeeds',
        setUp: () {
          when(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).thenAnswer((_) async => ConversationRemovalOutcome.removed);
        },
        build: createCubit,
        act: (cubit) => cubit.declineRequest(_testConversationId1),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when removeConversation throws',
        setUp: () {
          when(
            () => mockDmRepository.removeConversation(_testConversationId1),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.declineRequest(_testConversationId1),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    group('markAllRequestsAsRead', () {
      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when markConversationsAsRead succeeds',
        setUp: () {
          when(
            () => mockDmRepository.markConversationsAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([
          _testConversationId1,
          _testConversationId2,
        ]),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationsAsRead([
              _testConversationId1,
              _testConversationId2,
            ]),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'does not emit when conversationIds is empty',
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([]),
        expect: () => const <MessageRequestActionsState>[],
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when markConversationsAsRead throws',
        setUp: () {
          when(
            () => mockDmRepository.markConversationsAsRead(any()),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.markAllRequestsAsRead([_testConversationId1]),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    group('removeAllRequests', () {
      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, success] when removeConversations succeeds',
        setUp: () {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenAnswer((_) async => (removed: 2, refused: 0));
        },
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([
          _conversation(_testConversationId1, peer: _stranger),
          _conversation(_testConversationId2, peer: _stranger),
        ]),
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.removeConversations([
              _testConversationId1,
              _testConversationId2,
            ]),
          ).called(1);
        },
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'does not emit when the conversation list is empty',
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([]),
        expect: () => const <MessageRequestActionsState>[],
      );

      blocTest<MessageRequestActionsCubit, MessageRequestActionsState>(
        'emits [processing, error] when removeConversations throws',
        setUp: () {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenThrow(Exception('db failure'));
        },
        build: createCubit,
        act: (cubit) => cubit.removeAllRequests([
          _conversation(_testConversationId1, peer: _stranger),
        ]),
        errors: () => [isA<Exception>()],
        expect: () => [
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.error,
          ),
        ],
      );
    });

    // The policy itself now lives in DmRepository, so every removal path
    // inherits it rather than each cubit re-deciding (#8391). What is left to
    // pin here is the translation: a refusal must not read as a failure, and
    // a withheld row must still be reported to the caller (#8347).
    group('moderation protection', () {
      test('reports refused when the repository protects the row', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenAnswer((_) async => ConversationRemovalOutcome.refused);

        final cubit = createCubit();

        expect(
          await cubit.declineRequest(_testConversationId1),
          DeclineRequestOutcome.refused,
        );

        await cubit.close();
      });

      test('reports removed when the repository allows it', () async {
        when(
          () => mockDmRepository.removeConversation(_testConversationId1),
        ).thenAnswer((_) async => ConversationRemovalOutcome.removed);

        final cubit = createCubit();

        expect(
          await cubit.declineRequest(_testConversationId1),
          DeclineRequestOutcome.removed,
        );

        await cubit.close();
      });

      test('passes every id to the repository and lets it filter', () async {
        // The cubit must NOT pre-filter: doing so is what let the inbox path
        // inherit no guard at all (#8391).
        when(
          () => mockDmRepository.removeConversations(any()),
        ).thenAnswer((_) async => (removed: 1, refused: 1));

        final cubit = createCubit();

        await cubit.removeAllRequests([
          _conversation(_testConversationId1, peer: _stranger),
          _conversation(_testConversationId2, peer: _moderation),
        ]);

        verify(
          () => mockDmRepository.removeConversations([
            _testConversationId1,
            _testConversationId2,
          ]),
        ).called(1);

        await cubit.close();
      });

      // The sweep was silent about what it kept, so the guard was invisible in
      // the bulk path: with only a notice in the list it removed nothing,
      // emitted nothing, and the button looked broken (#8347).
      test('removeAllRequests reports the notice it withheld', () async {
        when(
          () => mockDmRepository.removeConversations(any()),
        ).thenAnswer((_) async => (removed: 1, refused: 1));

        final cubit = createCubit();

        expect(
          await cubit.removeAllRequests([
            _conversation(_testConversationId1, peer: _stranger),
            _conversation(_testConversationId2, peer: _moderation),
          ]),
          (withheld: true, failed: false),
        );

        await cubit.close();
      });

      test('removeAllRequests reports a sweep that removed nothing '
          'at all', () async {
        when(
          () => mockDmRepository.removeConversations(any()),
        ).thenAnswer((_) async => (removed: 0, refused: 1));

        final cubit = createCubit();

        expect(
          await cubit.removeAllRequests([
            _conversation(_testConversationId1, peer: _moderation),
          ]),
          (withheld: true, failed: false),
        );

        await cubit.close();
      });

      test(
        'removeAllRequests reports nothing withheld from a clean sweep',
        () async {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenAnswer((_) async => (removed: 1, refused: 0));

          final cubit = createCubit();

          expect(
            await cubit.removeAllRequests([
              _conversation(_testConversationId1, peer: _stranger),
            ]),
            (withheld: false, failed: false),
          );

          await cubit.close();
        },
      );

      // `removeConversations` is transactional, so a throw leaves every row in
      // place. Folding that into the withheld flag would tell the user the
      // notice was the reason a sweep that removed nothing removed nothing.
      test(
        'removeAllRequests separates a failed sweep from the row it withheld',
        () async {
          when(
            () => mockDmRepository.removeConversations(any()),
          ).thenThrow(Exception('drift is down'));

          final cubit = createCubit();

          expect(
            await cubit.removeAllRequests([
              _conversation(_testConversationId1, peer: _stranger),
              _conversation(_testConversationId2, peer: _moderation),
            ]),
            (withheld: false, failed: true),
          );

          await cubit.close();
        },
      );
    });

    group('$MessageRequestActionsState', () {
      test('supports value equality', () {
        const state1 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        const state2 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );

        expect(state1, equals(state2));
      });

      test('states with different status are not equal', () {
        const state1 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        const state2 = MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('copyWith returns same object when no parameters provided', () {
        const state = MessageRequestActionsState(
          status: MessageRequestActionsStatus.processing,
        );
        final updated = state.copyWith();

        expect(updated.status, equals(MessageRequestActionsStatus.processing));
      });

      test('copyWith replaces status', () {
        const state = MessageRequestActionsState();
        final updated = state.copyWith(
          status: MessageRequestActionsStatus.processing,
        );

        expect(updated.status, equals(MessageRequestActionsStatus.processing));
      });

      test('props contains status', () {
        const state = MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        );

        expect(state.props, [MessageRequestActionsStatus.success]);
      });
    });
  });
}
