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

    DmInboxClassification classify({
      DmSpamHeuristics? heuristics,
      bool Function(String conversationId)? markedNotSpam,
    }) {
      return DmInboxClassifier(
        officialIdentities: fixtures.officialIdentities,
        heuristics: heuristics ?? const DmSpamHeuristics(),
      ).classify(
        fixtures.dmConversations,
        userPubkey: fixtures.userPubkey,
        isFollowing: fixtures.isFollowing,
        signalsFor: fixtures.signalsFor,
        messageSignalsFor: fixtures.messageSignalsFor,
        markedNotSpam: markedNotSpam,
      );
    }

    DmVerdict soloVerdict(
      DmSenderSignals signals, {
      DmMessageSignals message = DmMessageSignals.none,
      bool currentUserHasSent = false,
    }) {
      return const DmInboxClassifier(officialIdentities: {})
          .classify(
            [
              DmConversation(
                id: 'solo',
                participantPubkeys: [_me, _stranger]..sort(),
                isGroup: false,
                createdAt: 0,
                currentUserHasSent: currentUserHasSent,
              ),
            ],
            userPubkey: _me,
            isFollowing: (_) => false,
            signalsFor: (_) => signals,
            messageSignalsFor: (_) => message,
          )
          .verdicts['solo']!;
    }

    group('official', () {
      DmVerdict roomVerdict(
        List<String> others, {
        bool replied = false,
        bool followed = false,
        bool Function(String pubkey)? isFollowing,
        String? sender,
      }) =>
          DmInboxClassifier(officialIdentities: fixtures.officialIdentities)
              .classify(
                [
                  DmConversation(
                    id: 'policy-room',
                    participantPubkeys: [fixtures.userPubkey, ...others],
                    isGroup: others.length > 1,
                    createdAt: 0,
                    currentUserHasSent: replied,
                    lastMessageSenderPubkey: sender,
                  ),
                ],
                userPubkey: fixtures.userPubkey,
                isFollowing: isFollowing ?? (_) => followed,
                signalsFor: (_) => DmSenderSignals.unknown,
              )
              .verdicts['policy-room']!;

      test(
        'a mixed room gets no Official status in either participant order',
        () {
          final official = fixtures.officialIdentities.keys.first;
          for (final others in [
            [official, _stranger],
            [_stranger, official],
          ]) {
            for (final sender in others) {
              final verdict = roomVerdict(others, sender: sender);
              expect(verdict.bucket, DmInboxBucket.requests);
              expect(
                verdict.score,
                const DmSpamHeuristics().weightUnknownGroupInvite,
              );
              expect(verdict.officialParticipants, isEmpty);
            }
          }
        },
      );

      test('mixed rooms retain ordinary reply and follow consent', () {
        final others = [fixtures.officialIdentities.keys.first, _stranger];
        expect(roomVerdict(others, replied: true).bucket, DmInboxBucket.inbox);
        expect(roomVerdict(others, followed: true).bucket, DmInboxBucket.inbox);
      });

      test('following only the stranger does not admit a mixed room', () {
        final verdict = roomVerdict(
          [fixtures.officialIdentities.keys.first, _stranger],
          isFollowing: (pubkey) => pubkey == _stranger,
        );
        expect(verdict.bucket, DmInboxBucket.requests);
      });

      test(
        'a self-only room is not Official even when the viewer is official',
        () {
          final result =
              DmInboxClassifier(
                officialIdentities: {
                  fixtures.userPubkey: fixtures.officialIdentities.values.first,
                },
              ).classify(
                [
                  DmConversation(
                    id: 'self',
                    participantPubkeys: [fixtures.userPubkey],
                    isGroup: false,
                    createdAt: 0,
                  ),
                ],
                userPubkey: fixtures.userPubkey,
                isFollowing: (_) => false,
                signalsFor: (_) => DmSenderSignals.unknown,
              );
          expect(result.verdicts['self']!.bucket, DmInboxBucket.requests);
        },
      );

      test(
        'all-official groups stay Official regardless of participant order',
        () {
          final others = fixtures.officialIdentities.keys.take(2).toList();
          expect(roomVerdict(others).bucket, DmInboxBucket.official);
          expect(
            roomVerdict(others.reversed.toList()).bucket,
            DmInboxBucket.official,
          );
        },
      );

      test('official group verdict retains each participant and role', () {
        final keys = fixtures.officialIdentities.keys;
        final operational = keys.firstWhere(
          (key) => !fixtures.officialIdentities[key]!.isBlockable,
        );
        final team = keys.firstWhere(
          (key) => fixtures.officialIdentities[key]!.isBlockable,
        );
        for (final others in [
          [operational, team],
          [team, operational, team],
        ]) {
          final verdict = roomVerdict(others);
          expect(verdict.bucket, DmInboxBucket.official);
          expect(verdict.officialParticipants, {
            operational: fixtures.officialIdentities[operational],
            team: fixtures.officialIdentities[team],
          });
        }
      });

      test('policy fixtures pin mixed and all-official destinations', () {
        final result = classify();
        final mixed = fixtures.dmConversations.firstWhere(
          (c) => c.lastMessageContent == 'Synthetic mixed-room message',
        );
        final official = fixtures.dmConversations.firstWhere(
          (c) => c.lastMessageContent == 'Synthetic official group message',
        );
        expect(result.verdicts[mixed.id]!.bucket, DmInboxBucket.requests);
        expect(result.verdicts[official.id]!.bucket, DmInboxBucket.official);
      });

      test('routes every canonical Divine account to the official bucket', () {
        final result = classify();

        expect(result.official, hasLength(7));
        expect(
          result.official.map(fixtures.titleFor),
          containsAll(<String>[
            'DivineHQ',
            'Divine Support',
            'Divine Trust & Safety',
            'Divine Moderation',
            'Liz',
            'Rabble',
          ]),
        );
      });

      test('operational accounts are unblockable and team members are not', () {
        final result = classify();
        final identities = <String, DivineOfficialIdentity>{
          for (final conversation in result.official)
            if (result.verdicts[conversation.id]!.officialParticipants.length ==
                1)
              fixtures.titleFor(conversation): result
                  .verdicts[conversation.id]!
                  .officialParticipants
                  .values
                  .single,
        };

        expect(identities['DivineHQ']!.isBlockable, isFalse);
        expect(identities['Divine Support']!.isBlockable, isFalse);
        expect(identities['Liz']!.isBlockable, isTrue);
        expect(identities['Rabble']!.isBlockable, isTrue);
      });

      test('never routes an all-official room to requests or likely spam', () {
        // A very strict config: identity weights raised, mitigations zeroed
        // and the threshold at the floor. Official must still not move.
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
        expect(result.inbox, isNotEmpty);
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
          (c) => fixtures.titleFor(c).endsWith(' and 1 other'),
        );
        expect(result.inbox, isNot(contains(mixedGroup)));
        expect(
          [...result.requests, ...result.likelySpam],
          contains(mixedGroup),
        );
      });
    });

    group('reply consent', () {
      test('a reply alone moves an unfollowed sender into inbox', () {
        const signals = DmSenderSignals(
          daysSinceFirstObserved: 1,
          divineVideoCount: 0,
          hasProfileMetadata: false,
          mutualConnectionCount: 0,
        );

        expect(soloVerdict(signals).bucket, DmInboxBucket.likelySpam);
        expect(
          soloVerdict(signals, currentUserHasSent: true).bucket,
          DmInboxBucket.inbox,
        );
      });

      test('the replied-to unfollowed fixture lands in inbox', () {
        final result = classify();
        final replied = fixtures.dmConversations.firstWhere(
          (c) => fixtures.titleFor(c) == 'Omar Haddad',
        );

        expect(fixtures.isFollowing(replied.participantPubkeys.first), isFalse);
        expect(replied.currentUserHasSent, isTrue);
        expect(result.inbox, contains(replied));
      });
    });

    group('unknown signals', () {
      test('a sender with nothing known is scored neutral, not as zero', () {
        final unknown = soloVerdict(DmSenderSignals.unknown);
        final knownZero = soloVerdict(
          const DmSenderSignals(
            divineVideoCount: 0,
            hasProfileMetadata: false,
            mutualConnectionCount: 0,
          ),
        );

        expect(unknown.score, equals(0));
        expect(unknown.bucket, DmInboxBucket.requests);
        expect(knownZero.score, greaterThanOrEqualTo(50));
        expect(knownZero.bucket, DmInboxBucket.likelySpam);
      });

      test('the unknown-data fixture stays in requests', () {
        final result = classify();
        expect(result.requests.map(fixtures.titleFor), contains('Ines Duarte'));
      });

      test('a loop count does not change the score', () {
        const base = DmSenderSignals(
          divineVideoCount: 3,
          hasProfileMetadata: true,
          mutualConnectionCount: 1,
        );
        const withLoops = DmSenderSignals(
          divineVideoCount: 3,
          hasProfileMetadata: true,
          mutualConnectionCount: 1,
          totalLoopCount: 999999,
        );

        expect(soloVerdict(base).score, isNot(0));
        expect(soloVerdict(withLoops).score, equals(soloVerdict(base).score));
      });
    });

    group('reasons about the message', () {
      test('marks link and media reasons as describing the message', () {
        final verdict = soloVerdict(
          const DmSenderSignals(divineVideoCount: 2),
          message: const DmMessageSignals(
            containsLink: true,
            containsMedia: true,
          ),
        );

        final aboutMessage = verdict.reasons
            .where((r) => r.aboutMessage)
            .map((r) => r.label);
        final aboutSender = verdict.reasons
            .where((r) => !r.aboutMessage)
            .map((r) => r.label);
        expect(
          aboutMessage,
          containsAll(<String>[
            'First message contains a link',
            'First message contains media',
          ]),
        );
        expect(aboutSender, contains('Posts on Divine'));
      });
    });

    group('not spam override', () {
      test('keeps a likely-spam row in requests whatever the weights', () {
        final spam = classify().likelySpam.first;

        final strict = classify(
          heuristics: const DmSpamHeuristics(spamThreshold: 1),
          markedNotSpam: (id) => id == spam.id,
        );

        expect(strict.requests, contains(spam));
        expect(strict.likelySpam, isNot(contains(spam)));
        expect(strict.inbox, isNot(contains(spam)));
      });

      test('does not move a row that was never spam', () {
        final request = classify().requests.first;
        final result = classify(markedNotSpam: (id) => id == request.id);

        expect(result.requests, contains(request));
        expect(
          result.verdicts[request.id]!.reasons.map((r) => r.label),
          isNot(contains('You marked this as not spam')),
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
            'FREE COINS GIVEAWAY',
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
      // Known to have nothing yet — every count is a known zero, not unknown.
      const brandNew = DmSenderSignals(
        daysSinceFirstObserved: 1,
        divineVideoCount: 0,
        hasProfileMetadata: false,
        mutualConnectionCount: 0,
      );

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
        expect(labels, contains('First seen recently'));
        expect(labels, contains('Has not posted on Divine'));
        // The established creator's mitigations must not describe this room.
        expect(labels, isNot(contains('Follows you')));
        expect(labels, isNot(contains('You have interacted before')));
        expect(labels, isNot(contains('Seen on Divine for a long time')));
      });
    });

    group(DmSpamHeuristics, () {
      test('configs with the same values are equal', () {
        expect(
          const DmSpamHeuristics(spamThreshold: 42),
          equals(const DmSpamHeuristics().copyWith(spamThreshold: 42)),
        );
        expect(
          const DmSpamHeuristics(spamThreshold: 42).hashCode,
          equals(const DmSpamHeuristics().copyWith(spamThreshold: 42).hashCode),
        );
      });

      test('rejects configs whose thresholds contradict each other', () {
        expect(
          () =>
              DmSpamHeuristics(newAccountDays: 60, establishedAccountDays: 30),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => const DmSpamHeuristics().copyWith(reporterThreshold: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('a difference in any one field makes configs unequal', () {
        const base = DmSpamHeuristics();
        final variants = [
          base.copyWith(spamThreshold: base.spamThreshold + 1),
          base.copyWith(newAccountDays: base.newAccountDays + 1),
          base.copyWith(
            establishedAccountDays: base.establishedAccountDays + 1,
          ),
          base.copyWith(fanOutThreshold: base.fanOutThreshold + 1),
          base.copyWith(reporterThreshold: base.reporterThreshold + 1),
          base.copyWith(mutualConnectionCap: base.mutualConnectionCap + 1),
          base.copyWith(weightNoDivineVideos: base.weightNoDivineVideos + 1),
          base.copyWith(weightNewAccount: base.weightNewAccount + 1),
          base.copyWith(
            weightNoProfileMetadata: base.weightNoProfileMetadata + 1,
          ),
          base.copyWith(
            weightNoMutualConnections: base.weightNoMutualConnections + 1,
          ),
          base.copyWith(weightContainsLink: base.weightContainsLink + 1),
          base.copyWith(weightContainsMedia: base.weightContainsMedia + 1),
          base.copyWith(weightHighFanOut: base.weightHighFanOut + 1),
          base.copyWith(
            weightReportedByOthers: base.weightReportedByOthers + 1,
          ),
          base.copyWith(
            weightUnknownGroupInvite: base.weightUnknownGroupInvite + 1,
          ),
          base.copyWith(weightFollowsMe: base.weightFollowsMe + 1),
          base.copyWith(
            weightPerMutualConnection: base.weightPerMutualConnection + 1,
          ),
          base.copyWith(
            weightEstablishedAccount: base.weightEstablishedAccount + 1,
          ),
          base.copyWith(weightHasDivineVideos: base.weightHasDivineVideos + 1),
          base.copyWith(
            weightPriorPublicInteraction: base.weightPriorPublicInteraction + 1,
          ),
        ];

        expect(variants, hasLength(20));
        for (final variant in variants) {
          expect(variant, isNot(equals(base)));
        }
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

      test('a sender listed twice is still a one-to-one', () {
        final conversation = DmConversation(
          id: 'duplicated',
          participantPubkeys: [_me, _stranger, _stranger],
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
            .verdicts['duplicated']!;

        expect(
          verdict.reasons.map((r) => r.label),
          isNot(contains('Added you to a group')),
        );
        expect(verdict.score, equals(-40));
      });

      test('a group with a followed member and a stranger earns it', () {
        // Only the stranger is scored, but the followed member does not make
        // the stranger's group invite any less of one.
        final conversation = DmConversation(
          id: 'mixed',
          participantPubkeys: [_me, _stranger, _other]..sort(),
          isGroup: false,
          createdAt: 0,
        );

        final verdict = const DmInboxClassifier(officialIdentities: {})
            .classify(
              [conversation],
              userPubkey: _me,
              isFollowing: (pubkey) => pubkey == _other,
              signalsFor: (_) => const DmSenderSignals(
                daysSinceFirstObserved: 200,
                divineVideoCount: 4,
                hasProfileMetadata: true,
                mutualConnectionCount: 1,
              ),
            )
            .verdicts['mixed']!;

        expect(
          verdict.reasons.map((r) => r.label),
          contains('Added you to a group'),
        );
        expect(
          verdict.score,
          equals(-40 + const DmSpamHeuristics().weightUnknownGroupInvite),
          reason: 'the 1:1 baseline for these signals is pinned at -40',
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

final String _me = _key('9a');
final String _stranger = _key('7f');
final String _other = _key('8e');

bool _allFollowed(DmInboxFixtures fixtures, conversation) {
  final others = (conversation.participantPubkeys as List<String>)
      .where((pk) => pk != fixtures.userPubkey)
      .toSet();
  return others.isNotEmpty && others.every(fixtures.isFollowing);
}
