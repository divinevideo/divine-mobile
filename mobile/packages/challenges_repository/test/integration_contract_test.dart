import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'harness.dart' show Harness;

void main() {
  group('app integration contract', () {
    test(
      'signed migration can promote an existing configured target',
      () async {
        final h = Harness();
        final initial = await h.repository.submit(await h.prepare());
        const relay = 'wss://configured.example.test';
        h.source.records = [
          jsonEncode(h.organizer.definition(createdAt: 151, relay: relay)),
        ];
        h.transport.outcomes = {relay: RelayOutcome.accepted};
        final result = await h.repository.retry(initial.action!.review.id);
        expect(result.status, SubmissionStatus.submitted);
        expect(result.action!.signedBody, initial.action!.signedBody);
        expect(result.action!.challengeRelays, contains(relay));
      },
    );
    test(
      'active relay entry prevents duplicate after local outbox loss',
      () async {
        final h = Harness();
        final first = await h.repository.submit(await h.prepare());
        h.source.records = [
          jsonEncode(h.definition.toJson()),
          first.action!.signedBody,
        ];
        h.store.actions.clear();
        h.now++;
        await expectLater(h.prepare(), throwsA(isA<SubmissionException>()));
        expect(h.signatures, 1);
      },
    );
    test('signed relay migration delivers original bytes '
        'to newly advertised relay', () async {
      final h = Harness();
      final initial = await h.repository.submit(await h.prepare());
      final body = initial.action!.signedBody;
      const migrated = 'wss://migrated.example.test';
      h.source.records = [
        jsonEncode(h.organizer.definition(createdAt: 151, relay: migrated)),
      ];
      h.transport.outcomes = {migrated: RelayOutcome.accepted};
      final result = await h.repository.retry(initial.action!.review.id);
      expect(result.status, SubmissionStatus.submitted);
      expect(result.action!.signedBody, body);
      expect(result.action!.challengeRelays, contains(migrated));
      expect(result.action!.deliveryDefinition, isNotNull);
      expect(h.signatures, 1);
    });
    test(
      'oversized client metadata is an explainable preparation failure',
      () async {
        final h = Harness();
        await expectLater(
          h.prepare(
            clientTags: [
              ['client', 'x' * 70000],
            ],
          ),
          throwsA(
            isA<SubmissionException>().having(
              (e) => e.status,
              'status',
              SubmissionStatus.eventTooLarge,
            ),
          ),
        );
        expect(h.store.reviews, isEmpty);
      },
    );
    test('contract failure during restore is a domain failure', () async {
      final h = Harness();
      final review = await h.prepare();
      final invalid = SubmissionReview(
        owner: review.owner,
        definition: review.definition,
        video: NostrEvent(
          id: review.video.id,
          pubkey: review.video.pubkey,
          sig: '0' * 128,
          createdAt: review.video.createdAt,
          kind: review.video.kind,
          content: review.video.content,
          tags: review.video.tags,
        ),
        fields: review.fields,
      );
      h.store.reviews['${review.owner}:${review.id}'] = invalid;
      await expectLater(
        h.repository.restoreReview(review.id),
        throwsA(isA<SubmissionException>()),
      );
    });
    test(
      'historical submitted evidence survives current policy denial',
      () async {
        final h = Harness();
        h.transport.outcomes = {h.relay: RelayOutcome.accepted};
        final first = await h.repository.submit(await h.prepare());
        expect(first.action!.submitted, isTrue);
        h.hidden.add(h.video.id);
        final result = await h.repository.retry(first.action!.review.id);
        expect(result.status, SubmissionStatus.blocked);
        expect(result.action!.submitted, isTrue);
      },
    );
    test(
      'two previously prepared reviews cannot create duplicate pending entries',
      () async {
        final h = Harness();
        final first = await h.prepare();
        h.now++;
        final second = await h.prepare();
        await h.repository.submit(first);
        expect(
          (await h.repository.submit(second)).status,
          SubmissionStatus.reviewRequired,
        );
        expect(h.signatures, 1);
      },
    );
    test(
      'transport awaiting reconciliation returns instead of deadlocking',
      () async {
        final h = Harness();
        final review = await h.prepare();
        late ChallengeSubmissionRepository repository;
        repository = ChallengeSubmissionRepository(
          reads: h.reads,
          store: h.store,
          transport: (body, targets) async {
            final echo = await repository.reconcile(
              review.id,
              body,
              relay: h.relay,
            );
            expect(echo.status, SubmissionStatus.retryable);
            return {h.relay: RelayOutcome.accepted};
          },
          currentOwner: () => h.owner,
          currentVideoId: (_) => h.videoId,
          canPublish: (_) => true,
          sign: (fields) async => h.signFields(fields),
          writableRelays: () => [],
        );
        final result = await repository
            .submit(review)
            .timeout(const Duration(seconds: 10));
        expect(result.status, SubmissionStatus.submitted);
      },
    );
    test(
      'a later consent cannot sign another pending same-video entry',
      () async {
        final h = Harness();
        final first = await h.repository.submit(await h.prepare());
        expect(first.action, isNotNull);
        h.now++;
        await expectLater(h.prepare(), throwsA(isA<SubmissionException>()));
        expect(h.signatures, 1);
      },
    );
    test('queued exact withdrawal pauses entry retries', () async {
      final h = Harness();
      final first = await h.repository.submit(await h.prepare());
      final entry = NostrEvent.fromJson(
        jsonDecode(first.action!.signedBody) as Map<String, Object?>,
      );
      final withdrawal = await h.repository.prepareWithdrawal(entry: entry);
      await h.repository.submit(withdrawal);
      final sent = h.transport.bodies.length;
      expect(
        (await h.repository.retry(first.action!.review.id)).status,
        SubmissionStatus.deliveryPaused,
      );
      expect(h.transport.bodies.length, sent);
    });
    test(
      'StateError from established signer is an observable failure',
      () async {
        final h = Harness()
          ..signer = (_) async => throw StateError('Signer disconnected');
        expect(
          (await h.repository.submit(await h.prepare())).status,
          SubmissionStatus.signerFailed,
        );
        expect(h.store.actions, isEmpty);
      },
    );
    test('switch during ACK retains latest evidence in result', () async {
      final h = Harness();
      h.transport.outcomes = {h.relay: RelayOutcome.accepted};
      h.transport.onPublish = () => h.owner = h.organizer.pubkey;
      final result = await h.repository.submit(await h.prepare());
      expect(result.status, SubmissionStatus.ownerChanged);
      expect(result.action!.submitted, isTrue);
    });
    test(
      'stored relay metadata cannot grant configured ACK authority',
      () async {
        final h = Harness();
        final first = await h.repository.submit(await h.prepare());
        final action = first.action!;
        await h.store.saveAction(
          action.review.owner,
          PendingChallengeAction(
            review: action.review,
            signedBody: action.signedBody,
            challengeRelays: ['wss://configured.example.test'],
            targets: action.targets,
            outcomes: {'wss://configured.example.test': RelayOutcome.accepted},
          ),
        );
        final result = await h.repository.retry(action.review.id);
        expect(result.status, SubmissionStatus.invalidSignedEvent);
      },
    );
  });
}
