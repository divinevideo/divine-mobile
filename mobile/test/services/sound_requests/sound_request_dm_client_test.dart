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
  group('interactions', () {
    test(
      'replays stable inputs and joins already delivered application messages',
      () async {
        final repository = _Repository();
        when(() => repository.userPubkey).thenReturn(owner);
        when(repository.watchSoundRequestMessages)
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
        when(repository.watchSoundRequestMessages).thenAnswer(
          (_) => Stream.value([
            const DmMessage(
              id: rumor,
              conversationId: 'conversation',
              senderPubkey: owner,
              content: 'Please enable',
              createdAt: 1,
              giftWrapId: rumor,
              tags: [
                ['batch', 'stable'],
              ],
            ),
          ]),
        );
        expect(await client.enqueue(intent), rumor);
        verify(
          () => repository.enqueueSend(
            recipientPubkey: recipient,
            content: 'Please enable',
            idempotencyKey: 'stable',
            createdAt: 1,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).called(1);
        await client.retry(rumor);
        verifyNever(() => repository.recoverFullSend(rumorId: rumor));
      },
    );
  });

  group('delivery failures', () {
    late _Repository repository;
    late SoundRequestDmClient client;
    final intent = SoundRequestSendIntent(
      key: 'stable',
      recipient: recipient,
      content: 'Please enable',
      tags: soundRequestTags(videoAddress: '34236:$recipient:clip'),
      createdAt: 1,
      videoAddress: '34236:$recipient:clip',
    );

    setUp(() {
      repository = _Repository();
      when(() => repository.userPubkey).thenReturn(owner);
      when(
        repository.watchSoundRequestMessages,
      ).thenAnswer((_) => Stream.value([]));
      client = SoundRequestDmClient(repository: repository, ownerPubkey: owner);
    });

    test('a send policy refusal is an expected failure', () async {
      when(
        () => repository.enqueueSend(
          recipientPubkey: recipient,
          content: 'Please enable',
          idempotencyKey: 'stable',
          createdAt: 1,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((_) async => const EnqueueSendResult.blocked('blocked'));
      await expectLater(
        client.enqueue(intent),
        throwsA(isA<SoundRequestException>()),
      );
    });

    test('an undelivered retry is an expected failure', () async {
      when(
        () => repository.recoverFullSend(rumorId: rumor),
      ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));
      await expectLater(
        client.retry(rumor),
        throwsA(isA<SoundRequestException>()),
      );
    });
  });
}
