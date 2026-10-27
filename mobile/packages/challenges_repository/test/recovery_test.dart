import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'harness.dart' show Harness;

void main() {
  group('durable recovery boundaries', () {
    for (final change in [
      'deadline',
      'rules',
      'video',
      'third-refresh-rules',
      'third-refresh-deadline',
    ]) {
      test(
        'first durable delivery survives $change change without new consent',
        () async {
          final h = Harness();
          final review = await h.prepare();
          final expectedBody = h.signFields(review.fields);
          final expectedId =
              (jsonDecode(expectedBody) as Map<String, Object?>)['id'];
          void reviseRules() {
            h.source.records = [
              jsonEncode(
                h.organizer.definition(
                  createdAt: 180,
                  content: 'Rules changed during durable delivery.',
                ),
              ),
            ];
          }

          switch (change) {
            case 'deadline':
              h.store.onInsert = () => h.now = 200;
            case 'rules':
              h.store.onInsert = reviseRules;
            case 'video':
              h.store.onInsert = () => h.videoId = 'a' * 64;
            case 'third-refresh-rules':
            case 'third-refresh-deadline':
              var reads = 0;
              h.source.beforeRead = () async {
                reads++;
                if (reads == 3) {
                  if (change == 'third-refresh-rules') {
                    reviseRules();
                  } else {
                    h.now = 200;
                  }
                }
              };
          }
          h.transport.outcomes = {h.relay: RelayOutcome.accepted};
          final result = await h.repository.submit(review);
          expect(result.status, SubmissionStatus.submitted);
          expect(h.signatures, 1);
          expect(result.action!.signedBody, expectedBody);
          expect(h.transport.bodies, [expectedBody]);
          expect(
            (jsonDecode(h.transport.bodies.single)
                as Map<String, Object?>)['id'],
            expectedId,
          );
          final restarted = await h.createRepository().retry(review.id);
          expect(restarted.status, SubmissionStatus.submitted);
          expect(restarted.action!.signedBody, expectedBody);
          expect(h.signatures, 1);
          expect(h.transport.bodies, [expectedBody]);
        },
      );
    }
    for (final restriction in [
      'owner',
      'actor-policy',
      'video-visibility',
      'entry-visibility',
      'cancelled',
      'malformed',
      'partial',
      'failed-read',
    ]) {
      test(
        'durable insertion preserves $restriction delivery safeguard',
        () async {
          final h = Harness();
          final review = await h.prepare();
          final body = h.signFields(review.fields);
          h.store.onInsert = () {
            switch (restriction) {
              case 'owner':
                h.owner = h.organizer.pubkey;
              case 'actor-policy':
                h.publicationAllowed = false;
              case 'video-visibility':
                h.hidden.add(h.video.id);
              case 'entry-visibility':
                h.hidden.add(
                  (jsonDecode(body) as Map<String, Object?>)['id']! as String,
                );
              case 'cancelled':
                h.source.records = [
                  jsonEncode(
                    h.organizer.definition(createdAt: 180, status: 'cancelled'),
                  ),
                ];
              case 'malformed':
                h.source.records = [
                  jsonEncode(
                    h.organizer.sign(
                      createdAt: 180,
                      tags: [
                        ['d', 'synthetic:challenge'],
                      ],
                    ),
                  ),
                ];
              case 'partial':
                h.source.completeness = ReadCompleteness.partial;
              case 'failed-read':
                h.source.fail = true;
            }
          };
          final expected = switch (restriction) {
            'owner' => SubmissionStatus.ownerChanged,
            'actor-policy' ||
            'video-visibility' ||
            'entry-visibility' => SubmissionStatus.blocked,
            'cancelled' => SubmissionStatus.deliveryPaused,
            _ => SubmissionStatus.readUnavailable,
          };
          final result = await h.repository.submit(review);
          expect(result.status, expected);
          expect(result.action!.signedBody, body);
          expect(h.store.actions.values.single.signedBody, body);
          expect(h.transport.bodies, isEmpty);
          expect(h.signatures, 1);
        },
      );
    }
    test(
      'cancelled durable delivery resumes the same bytes after reactivation',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final body = (await h.repository.submit(review)).action!.signedBody;
        h.source.records = [
          jsonEncode(
            h.organizer.definition(createdAt: 180, status: 'cancelled'),
          ),
        ];
        final paused = await h.createRepository().retry(review.id);
        expect(paused.status, SubmissionStatus.deliveryPaused);
        expect(paused.action!.signedBody, body);
        expect(h.transport.bodies, [body]);
        h.source.records = [jsonEncode(h.organizer.definition(createdAt: 190))];
        h.transport.outcomes = {h.relay: RelayOutcome.accepted};
        final resumed = await h.createRepository().retry(review.id);
        expect(resumed.status, SubmissionStatus.submitted);
        expect(h.transport.bodies, [body, body]);
        expect(h.signatures, 1);
      },
    );

    test(
      'same-second reentry never reuses a withdrawn event as new consent',
      () async {
        final h = Harness();
        final first = await h.repository.submit(await h.prepare());
        final entry = NostrEvent.fromJson(
          jsonDecode(first.action!.signedBody) as Map<String, Object?>,
        );
        await h.repository.submit(
          await h.repository.prepareWithdrawal(entry: entry),
        );
        await expectLater(
          h.prepare(),
          throwsA(
            isA<SubmissionException>().having(
              (e) => e.status,
              'status',
              SubmissionStatus.reviewRequired,
            ),
          ),
        );
        expect(h.signatures, 2);
        h.now++;
        final fresh = await h.prepare();
        expect(fresh.id, isNot(first.action!.review.id));
      },
    );

    test(
      'withdrawal permits hidden media but enforces actor permission',
      () async {
        final h = Harness();
        final body = (await h.repository.submit(await h.prepare()))
            .action!
            .signedBody;
        final entry = NostrEvent.fromJson(
          jsonDecode(body) as Map<String, Object?>,
        );
        h.now = 250;
        h.hidden.add(h.video.id);
        h.source.records = [
          jsonEncode(
            h.organizer.definition(createdAt: 180, status: 'cancelled'),
          ),
        ];
        final review = await h.repository.prepareWithdrawal(entry: entry);
        final withdrawn = await h.repository.submit(review);
        expect(withdrawn.status, SubmissionStatus.retryable);
        h.publicationAllowed = false;
        expect(
          (await h.createRepository().retry(review.id)).status,
          SubmissionStatus.blocked,
        );
        expect(h.transport.bodies, hasLength(2));
        h.publicationAllowed = true;
        final retried = await h.createRepository().retry(review.id);
        expect(retried.action!.signedBody, withdrawn.action!.signedBody);
        expect(h.transport.bodies, hasLength(3));
        expect(h.hidden, contains(h.video.id));
      },
    );

    test(
      'durable retry preserves bytes after closing and active revisions change',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final signed = (await h.repository.submit(review)).action!.signedBody;
        h
          ..now = 200
          ..videoId = 'a' * 64;
        h.source.records = [
          jsonEncode(
            h.organizer.definition(
              createdAt: 180,
              end: 190,
              content: 'Superseded rules.',
            ),
          ),
        ];
        h.transport.outcomes = {h.relay: RelayOutcome.accepted};
        final retried = await h.createRepository().retry(review.id);
        expect(retried.status, SubmissionStatus.submitted);
        expect(h.signatures, 1);
        expect(h.transport.bodies, [signed, signed]);
        expect(retried.action!.indexed, isFalse);
      },
    );
    for (final restriction in ['cancelled', 'malformed', 'partial', 'policy']) {
      test(
        'durable retry pauses on $restriction while retaining exact bytes',
        () async {
          final h = Harness();
          final review = await h.prepare();
          final body = (await h.repository.submit(review)).action!.signedBody;
          switch (restriction) {
            case 'cancelled':
              h.source.records = [
                jsonEncode(
                  h.organizer.definition(createdAt: 180, status: 'cancelled'),
                ),
              ];
            case 'malformed':
              h.source.records = [
                jsonEncode(
                  h.organizer.sign(
                    createdAt: 180,
                    tags: [
                      ['d', 'synthetic:challenge'],
                    ],
                  ),
                ),
              ];
            case 'partial':
              h.source.completeness = ReadCompleteness.partial;
            case 'policy':
              h.hidden.add(h.video.id);
          }
          final result = await h.createRepository().retry(review.id);
          expect(
            result.status,
            restriction == 'cancelled'
                ? SubmissionStatus.deliveryPaused
                : restriction == 'policy'
                ? SubmissionStatus.blocked
                : SubmissionStatus.readUnavailable,
          );
          expect(h.transport.bodies, [body]);
          expect(h.store.actions.values.single.signedBody, body);
          expect(h.signatures, 1);
        },
      );
    }
    test(
      'newly signed action blocked by current event policy cannot publish',
      () async {
        final h = Harness();
        final review = await h.prepare();
        h.signer = (fields) async {
          final body = h.signFields(fields);
          h.hidden.add(
            (jsonDecode(body) as Map<String, Object?>)['id']! as String,
          );
          return body;
        };
        expect(
          (await h.repository.submit(review)).status,
          SubmissionStatus.blocked,
        );
        expect(h.transport.bodies, isEmpty);
      },
    );

    test(
      'concurrent indexing and relay echo both survive reconciliation',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final result = await h.repository.submit(review);
        final body = result.action!.signedBody;
        await Future.wait([
          h.repository.reconcile(review.id, body, indexed: true),
          h.repository.reconcile(review.id, body, relay: h.relay),
        ]);
        final saved = h.store.actions.values.single;
        expect(saved.indexed, isTrue);
        expect(saved.submitted, isTrue);
      },
    );
    test(
      'restart discovers owner scoped work and restores reviewed context',
      () async {
        final h = Harness();
        final review = await h.prepare();
        await h.repository.submit(review);
        final restarted = h.createRepository();
        final pending = await restarted.pendingActions();
        expect(pending.single.review.id, review.id);
        final restored = await restarted.restoreReview(review.id);
        expect(restored!.video.id, h.video.id);
        expect(restored.definition.id, h.definition.id);
        h.owner = h.organizer.pubkey;
        expect(await restarted.pendingActions(), isEmpty);
        expect(await restarted.restoreReview(review.id), isNull);
      },
    );
    test(
      'transport exception and later rejection preserve the same event',
      () async {
        final h = Harness();
        final review = await h.prepare();
        h.transport.onPublish = () =>
            throw Exception('Unknown acknowledgement');
        final failed = await h.repository.submit(review);
        expect(failed.status, SubmissionStatus.retryable);
        expect(failed.action!.outcomes[h.relay], RelayOutcome.silence);
        h.transport.onPublish = null;
        h.transport.outcomes = {
          h.relay: RelayOutcome.rejected,
          'wss://configured.example.test': RelayOutcome.unreachable,
        };
        final retried = await h.repository.retry(review.id);
        expect(retried.status, SubmissionStatus.retryable);
        expect(retried.action!.outcomes[h.relay], RelayOutcome.rejected);
        expect(h.transport.bodies, [
          failed.action!.signedBody,
          failed.action!.signedBody,
        ]);
      },
    );
    test(
      'failed acknowledgement storage leaves retryable exact bytes',
      () async {
        final h = Harness();
        final review = await h.prepare();
        h.store.onSave = () => throw Exception('Synthetic save failure');
        final result = await h.repository.submit(review);
        expect(result.status, SubmissionStatus.persistenceFailed);
        expect(h.transport.bodies.single, result.action!.signedBody);
        expect(result.action!.outcomes, isEmpty);
        h.store.onSave = null;
        expect(
          (await h.createRepository().retry(review.id)).action!.signedBody,
          result.action!.signedBody,
        );
      },
    );
    test('signer failure never persists or publishes', () async {
      final h = Harness();
      final review = await h.prepare();
      h.signer = (_) async => throw Exception('Synthetic signer unavailable');
      expect(
        (await h.repository.submit(review)).status,
        SubmissionStatus.signerFailed,
      );
      expect(h.store.actions, isEmpty);
      expect(h.transport.bodies, isEmpty);
    });
    test('missing or signed-out recovery never signs', () async {
      final h = Harness();
      expect(
        (await h.repository.retry('missing')).status,
        SubmissionStatus.reviewRequired,
      );
      expect(
        (await h.repository.reconcile('missing', '{}')).status,
        SubmissionStatus.reviewRequired,
      );
      h.owner = null;
      expect(
        (await h.repository.retry('missing')).status,
        SubmissionStatus.ownerChanged,
      );
      expect(
        (await h.repository.reconcile('missing', '{}')).status,
        SubmissionStatus.ownerChanged,
      );
      expect(h.signatures, 0);
    });
    test(
      'reconciliation verifies signatures and retains prior durable body',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final result = await h.repository.submit(review);
        final original = result.action!.signedBody;
        expect(
          (await h.repository.reconcile(
            review.id,
            '{}',
            relay: h.relay,
          )).status,
          SubmissionStatus.invalidSignedEvent,
        );
        expect(h.store.actions.values.single.signedBody, original);
        expect(h.store.actions.values.single.submitted, isFalse);
      },
    );
    for (final operation in ['retry', 'reconcile']) {
      test('$operation storage failure is explicit', () async {
        final h = Harness();
        h.store.onLoad = () => throw Exception('Synthetic load failure');
        final result = operation == 'retry'
            ? await h.repository.retry('missing')
            : await h.repository.reconcile('missing', '{}');
        expect(result.status, SubmissionStatus.persistenceFailed);
        expect(h.transport.bodies, isEmpty);
      });
      test('$operation load account switch cannot cross owner scope', () async {
        final h = Harness();
        final review = await h.prepare();
        final action = (await h.repository.submit(review)).action!;
        h.store.onLoad = () => h.owner = h.organizer.pubkey;
        final result = operation == 'retry'
            ? await h.repository.retry(review.id)
            : await h.repository.reconcile(review.id, action.signedBody);
        expect(result.status, SubmissionStatus.ownerChanged);
        expect(h.transport.bodies, hasLength(1));
      });
    }
    test(
      'reconciliation save failure and account switch are explicit',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final body = (await h.repository.submit(review)).action!.signedBody;
        h.store.onSave = () => throw Exception('Synthetic save failure');
        expect(
          (await h.repository.reconcile(review.id, body, indexed: true)).status,
          SubmissionStatus.persistenceFailed,
        );
        h.store.onSave = () => h.owner = h.organizer.pubkey;
        expect(
          (await h.repository.reconcile(
            review.id,
            body,
            relay: h.relay,
          )).status,
          SubmissionStatus.ownerChanged,
        );
      },
    );
    test('forged review template cannot grant authority', () async {
      final h = Harness();
      final review = await h.prepare();
      final forged = SubmissionReview(
        owner: review.owner,
        definition: review.definition,
        video: review.video,
        fields: UnsignedChallengeAction(
          kind: 1111,
          createdAt: 150,
          content: 'Forged',
          tags: review.fields.tags,
        ),
      );
      expect(
        (await h.repository.submit(forged)).status,
        SubmissionStatus.reviewRequired,
      );
      expect(h.signatures, 0);
    });
    test('unknown persisted malformed signature never republishes', () async {
      final h = Harness();
      final review = await h.prepare();
      final original = (await h.repository.submit(review)).action!;
      final tampered = await _storeTamperedBody(h, original);
      final retried = await h.createRepository().retry(review.id);
      expect(retried.status, SubmissionStatus.invalidSignedEvent);
      expect(retried.action!.signedBody, tampered);
      expect(h.transport.bodies, hasLength(1));
    });
    test(
      'forged sources and unrelated metadata cannot prepare consent',
      () async {
        final h = Harness();
        await expectLater(
          h.repository.prepareEntry(definition: h.video, video: h.video),
          throwsA(isA<SubmissionException>()),
        );
        await expectLater(
          h.repository.prepareWithdrawal(entry: h.video),
          throwsA(isA<SubmissionException>()),
        );
        await expectLater(
          h.prepare(
            clientTags: [
              ['q', 'unreviewed'],
            ],
          ),
          throwsA(isA<SubmissionException>()),
        );
        await expectLater(
          h.prepare(
            clientTags: [
              ['client', 'x' * 65536],
            ],
          ),
          throwsA(isA<SubmissionException>()),
        );
        h.owner = h.organizer.pubkey;
        await expectLater(h.prepare(), throwsA(isA<SubmissionException>()));
        expect(h.transport.bodies, isEmpty);
      },
    );
  });
}

Future<String> _storeTamperedBody(
  Harness h,
  PendingChallengeAction original,
) async {
  final wire = jsonDecode(original.signedBody) as Map<String, Object?>;
  wire['content'] = 'Forged';
  final tampered = jsonEncode(wire);
  await h.store.saveAction(
    original.review.owner,
    PendingChallengeAction(
      review: original.review,
      signedBody: tampered,
      challengeRelays: original.challengeRelays,
      targets: original.targets,
    ),
  );
  return tampered;
}
