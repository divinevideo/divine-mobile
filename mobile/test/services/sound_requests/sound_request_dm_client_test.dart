import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/sound_requests/sound_request_dm_client.dart';

class _Repository extends Mock implements DmRepository {}

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const recipient =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const rumor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
void main() {
  test(
    'replays stable inputs and joins already delivered application messages',
    () async {
      final repository = _Repository();
      when(() => repository.userPubkey).thenReturn(owner);
      when(() => repository.watchSoundRequestMessages())
          .thenAnswer((_) => Stream.value([]));
      when(
        () => repository.enqueueSend(
          recipientPubkey: recipient,
          content: 'Please enable',
          idempotencyKey: 'stable',
          createdAt: 1,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((_) async => const EnqueueSendResult.enqueued(rumor));
      final client = SoundRequestDmClient(
        repository: repository,
        ownerPubkey: owner,
      );
      final intent = SoundRequestSendIntent(
        key: 'stable',
        recipient: recipient,
        content: 'Please enable',
        tags: soundRequestTags(videoAddress: '34236:$recipient:clip'),
        createdAt: 1,
        videoAddress: '34236:$recipient:clip',
      );
      expect(await client.enqueue(intent), rumor);
      when(() => repository.watchSoundRequestMessages()).thenAnswer(
        (_) => Stream.value([
          DmMessage(
            id: rumor,
            conversationId: 'conversation',
            senderPubkey: owner,
            content: 'Please enable',
            createdAt: 1,
            giftWrapId: rumor,
            tags: const [
              ['batch', 'stable'],
            ],
          ),
        ]),
      );
      expect(await client.enqueue(intent), rumor);
      await client.retry(rumor);
      verifyNever(() => repository.recoverFullSend(rumorId: rumor));
    },
  );
}
