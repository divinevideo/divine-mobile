import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/chat/chat_mention_editing.dart';
import 'package:openvine/models/caption_mention.dart';

void main() {
  final first = CaptionMention(
    display: 'Alice',
    pubkey: 'a' * 64,
    start: 0,
    end: 6,
  );
  final second = CaptionMention(
    display: 'Alice',
    pubkey: 'b' * 64,
    start: 7,
    end: 13,
  );
  group('updateChatMentionBindings', () {
    test('pasting an identical name before a pick shifts the original', () {
      final kept = updateChatMentionBindings(
        before: '@Alice ',
        after: '@Alice @Alice ',
        cursor: 7,
        mentions: [first],
      );
      expect(kept.single.pubkey, first.pubkey);
      expect(kept.single.start, 7);
      expect(kept.single.end, 13);
    });

    test('deleting either identical token removes only its own identity', () {
      final deleteSecond = updateChatMentionBindings(
        before: '@Alice @Alice ',
        after: '@Alice ',
        cursor: 7,
        mentions: [first, second],
      );
      final deleteFirst = updateChatMentionBindings(
        before: '@Alice @Alice ',
        after: '@Alice ',
        cursor: 0,
        mentions: [first, second],
      );
      expect(deleteSecond.map((m) => m.pubkey), [first.pubkey]);
      expect(deleteFirst.map((m) => m.pubkey), [second.pubkey]);
      expect(deleteFirst.single.start, 0);
    });
    test(
      'inserting text ahead shifts identities; editing a token drops it',
      () {
        final shifted = updateChatMentionBindings(
          before: '@Alice @Alice ',
          after: 'hello @Alice @Alice ',
          cursor: 6,
          mentions: [first, second],
        );
        expect(shifted.map((m) => m.start), [6, 13]);
        final edited = updateChatMentionBindings(
          before: '@Alice @Alice ',
          after: '@Alicex @Alice ',
          cursor: 7,
          mentions: [first, second],
        );
        expect(edited.map((m) => m.pubkey), [second.pubkey]);
      },
    );
    for (final mark in ['.', ',', '-', '!', '?', ')']) {
      test('keeps a pick that "$mark" follows', () {
        final kept = updateChatMentionBindings(
          before: '@Alice ',
          after: '@Alice$mark',
          cursor: 7,
          mentions: [first],
        );
        expect(kept.map((m) => m.pubkey), [first.pubkey]);
      });
    }
    for (final glued in ['x', '7', '_']) {
      test('drops a pick that "$glued" runs into', () {
        final kept = updateChatMentionBindings(
          before: '@Alice ',
          after: '@Alice$glued',
          cursor: 7,
          mentions: [first],
        );
        expect(kept, isEmpty);
      });
    }
    test('a letter typed against the @ drops that binding', () {
      final kept = updateChatMentionBindings(
        before: '@Alice @Alice ',
        after: 'x@Alice @Alice ',
        cursor: 1,
        mentions: [first, second],
      );
      expect(kept.map((m) => m.pubkey), [second.pubkey]);
      expect(kept.single.start, 8);
    });
  });
}
