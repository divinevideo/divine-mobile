import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'harness.dart';
import 'synthetic.dart';

void main() {
  group('participant delivery', () {
    for (final time in [99, 200]) {
      test('clock boundary $time prevents signing reviewed entry', () async {
        final h = Harness();
        final review = await h.prepare();
        h.now = time;
        expect(
          (await h.repository.submit(review)).status,
          SubmissionStatus.reviewRequired,
        );
        expect(h.signatures, 0);
      });
    }
    test('inclusive opening boundary allows entry', () async {
      final h = Harness()..now = 100;
      expect(
        (await h.repository.submit(await h.prepare())).status,
        SubmissionStatus.retryable,
      );
      expect(h.signatures, 1);
    });
    test('closed and cancelled revisions require review', () async {
      for (final replacement in ['closed', 'cancelled']) {
        final h = Harness();
        final review = await h.prepare();
        h.source.records = [
          jsonEncode(
            h.organizer.definition(
              createdAt: 101,
              end: replacement == 'closed' ? 140 : 200,
              status: replacement == 'cancelled' ? 'cancelled' : 'active',
            ),
          ),
        ];
        expect(
          (await h.repository.submit(review)).status,
          SubmissionStatus.reviewRequired,
        );
        expect(h.signatures, 0);
      }
    });
    test('partial current read prevents signing', () async {
      final h = Harness();
      final review = await h.prepare();
      h.source.completeness = ReadCompleteness.partial;
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.readUnavailable,
      );
      expect(h.signatures, 0);
    });
    test('current policy and current video revision gate submission', () async {
      final h = Harness();
      final review = await h.prepare();
      h.hidden.add(h.video.id);
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.blocked,
      );
      h.hidden.clear();
      h.videoId = null;
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.reviewRequired,
      );
      expect(h.signatures, 0);
    });
    test(
      'signed field rewrites and unexpected NIP89 injection are rejected',
      () async {
        for (final rewrite in [
          'content',
          'time',
          'kind',
          'tag',
          'owner',
          'signature',
          'malformed',
        ]) {
          final h = Harness();
          final review = await h.prepare();
          h.signer = (fields) async {
            if (rewrite == 'malformed') return '{}';
            final signer = rewrite == 'owner' ? h.organizer : h.creator;
            final event = signer.sign(
              kind: rewrite == 'kind' ? 1 : fields.kind,
              createdAt: fields.createdAt + (rewrite == 'time' ? 1 : 0),
              content: rewrite == 'content' ? 'Rewritten' : fields.content,
              tags: [
                ...fields.tags,
                if (rewrite == 'tag') ['client', 'Unexpected'],
              ],
            );
            if (rewrite == 'signature') event['sig'] = '0' * 128;
            return jsonEncode(event);
          };
          expect(
            (await h.repository.submit(review)).status,
            SubmissionStatus.invalidSignedEvent,
            reason: rewrite,
          );
          expect(h.store.actions, isEmpty);
          expect(h.transport.bodies, isEmpty);
        }
      },
    );
    test('reviewed client tag is immutable and signed unchanged', () async {
      final h = Harness();
      final tags = [
        ['client', 'Divine test client'],
      ];
      final review = await h.prepare(clientTags: tags);
      tags.single[1] = 'mutated';
      final mutableCopy = review.fields.toJson();
      (mutableCopy['tags']! as List<List<String>>).clear();
      final result = await h.repository.submit(review);
      expect(result.status, SubmissionStatus.retryable);
      final event = NostrEvent.fromJson(
        jsonDecode(result.action!.signedBody) as Map<String, Object?>,
      );
      expect(event.tags.last, ['client', 'Divine test client']);
    });
    for (final boundary in [
      'load',
      'read',
      'sign',
      'insert',
      'publish',
      'save',
    ]) {
      test(
        'account switch during $boundary await never publishes new owner work',
        () async {
          final h = Harness();
          final review = await h.prepare();
          void switchOwner() => h.owner = h.organizer.pubkey;
          switch (boundary) {
            case 'load':
              h.store.onLoad = switchOwner;
            case 'read':
              h.source.beforeRead = () async => switchOwner();
            case 'sign':
              h.signer = (fields) async {
                switchOwner();
                return h.signFields(fields);
              };
            case 'insert':
              h.store.onInsert = switchOwner;
            case 'publish':
              h.transport.onPublish = switchOwner;
            case 'save':
              h.store.onSave = switchOwner;
          }
          final result = await h.repository.submit(review);
          expect(result.status, SubmissionStatus.ownerChanged);
          expect(
            h.transport.bodies.length,
            boundary == 'publish' || boundary == 'save' ? 1 : 0,
          );
          expect(
            h.store.actions.keys.every(
              (key) => key.startsWith(h.creator.pubkey),
            ),
            isTrue,
          );
        },
      );
    }
    test(
      'account switch during handoff persistence invalidates preparation',
      () async {
        final h = Harness();
        h.store.onReview = () => h.owner = h.organizer.pubkey;
        await expectLater(
          h.prepare(),
          throwsA(
            isA<SubmissionException>().having(
              (e) => e.status,
              'status',
              SubmissionStatus.ownerChanged,
            ),
          ),
        );
        expect(h.store.reviews.keys.single, startsWith(h.creator.pubkey));
        expect(h.transport.bodies, isEmpty);
      },
    );
    test(
      'post-sign rules change cannot be silently persisted or published',
      () async {
        final h = Harness();
        final review = await h.prepare();
        h.signer = (fields) async {
          h.source.records = [
            jsonEncode(
              h.organizer.definition(
                createdAt: 101,
                content: 'Changed while signing.',
              ),
            ),
          ];
          return h.signFields(fields);
        };
        expect(
          (await h.repository.submit(review)).status,
          SubmissionStatus.reviewRequired,
        );
        expect(h.store.actions, isEmpty);
        expect(h.transport.bodies, isEmpty);
      },
    );
    test(
      'API indexing is separate from matching challenge relay echo',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final result = await h.repository.submit(review);
        final body = result.action!.signedBody;
        final indexed = await h.repository.reconcile(
          review.id,
          body,
          indexed: true,
        );
        expect(indexed.status, SubmissionStatus.retryable);
        expect(indexed.action!.indexed, isTrue);
        final configured = await h.repository.reconcile(
          review.id,
          body,
          relay: 'wss://configured.example.test',
        );
        expect(configured.status, SubmissionStatus.retryable);
        final echoed = await h.repository.reconcile(
          review.id,
          body,
          relay: h.relay,
        );
        expect(echoed.status, SubmissionStatus.submitted);
        expect(echoed.action!.indexed, isTrue);
        expect(
          (await h.repository.retry(review.id)).status,
          SubmissionStatus.submitted,
        );
        expect(h.transport.bodies, hasLength(1));
      },
    );
    test(
      'withdrawal is exact, durable and permits explicit later reentry',
      () async {
        final h = Harness();
        final firstReview = await h.prepare();
        final first = await h.repository.submit(firstReview);
        final entry = NostrEvent.fromJson(
          jsonDecode(first.action!.signedBody) as Map<String, Object?>,
        );
        h.source.records = [
          jsonEncode(h.definition.toJson()),
          first.action!.signedBody,
        ];
        final withdrawalReview = await h.repository.prepareWithdrawal(
          entry: entry,
        );
        final withdrawal = await h.repository.submit(withdrawalReview);
        expect(withdrawal.status, SubmissionStatus.retryable);
        final parsed =
            parseChallengeEvent(jsonDecode(withdrawal.action!.signedBody))
                    .value!
                as ChallengeWithdrawal;
        expect(parsed.entryId, entry.id);
        expect(
          h.transport.bodies.map(
            (body) => (jsonDecode(body) as Map<String, Object?>)['kind'],
          ),
          everyElement(1111),
        );
        h.source.records.add(withdrawal.action!.signedBody);
        final coordinate = definitionOf(h.definition.toJson()).coordinate;
        expect((await h.reads.refresh(coordinate)).view.entries, isEmpty);
        h.now = 151;
        final reentry = await h.repository.submit(await h.prepare());
        expect(reentry.status, SubmissionStatus.retryable);
        final reentryEvent = NostrEvent.fromJson(
          jsonDecode(reentry.action!.signedBody) as Map<String, Object?>,
        );
        expect(reentryEvent.id, isNot(entry.id));
        expect(
          (parseChallengeEvent(reentryEvent).value! as ChallengeEntry).video.id,
          h.video.id,
        );
        h.owner = h.organizer.pubkey;
        await expectLater(
          h.repository.prepareWithdrawal(entry: entry),
          throwsA(isA<SubmissionException>()),
        );
      },
    );
    test(
      'withdrawal remains possible after window closes and video is hidden',
      () async {
        final h = Harness();
        final first = await h.repository.submit(await h.prepare());
        final entry = NostrEvent.fromJson(
          jsonDecode(first.action!.signedBody) as Map<String, Object?>,
        );
        h.now = 250;
        h.hidden.add(h.video.id);
        final review = await h.repository.prepareWithdrawal(entry: entry);
        final withdrawal = await h.repository.submit(review);
        expect(withdrawal.status, SubmissionStatus.retryable);
        final retried = await h.createRepository().retry(review.id);
        expect(retried.action!.signedBody, withdrawal.action!.signedBody);
      },
    );
    test(
      'persists before transport and restarts with identical signed bytes',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final first = await h.repository.submit(review);
        expect(first.status, SubmissionStatus.retryable);
        expect(h.signatures, 1);
        expect(h.store.actions, hasLength(1));
        expect(h.transport.bodies, hasLength(1));
        final signed = h.transport.bodies.single;
        h.transport.outcomes = {h.relay: RelayOutcome.accepted};
        final restarted = h.createRepository();
        final retried = await restarted.retry(review.id);
        expect(retried.status, SubmissionStatus.submitted);
        expect(h.signatures, 1);
        expect(h.transport.bodies, [signed, signed]);
        expect(retried.action!.indexed, isFalse);
      },
    );
    test(
      'configured relay acceptance does not mark challenge submitted',
      () async {
        final h = Harness();
        h.transport.outcomes = {
          'wss://configured.example.test': RelayOutcome.accepted,
        };
        expect(
          (await h.repository.submit(await h.prepare())).status,
          SubmissionStatus.retryable,
        );
      },
    );
    test('changed rules require new review without signing', () async {
      final h = Harness();
      final review = await h.prepare();
      h.source.records = [
        jsonEncode(
          h.organizer.definition(createdAt: 151, content: 'Changed rules.'),
        ),
      ];
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.reviewRequired,
      );
      expect(h.signatures, 0);
      expect(h.transport.bodies, isEmpty);
    });
    test('durable insert failure prevents publication', () async {
      final h = Harness();
      final review = await h.prepare();
      h.store.failInsert = true;
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.persistenceFailed,
      );
      expect(h.transport.bodies, isEmpty);
    });
    test('duplicate taps sign and publish once', () async {
      final h = Harness();
      final review = await h.prepare();
      final results = await Future.wait([
        h.repository.submit(review),
        h.repository.submit(review),
      ]);
      expect(
        results.map((r) => r.status),
        everyElement(SubmissionStatus.retryable),
      );
      expect(h.signatures, 1);
      expect(h.transport.bodies, hasLength(1));
    });
  });
}
