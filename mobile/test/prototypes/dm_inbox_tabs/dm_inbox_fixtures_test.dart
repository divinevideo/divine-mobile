// ABOUTME: PROTOTYPE (#8076) — pins how fixture rows are titled.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';

void main() {
  group(DmInboxFixtures, () {
    late DmInboxFixtures fixtures;

    setUp(() => fixtures = DmInboxFixtures.build());

    group('titleFor', () {
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
