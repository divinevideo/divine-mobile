// ABOUTME: Tests parsing collaborator invite DMs from structured tags.
// ABOUTME: Ensures fallback plaintext is never treated as invite metadata.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/collaborator_invite_parser.dart';

void main() {
  const creatorPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const messageId = 'message-id';
  const videoAddress = '34236:$creatorPubkey:video-d-tag';

  DmMessage messageWithTags(
    List<List<String>> tags, {
    String content = 'fallback copy',
  }) {
    return DmMessage(
      id: messageId,
      conversationId: 'conversation-id',
      senderPubkey: creatorPubkey,
      content: content,
      createdAt: 1700000000,
      giftWrapId: 'gift-wrap-id',
      tags: tags,
    );
  }

  group(CollaboratorInviteParser, () {
    test('parses valid structured collaborator invite tags', () {
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
        ['p', creatorPubkey],
        ['role', 'Collaborator'],
        ['title', 'Skate loop'],
        ['thumb', 'https://cdn.example.com/thumb.jpg'],
      ]);

      final invite = CollaboratorInviteParser.parse(message);

      expect(invite, isNotNull);
      expect(invite!.messageId, messageId);
      expect(invite.videoAddress, videoAddress);
      expect(invite.videoKind, 34236);
      expect(invite.creatorPubkey, creatorPubkey);
      expect(invite.videoDTag, 'video-d-tag');
      expect(invite.role, 'Collaborator');
      expect(invite.relayHint, 'wss://relay.divine.video');
      expect(invite.title, 'Skate loop');
      expect(invite.thumbnailUrl, 'https://cdn.example.com/thumb.jpg');
    });

    test('rejects plaintext-only fallback content', () {
      final message = messageWithTags(
        const [],
        content: 'You were invited to collaborate on 34236:$creatorPubkey:d.',
      );

      expect(CollaboratorInviteParser.parse(message), isNull);
    });

    test('requires the structured invite marker tag', () {
      final message = messageWithTags([
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
        ['p', creatorPubkey],
        ['role', 'Collaborator'],
      ]);

      expect(CollaboratorInviteParser.parse(message), isNull);
    });

    test('uses the address pubkey when creator p tag is absent', () {
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
      ]);

      final invite = CollaboratorInviteParser.parse(message);

      expect(invite, isNotNull);
      expect(invite!.creatorPubkey, creatorPubkey);
      expect(invite.role, 'Collaborator');
    });

    test('rejects malformed video addresses', () {
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', 'not-a-video-address', 'wss://relay.divine.video', 'root'],
        ['p', creatorPubkey],
      ]);

      expect(CollaboratorInviteParser.parse(message), isNull);
    });

    test('rejects non-collaborator role tags', () {
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
        ['p', creatorPubkey],
        ['role', 'Producer'],
      ]);

      expect(CollaboratorInviteParser.parse(message), isNull);
    });

    // #3661 — NIP-17 rumors arrive with the recipient p tag at index 0
    // (injected by NIP17MessageService.sendPrivateMessage). The creator
    // p tag the collaborator invitation sender appends comes after. Match by membership.
    test('parses invite when recipient p tag precedes creator p tag', () {
      const recipientPubkey =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
        // Order matches what the wire actually delivers.
        ['p', recipientPubkey],
        ['p', creatorPubkey],
        ['role', 'Collaborator'],
        ['title', 'Skate loop'],
      ]);

      final invite = CollaboratorInviteParser.parse(message);

      expect(invite, isNotNull);
      expect(invite!.creatorPubkey, creatorPubkey);
      expect(invite.title, 'Skate loop');
    });

    test('rejects invite when no p tag matches the address creator', () {
      const recipientPubkey =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      const otherPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final message = messageWithTags([
        ['divine', 'collab-invite'],
        ['a', videoAddress, 'wss://relay.divine.video', 'root'],
        ['p', recipientPubkey],
        ['p', otherPubkey],
        ['role', 'Collaborator'],
      ]);

      expect(CollaboratorInviteParser.parse(message), isNull);
    });
  });
}
