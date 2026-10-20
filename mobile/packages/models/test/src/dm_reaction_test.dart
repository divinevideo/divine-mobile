import 'package:models/models.dart';
import 'package:test/test.dart';

DmReaction _reaction(DmReactionPublishStatus status) => DmReaction(
  id: 'r',
  conversationId: 'c',
  targetMessageId: 'm',
  targetMessageAuthor: 'a',
  reactorPubkey: 'o',
  emoji: '🔥',
  createdAt: 1700000000,
  ownerPubkey: 'o',
  publishStatus: status,
);

void main() {
  group(DmReaction, () {
    group('isUnsettled', () {
      test('is true while the reaction still needs delivering', () {
        for (final status in [
          DmReactionPublishStatus.pending,
          DmReactionPublishStatus.failed,
          DmReactionPublishStatus.unconfirmed,
        ]) {
          expect(_reaction(status).isUnsettled, isTrue, reason: '$status');
        }
      });

      test('is false once nothing more will be sent', () {
        for (final status in [
          DmReactionPublishStatus.sent,
          DmReactionPublishStatus.blocked,
          DmReactionPublishStatus.removalRefused,
          DmReactionPublishStatus.received,
        ]) {
          expect(_reaction(status).isUnsettled, isFalse, reason: '$status');
        }
      });
    });
  });
}
