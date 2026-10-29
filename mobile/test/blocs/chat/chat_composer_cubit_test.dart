import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/chat/chat_composer_cubit.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  group(ChatComposerCubit, () {
    group('submit', () {
      test('deleting a pick leaves a pasted identical name plain', () async {
        final bodies = <String>[];
        final cubit = ChatComposerCubit(
          send: (body) async {
            bodies.add(body);
            return true;
          },
        );
        addTearDown(cubit.close);
        cubit.updateDraft('@Al', 3);
        cubit.selectMention(cursor: 3, pubkey: 'a' * 64, display: 'Alice');
        cubit.updateDraft('@Alice @Alice ', 7);
        cubit.updateDraft('@Alice ', 7);

        expect(cubit.state.mentions, isEmpty);
        expect(await cubit.submit(), isTrue);
        expect(bodies, ['@Alice']);
      });

      for (final replaceFirst in [true, false]) {
        test(
          'replacement drops only the selected pick; first: $replaceFirst',
          () async {
            final first = 'a' * 64;
            final second = 'b' * 64;
            final bodies = <String>[];
            final cubit = ChatComposerCubit(
              send: (body) async {
                bodies.add(body);
                return true;
              },
            );
            addTearDown(cubit.close);
            cubit.updateDraft('@Al', 3);
            cubit.selectMention(cursor: 3, pubkey: first, display: 'Alice');
            cubit.updateDraft('@Alice @Al', 10);
            cubit.selectMention(cursor: 10, pubkey: second, display: 'Alice');
            cubit.updateDraft(
              '@Alice @Alice ',
              replaceFirst ? 0 : 13,
              selectionExtent: replaceFirst ? 6 : 7,
            );
            cubit.updateDraft('@Alice @Alice @Alice ', replaceFirst ? 13 : 20);

            expect(await cubit.submit(), isTrue);
            expect(bodies, [
              if (replaceFirst)
                '@Alice @Alice nostr:${NostrKeyUtils.encodePubKey(second)}'
              else
                'nostr:${NostrKeyUtils.encodePubKey(first)} @Alice @Alice',
            ]);
          },
        );
      }

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

      test('repicking the same label replaces the account binding', () async {
        final first = 'a' * 64;
        final second = 'b' * 64;
        final bodies = <String>[];
        final cubit = ChatComposerCubit(
          send: (body) async {
            bodies.add(body);
            return true;
          },
        );
        addTearDown(cubit.close);
        cubit.updateDraft('@Al', 3);
        cubit.selectMention(cursor: 3, pubkey: first, display: 'Alice');
        cubit.selectMention(cursor: 6, pubkey: second, display: 'Alice');
        await cubit.submit();
        expect(bodies, ['nostr:${NostrKeyUtils.encodePubKey(second)}']);
      });

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
