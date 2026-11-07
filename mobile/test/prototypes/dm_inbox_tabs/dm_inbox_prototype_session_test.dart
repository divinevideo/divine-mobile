// ABOUTME: PROTOTYPE (#8076) — pins the session actions and the sender
// ABOUTME: context rules: unknown is never shown as zero, loops follow the
// ABOUTME: viewer's choice, and message facts wait until a request is opened.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_session.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';

void main() {
  group('dm inbox prototype session', () {
    late DmInboxFixtures fixtures;

    setUp(() => fixtures = DmInboxFixtures.build());

    DmConversation byTitle(String title) => fixtures.dmConversations.firstWhere(
      (c) => fixtures.titleFor(c) == title,
    );

    DmInboxClassification classify(
      DmPrototypeSession session, {
      DmPrototypeSettings settings = const DmPrototypeSettings(),
    }) => classifyPrototype(
      fixtures: fixtures,
      settings: settings,
      session: session,
    );

    group('senderContextParts', () {
      test('lists videos, then the named mutual, then loops', () {
        final parts = senderContextParts(
          const DmSenderSignals(
            divineVideoCount: 22,
            mutualConnectionCount: 4,
            totalLoopCount: 56000,
          ),
          showLoops: true,
          mutualName: 'Maya Okonkwo',
        );

        expect(
          parts,
          equals([
            '22 videos',
            'Followed by Maya Okonkwo and 3 others',
            '56K loops',
          ]),
        );
      });

      test('leaves out every unknown value instead of showing zero', () {
        expect(
          senderContextParts(DmSenderSignals.unknown, showLoops: true),
          isEmpty,
        );
      });

      test('says so when the sender is known to have no videos', () {
        final parts = senderContextParts(
          const DmSenderSignals(divineVideoCount: 0, mutualConnectionCount: 0),
          showLoops: true,
        );

        expect(parts, equals(['No videos yet', 'No mutual connections']));
      });

      test('hides a known zero of loops, as profiles do for other people', () {
        final parts = senderContextParts(
          const DmSenderSignals(divineVideoCount: 2, totalLoopCount: 0),
          showLoops: true,
        );

        expect(parts, equals(['2 videos']));
      });

      test('hides loops when the viewer has turned them off', () {
        final parts = senderContextParts(
          const DmSenderSignals(divineVideoCount: 2, totalLoopCount: 900),
          showLoops: false,
        );

        expect(parts, isNot(contains('900 loops')));
        expect(parts, equals(['2 videos']));
      });

      test('names a single mutual and counts mutuals it cannot name', () {
        expect(
          senderContextParts(
            const DmSenderSignals(mutualConnectionCount: 1),
            showLoops: true,
            mutualName: 'Rin Takahashi',
          ),
          equals(['Followed by Rin Takahashi']),
        );
        expect(
          senderContextParts(
            const DmSenderSignals(mutualConnectionCount: 3),
            showLoops: true,
          ),
          equals(['3 mutual connections']),
        );
      });
    });

    group('soleCounterparty', () {
      test('returns the other person in a one-to-one conversation', () {
        final priya = byTitle('Priya Raman');
        expect(
          soleCounterparty(priya, fixtures.userPubkey),
          equals(
            priya.participantPubkeys.firstWhere(
              (pubkey) => pubkey != fixtures.userPubkey,
            ),
          ),
        );
      });

      test('returns null for a group', () {
        final group = fixtures.dmConversations.firstWhere(
          (c) => fixtures.titleFor(c).endsWith(' and 1 other'),
        );
        expect(soleCounterparty(group, fixtures.userPubkey), isNull);
      });
    });

    group(DmPrototypeSession, () {
      test('hands out sets a caller cannot change behind its back', () {
        final session = const DmPrototypeSession().reveal('a').block('b');

        expect(() => session.revealed.add('c'), throwsUnsupportedError);
        expect(() => session.blocked.add('c'), throwsUnsupportedError);
        expect(session.revealed, equals({'a'}));
      });

      test('a sent reply moves a request into inbox', () {
        final priya = byTitle('Priya Raman');
        expect(classify(const DmPrototypeSession()).requests, contains(priya));

        final after = classify(const DmPrototypeSession().reply(priya.id));

        expect(after.inbox.map((c) => c.id), contains(priya.id));
        expect(after.requests.map((c) => c.id), isNot(contains(priya.id)));
      });

      test('not spam keeps a row in requests through a stricter threshold', () {
        final spam = byTitle('crypto_signals_daily');
        final session = const DmPrototypeSession().markNotSpam(spam.id);

        final strict = classify(
          session,
          settings: const DmPrototypeSettings(
            heuristics: DmSpamHeuristics(spamThreshold: 1),
          ),
        );

        expect(strict.requests.map((c) => c.id), contains(spam.id));
        expect(strict.inbox.map((c) => c.id), isNot(contains(spam.id)));
      });

      test('opening a request marks it read', () {
        final priya = byTitle('Priya Raman');
        expect(priya.isRead, isFalse);

        final seen = const DmPrototypeSession()
            .reveal(priya.id)
            .apply(fixtures.dmConversations)
            .firstWhere((c) => c.id == priya.id);

        expect(seen.isRead, isTrue);
      });

      test('delete removes only that conversation', () {
        final priya = byTitle('Priya Raman');
        final rows = const DmPrototypeSession()
            .remove(priya.id)
            .apply(fixtures.dmConversations);

        expect(rows.map((c) => c.id), isNot(contains(priya.id)));
        expect(rows, hasLength(fixtures.dmConversations.length - 1));
      });

      test('block hides every conversation with that sender', () {
        final group = fixtures.dmConversations.firstWhere(
          (c) => fixtures.titleFor(c).endsWith(' and 1 other'),
        );
        final friend = fixtures.dmConversations.firstWhere(
          (c) => fixtures.titleFor(c) == 'Sofia Marchetti',
        );
        final sofia = friend.participantPubkeys.firstWhere(
          (pubkey) => pubkey != fixtures.userPubkey,
        );

        final rows = const DmPrototypeSession()
            .block(sofia)
            .apply(fixtures.dmConversations);

        expect(rows.map((c) => c.id), isNot(contains(friend.id)));
        expect(rows.map((c) => c.id), isNot(contains(group.id)));
      });
    });

    group('visibleReasons', () {
      const verdict = DmVerdict(
        bucket: DmInboxBucket.requests,
        score: 35,
        reasons: [
          DmRiskReason('First seen recently', 25),
          DmRiskReason('First message contains a link', 25, aboutMessage: true),
          DmRiskReason('Posts on Divine', -15),
        ],
      );

      test('holds back facts about the hidden message', () {
        final labels = visibleReasons(
          verdict,
          includeMessageReasons: false,
        ).map((r) => r.label);

        expect(labels, contains('First seen recently'));
        expect(labels, isNot(contains('First message contains a link')));
      });

      test('shows them once the message may be read', () {
        final labels = visibleReasons(
          verdict,
          includeMessageReasons: true,
        ).map((r) => r.label);

        expect(labels, contains('First message contains a link'));
      });
    });

    group('cautionReason', () {
      test('picks the strongest risk reason that may be shown', () {
        const verdict = DmVerdict(
          bucket: DmInboxBucket.requests,
          score: 60,
          reasons: [
            DmRiskReason('No profile name or photo', 15),
            DmRiskReason(
              'First message contains a link',
              45,
              aboutMessage: true,
            ),
            DmRiskReason('First seen recently', 25),
          ],
        );

        expect(
          cautionReason(verdict, includeMessageReasons: false)?.label,
          equals('First seen recently'),
        );
        expect(
          cautionReason(verdict, includeMessageReasons: true)?.label,
          equals('First message contains a link'),
        );
      });

      test('is null when nothing raised the risk', () {
        const verdict = DmVerdict(
          bucket: DmInboxBucket.requests,
          score: -15,
          reasons: [DmRiskReason('Posts on Divine', -15)],
        );

        expect(cautionReason(verdict, includeMessageReasons: true), isNull);
      });
    });
  });
}
