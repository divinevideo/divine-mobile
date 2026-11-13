// ABOUTME: PROTOTYPE (#8076) — pins how fixture rows are titled.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';

void main() {
  group(DmInboxFixtures, () {
    late DmInboxFixtures fixtures;

    setUp(() => fixtures = DmInboxFixtures.build());

    group('officialTitleFor', () {
      test('names all counterparties consistently and deduplicates them', () {
        final others = fixtures.officialIdentities.keys.take(2).toList();
        final names = (others.toList()..sort())
            .map(fixtures.displayNameFor)
            .join(', ');
        expect(names, 'DivineHQ, Divine Support');
        for (final participants in [others, others.reversed.toList()]) {
          final room = DmConversation(
            id: 'title',
            participantPubkeys: [
              fixtures.userPubkey,
              ...participants,
              participants.first,
            ],
            isGroup: true,
            createdAt: 0,
          );
          expect(fixtures.officialTitleFor(room), names);
        }
      });
    });

    group('titleFor', () {
      test(
        'mixed rooms lead with a non-official participant in either order',
        () {
          final mixed = fixtures.dmConversations.firstWhere(
            (c) => c.lastMessageContent == 'Synthetic mixed-room message',
          );
          final others = mixed.participantPubkeys
              .where((pk) => pk != fixtures.userPubkey)
              .toList();
          expect(fixtures.displayNameFor(others.first), 'Divine Support');
          for (final participants in [others, others.reversed.toList()]) {
            final room = mixed.copyWith(
              participantPubkeys: [fixtures.userPubkey, ...participants],
            );
            expect(fixtures.titleFor(room), 'Ines Duarte and 1 other');
          }
        },
      );

      test(
        'ordinary and all-official rooms retain their leading participant',
        () {
          final official = fixtures.officialIdentities.keys.take(2).toList();
          final ordinary = fixtures.senders.keys
              .where((pk) => !fixtures.officialIdentities.containsKey(pk))
              .take(2)
              .toList();
          expect(ordinary, hasLength(2));
          for (final participants in [
            ordinary,
            ordinary.reversed.toList(),
            official,
            official.reversed.toList(),
          ]) {
            final room = DmConversation(
              id: 'unchanged-title',
              participantPubkeys: [fixtures.userPubkey, ...participants],
              isGroup: true,
              createdAt: 0,
            );
            expect(
              fixtures.titleFor(room),
              '${fixtures.displayNameFor(participants.first)} and 1 other',
            );
          }
        },
      );

      Iterable<String> titlesOfGroupsWith(int others) => fixtures
          .dmConversations
          .where(
            (c) =>
                c.participantPubkeys
                    .where((pk) => pk != fixtures.userPubkey)
                    .length ==
                others,
          )
          .map(fixtures.titleFor);

      test('names one other member in the singular', () {
        final titles = titlesOfGroupsWith(2);

        expect(titles, isNotEmpty);
        expect(titles, everyElement(endsWith(' and 1 other')));
      });

      test('names several other members in the plural', () {
        final titles = titlesOfGroupsWith(3);

        expect(titles, isNotEmpty);
        expect(titles, everyElement(endsWith(' and 2 others')));
      });
    });
  });
}
