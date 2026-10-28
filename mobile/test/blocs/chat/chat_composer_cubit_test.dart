import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/chat/chat_composer_cubit.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  group(ChatComposerCubit, () {
    group('submit', () {
      test('keeps a changed draft while a send is pending', () async {
        final pending = Completer<bool>();
        final bodies = <String>[];
        final cubit = ChatComposerCubit(
          send: (body) {
            bodies.add(body);
            return pending.future;
          },
        );
        addTearDown(cubit.close);
        cubit.updateDraft('first', 5);
        final sent = cubit.submit();
        expect(cubit.state.submitting, isTrue);
        cubit.updateDraft('second', 6);
        expect(await cubit.submit(), isFalse);
        pending.complete(true);
        expect(await sent, isFalse);
        expect(bodies, ['first']);
        expect(cubit.state.text, 'second');
        expect(cubit.state.submitting, isFalse);
      });

      test(
        'retains the draft and reports non-Exception send failures',
        () async {
          final cubit = ChatComposerCubit(
            send: (_) async => throw StateError('failed'),
          );
          addTearDown(cubit.close);
          cubit.updateDraft('hello', 5);
          expect(await cubit.submit(), isFalse);
          expect(cubit.state.text, 'hello');
          expect(cubit.state.sendFailed, isTrue);
          expect(cubit.state.submitting, isFalse);
        },
      );

      test(
        'edited picks stay plain text and literal references survive',
        () async {
          final key = 'a' * 64;
          final reference = 'nostr:${NostrKeyUtils.encodePubKey(key)}';
          final bodies = <String>[];
          final cubit = ChatComposerCubit(
            send: (body) async {
              bodies.add(body);
              return true;
            },
          );
          addTearDown(cubit.close);
          cubit.updateDraft('@Al', 3);
          final insertion = cubit.selectMention(
            cursor: 3,
            pubkey: key,
            display: 'Alice',
          );
          expect(insertion, isNotNull);
          cubit.updateDraft('@Alicia $reference', 7);
          expect(await cubit.submit(), isTrue);
          expect(bodies, ['@Alicia $reference']);
          expect(cubit.state.text, isEmpty);
          expect(cubit.state.mentions, isEmpty);
        },
      );

      test('closing during a send does not emit into a closed Cubit', () async {
        final pending = Completer<bool>();
        final cubit = ChatComposerCubit(send: (_) => pending.future);
        cubit.updateDraft('hello', 5);
        final sent = cubit.submit();
        await cubit.close();
        pending.complete(true);
        expect(await sent, isFalse);
      });
    });
  });
}
