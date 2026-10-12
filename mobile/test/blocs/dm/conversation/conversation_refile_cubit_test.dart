// ABOUTME: Tests for ConversationRefileCubit, which reports where an open
// ABOUTME: conversation's messages went when it is taken apart (#10037).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation/conversation_refile_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  group(ConversationRefileCubit, () {
    const conversationId = 'room';
    late _MockDmRepository dmRepository;
    late StreamController<Set<String>> refiled;

    setUp(() {
      dmRepository = _MockDmRepository();
      refiled = StreamController<Set<String>>.broadcast();
      when(
        () => dmRepository.watchRefiledFrom(conversationId),
      ).thenAnswer((_) => refiled.stream);
    });

    tearDown(() => refiled.close());

    ConversationRefileCubit build() => ConversationRefileCubit(
      dmRepository: dmRepository,
      conversationId: conversationId,
    );

    test('starts with nowhere to go', () async {
      final cubit = build();
      addTearDown(cubit.close);

      expect(cubit.state, isEmpty);
    });

    blocTest<ConversationRefileCubit, Set<String>>(
      'emits where the messages went when the conversation is taken apart',
      build: build,
      act: (_) => refiled.add({'one-to-one'}),
      expect: () => [
        {'one-to-one'},
      ],
    );

    test('stops listening once closed', () async {
      final cubit = build();
      expect(refiled.hasListener, isTrue);

      await cubit.close();

      expect(refiled.hasListener, isFalse);
    });
  });
}
