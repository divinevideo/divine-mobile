// ABOUTME: PROTOTYPE (#8076) — pins the four-way classifier's invariants.
// ABOUTME: The official-account rules are product requirements, not
// ABOUTME: implementation details, so they get named tests.

import 'package:flutter_test/flutter_test.dart';
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
  });
}

bool _allFollowed(DmInboxFixtures fixtures, conversation) {
  final others = (conversation.participantPubkeys as List<String>)
      .where((pk) => pk != fixtures.userPubkey)
      .toSet();
  return others.isNotEmpty && others.every(fixtures.isFollowing);
}
