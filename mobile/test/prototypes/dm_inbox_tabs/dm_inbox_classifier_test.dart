// ABOUTME: PROTOTYPE (#8076) — pins the four-way classifier's invariants.
// ABOUTME: The official-account rules are product requirements, not
// ABOUTME: implementation details, so they get named tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';

void main() {
  group(DmInboxClassifier, () {
    late DmInboxFixtures fixtures;

    setUp(() => fixtures = DmInboxFixtures.build());

    DmInboxClassification classify({DmSpamHeuristics? heuristics}) {
      return DmInboxClassifier(
        officialIdentities: fixtures.officialIdentities,
        heuristics: heuristics ?? const DmSpamHeuristics(),
      ).classify(
        fixtures.dmConversations,
        userPubkey: fixtures.userPubkey,
        isFollowing: fixtures.isFollowing,
        signalsFor: fixtures.signalsFor,
        messageSignalsFor: fixtures.messageSignalsFor,
      );
    }

    group('official', () {
      test('routes every canonical Divine account to the official bucket', () {
        final result = classify();

        expect(result.official, hasLength(6));
        expect(
          result.official.map(fixtures.titleFor),
          containsAll(<String>[
            'DivineHQ',
            'Divine Support',
            'Divine Trust & Safety',
            'Divine Moderation',
            'Liz · Divine team',
            'Rabble · Divine team',
          ]),
        );
      });

      test('operational accounts are unblockable and team members are not', () {
        final result = classify();
        final identities = <String, DivineOfficialIdentity>{
          for (final conversation in result.official)
            fixtures.titleFor(conversation):
                result.verdicts[conversation.id]!.officialIdentity!,
        };

        expect(identities['DivineHQ']!.isBlockable, isFalse);
        expect(identities['Divine Support']!.isBlockable, isFalse);
        expect(identities['Liz · Divine team']!.isBlockable, isTrue);
        expect(identities['Rabble · Divine team']!.isBlockable, isTrue);
      });

      test('never routes an official account to requests or likely spam', () {
        // The strictest possible config: everything is maximally suspicious
        // and the threshold is at the floor. Official must still not move.
        final result = classify(
          heuristics: const DmSpamHeuristics(
            spamThreshold: 1,
            weightNoDivineVideos: 100,
            weightNewAccount: 100,
            weightNoProfileMetadata: 100,
            weightNoMutualConnections: 100,
            weightFollowsMe: 0,
            weightPerMutualConnection: 0,
            weightEstablishedAccount: 0,
            weightHasDivineVideos: 0,
            weightPriorPublicInteraction: 0,
          ),
        );

        final officialTitles = result.official.map(fixtures.titleFor);
        expect(officialTitles, containsAll(['DivineHQ', 'Divine Support']));
        for (final conversation in [...result.requests, ...result.likelySpam]) {
          expect(
            fixtures.titleFor(conversation),
            isNot(anyOf('DivineHQ', 'Divine Support')),
          );
        }
      });
    });

    group('inbox', () {
      test('includes conversations the user has replied to', () {
        final result = classify();
        expect(
          result.inbox.every(
            (c) => c.currentUserHasSent || _allFollowed(fixtures, c),
          ),
          isTrue,
        );
      });

      test('includes a followed sender the user has never replied to', () {
        final result = classify();
        final titles = result.inbox.map(fixtures.titleFor);
        expect(titles, contains('Sofia Marchetti'));
      });

      test('keeps a group containing one unfollowed spammer out of inbox', () {
        final result = classify();
        final mixedGroup = fixtures.dmConversations.firstWhere(
          (c) => fixtures.titleFor(c).contains('and 1 others'),
        );
        expect(result.inbox, isNot(contains(mixedGroup)));
        expect(
          [...result.requests, ...result.likelySpam],
          contains(mixedGroup),
        );
      });
    });

    group('likelySpam', () {
      test('catches the unambiguous spam senders at default weights', () {
        final result = classify();
        final titles = result.likelySpam.map(fixtures.titleFor).toList();

        expect(
          titles,
          containsAll(<String>[
            'crypto_signals_daily',
            'FREE V-BUCKS GIVEAWAY',
            'noname',
          ]),
        );
      });

      test('leaves plausible first contact in requests at default weights', () {
        final result = classify();
        final requestTitles = result.requests.map(fixtures.titleFor).toList();

        expect(
          requestTitles,
          containsAll(<String>[
            'Priya Raman',
            'Tobias Lund',
            'Nadia Broussard',
          ]),
        );
      });

      test('empties as the threshold rises past every score', () {
        final result = classify(
          heuristics: const DmSpamHeuristics(spamThreshold: 1000),
        );
        expect(result.likelySpam, isEmpty);
      });

      test('swallows every request as the threshold drops to zero', () {
        final result = classify(
          heuristics: const DmSpamHeuristics(spamThreshold: -1000),
        );
        expect(result.requests, isEmpty);
        expect(result.likelySpam, isNotEmpty);
      });
    });

    group('verdicts', () {
      test('explains every conversation it classified', () {
        final result = classify();
        expect(
          result.verdicts.keys.toSet(),
          equals(fixtures.dmConversations.map((c) => c.id).toSet()),
        );
      });

      test('partitions without dropping or duplicating a conversation', () {
        final result = classify();
        final all = [
          ...result.official,
          ...result.inbox,
          ...result.requests,
          ...result.likelySpam,
        ];
        expect(all, hasLength(fixtures.dmConversations.length));
        expect(all.map((c) => c.id).toSet(), hasLength(all.length));
      });
    });

    group('weakest link', () {
      // The room's verdict must come from whichever unfollowed participant
      // the scorer itself rates worst, not from a separate ranking formula.
      const popular = DmSenderSignals(
        followsMe: true,
        mutualConnectionCount: 3,
        divineVideoCount: 40,
        daysSinceFirstObserved: 400,
        hasProfileMetadata: true,
        hasPriorPublicInteraction: true,
        recentFirstContactCount: 25,
      );
      const brandNew = DmSenderSignals(daysSinceFirstObserved: 1);

      int soloScore(DmSenderSignals signals) =>
          const DmInboxClassifier(officialIdentities: {})
              .classify(
                [
                  DmConversation(
                    id: 'solo',
                    participantPubkeys: [_me, _stranger],
                    isGroup: false,
                    createdAt: 0,
                  ),
                ],
                userPubkey: _me,
                isFollowing: (_) => false,
                signalsFor: (_) => signals,
              )
              .verdicts['solo']!
              .score;

      test('a room inherits its riskiest member, not its best-ranked', () {
        final establishedAlone = soloScore(popular);
        final brandNewAlone = soloScore(brandNew);
        expect(
          brandNewAlone,
          greaterThan(establishedAlone),
          reason: 'the brand-new account is the genuinely riskier member',
        );

        final verdict = const DmInboxClassifier(officialIdentities: {})
            .classify(
              [
                DmConversation(
                  id: 'room',
                  participantPubkeys: [_me, _stranger, _other]..sort(),
                  isGroup: true,
                  createdAt: 0,
                ),
              ],
              userPubkey: _me,
              isFollowing: (_) => false,
              signalsFor: (pubkey) => pubkey == _stranger ? popular : brandNew,
            )
            .verdicts['room']!;

        expect(verdict.bucket, DmInboxBucket.likelySpam);
        expect(
          verdict.score,
          equals(
            brandNewAlone + const DmSpamHeuristics().weightUnknownGroupInvite,
          ),
        );
      });

      test('the reasons shown belong to the member that set the score', () {
        final verdict = const DmInboxClassifier(officialIdentities: {})
            .classify(
              [
                DmConversation(
                  id: 'room',
                  participantPubkeys: [_me, _stranger, _other]..sort(),
                  isGroup: true,
                  createdAt: 0,
                ),
              ],
              userPubkey: _me,
              isFollowing: (_) => false,
              signalsFor: (pubkey) => pubkey == _stranger ? popular : brandNew,
            )
            .verdicts['room']!;

        final labels = verdict.reasons.map((r) => r.label);
        expect(labels, contains('New account'));
        expect(labels, contains('Has not posted on Divine'));
        // The established creator's mitigations must not describe this room.
        expect(labels, isNot(contains('Follows you')));
        expect(labels, isNot(contains('You have interacted before')));
        expect(labels, isNot(contains('Long-standing account')));
      });
    });

    group('group invite weight', () {
      test('a 1:1 does not earn the group weight when isGroup has drifted', () {
        // `DmConversation.isGroup` is written from `participants.length > 2`
        // and rewritten on every upsert, so it can disagree with the row's
        // real participants (#5374). The weight must follow the participants.
        DmVerdict verdictFor({required bool isGroup}) {
          final conversation = DmConversation(
            id: 'drifted',
            participantPubkeys: [_me, _stranger]..sort(),
            isGroup: isGroup,
            createdAt: 0,
          );
          return const DmInboxClassifier(officialIdentities: {})
              .classify(
                [conversation],
                userPubkey: _me,
                isFollowing: (_) => false,
                signalsFor: (_) => const DmSenderSignals(
                  daysSinceFirstObserved: 200,
                  divineVideoCount: 4,
                  hasProfileMetadata: true,
                  mutualConnectionCount: 1,
                ),
              )
              .verdicts['drifted']!;
        }

        final honest = verdictFor(isGroup: false);
        final drifted = verdictFor(isGroup: true);

        expect(honest.score, equals(-40), reason: 'baseline is pinned');
        expect(drifted.score, equals(honest.score));
        expect(
          drifted.reasons.map((r) => r.label),
          isNot(contains('Added you to a group')),
        );
      });

      test('a real group with two unknown participants still earns it', () {
        final conversation = DmConversation(
          id: 'group',
          participantPubkeys: [_me, _stranger, _other]..sort(),
          // Deliberately false: the verdict must not depend on this column.
          isGroup: false,
          createdAt: 0,
        );

        final verdict = const DmInboxClassifier(officialIdentities: {})
            .classify(
              [conversation],
              userPubkey: _me,
              isFollowing: (_) => false,
              signalsFor: (_) => const DmSenderSignals(
                daysSinceFirstObserved: 200,
                divineVideoCount: 4,
                hasProfileMetadata: true,
                mutualConnectionCount: 1,
              ),
            )
            .verdicts['group']!;

        expect(
          verdict.reasons.map((r) => r.label),
          contains('Added you to a group'),
        );
      });
    });
  });
}

/// Synthetic 64-character participant keys for hand-built conversations.
String _key(String seed) {
  final buffer = StringBuffer();
  while (buffer.length < 64) {
    buffer.write(seed);
  }
  return buffer.toString().substring(0, 64);
}

final _me = _key('9a');
final _stranger = _key('7f');
final _other = _key('8e');

bool _allFollowed(DmInboxFixtures fixtures, conversation) {
  final others = (conversation.participantPubkeys as List<String>)
      .where((pk) => pk != fixtures.userPubkey)
      .toSet();
  return others.isNotEmpty && others.every(fixtures.isFollowing);
}
