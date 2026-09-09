// ABOUTME: Unit tests for the conversation_view quoted/own-share resolvers.
// ABOUTME: Covers resolveOwnShareVideoRef and resolveQuotedVideoRef pure fns.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';

void main() {
  const conversationId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const senderPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

  const sharedVideoRef = DmSharedVideoRef(
    coordinateOrId: '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
    videoKind: DmSharedVideoKind.addressableShortVideo,
  );

  const otherVideoRef = DmSharedVideoRef(
    coordinateOrId:
        '5555555555555555555555555555555555555555555555555555555555555555',
    videoKind: DmSharedVideoKind.shortVideo,
  );

  DmMessage buildMessage({
    required String id,
    String? replyToId,
    DmSharedVideoRef? sharedVideoRef,
  }) {
    return DmMessage(
      id: id,
      conversationId: conversationId,
      senderPubkey: senderPubkey,
      content: 'hello',
      createdAt: 1700000000,
      giftWrapId: 'gw-$id',
      replyToId: replyToId,
      sharedVideoRef: sharedVideoRef,
    );
  }

  group('resolveOwnShareVideoRef', () {
    test('returns sharedVideoRef when message is not a reply', () {
      final message = buildMessage(
        id: 'msg-1',
        sharedVideoRef: sharedVideoRef,
      );

      expect(resolveOwnShareVideoRef(message), equals(sharedVideoRef));
    });

    test('returns null when message is a reply even if it self-carries a '
        'sharedVideoRef', () {
      final message = buildMessage(
        id: 'msg-2',
        replyToId: 'parent-1',
        sharedVideoRef: sharedVideoRef,
      );

      expect(resolveOwnShareVideoRef(message), isNull);
    });

    test('returns null when a non-reply message has no sharedVideoRef', () {
      final message = buildMessage(id: 'msg-3');

      expect(resolveOwnShareVideoRef(message), isNull);
    });
  });

  group('resolveQuotedVideoRef', () {
    test('returns null when message is not a reply', () {
      final message = buildMessage(
        id: 'msg-1',
        sharedVideoRef: sharedVideoRef,
      );
      final index = <String, DmMessage>{message.id: message};

      expect(resolveQuotedVideoRef(message, index), isNull);
    });

    test('returns the parent ref when the parent is in the index with a '
        'non-null sharedVideoRef', () {
      final parent = buildMessage(
        id: 'parent-1',
        sharedVideoRef: sharedVideoRef,
      );
      // The reply self-carries a DIFFERENT ref to prove the parent wins.
      final reply = buildMessage(
        id: 'reply-1',
        replyToId: 'parent-1',
        sharedVideoRef: otherVideoRef,
      );
      final index = <String, DmMessage>{
        parent.id: parent,
        reply.id: reply,
      };

      expect(resolveQuotedVideoRef(reply, index), equals(sharedVideoRef));
    });

    test('falls back to the reply own sharedVideoRef when the parent is '
        'absent from the index', () {
      final reply = buildMessage(
        id: 'reply-1',
        replyToId: 'parent-1',
        sharedVideoRef: otherVideoRef,
      );
      final index = <String, DmMessage>{reply.id: reply};

      expect(resolveQuotedVideoRef(reply, index), equals(otherVideoRef));
    });

    test(
      'returns null when neither the parent nor the reply carries a ref',
      () {
        final parent = buildMessage(id: 'parent-1');
        final reply = buildMessage(id: 'reply-1', replyToId: 'parent-1');
        final index = <String, DmMessage>{
          parent.id: parent,
          reply.id: reply,
        };

        expect(resolveQuotedVideoRef(reply, index), isNull);
      },
    );

    test('returns null when the parent is present but has no ref and the '
        'reply has none either', () {
      final parent = buildMessage(id: 'parent-1');
      final reply = buildMessage(id: 'reply-1', replyToId: 'parent-1');
      final index = <String, DmMessage>{
        parent.id: parent,
        reply.id: reply,
      };

      expect(resolveQuotedVideoRef(reply, index), isNull);
    });
  });
}
