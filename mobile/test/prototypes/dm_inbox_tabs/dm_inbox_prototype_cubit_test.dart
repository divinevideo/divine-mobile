// ABOUTME: PROTOTYPE (#8076) — pins the prototype cubit's state transitions:
// ABOUTME: session actions reclassify, and a new presentation condition
// ABOUTME: starts from a clean session.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_cubit.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';

void main() {
  group(DmInboxPrototypeCubit, () {
    late DmInboxFixtures fixtures;
    late DmInboxPrototypeCubit cubit;

    setUp(() {
      fixtures = DmInboxFixtures.build();
      cubit = DmInboxPrototypeCubit(fixtures: fixtures);
    });

    tearDown(() => cubit.close());

    DmConversation conversationTitled(String title) => fixtures.dmConversations
        .firstWhere((c) => fixtures.titleFor(c) == title);

    group('initial state', () {
      test('sorts every bucket newest first', () {
        final requests = cubit.state.classification.requests;

        expect(requests, hasLength(greaterThan(1)));
        for (var i = 1; i < requests.length; i++) {
          expect(
            requests[i - 1].effectiveTimestamp,
            greaterThanOrEqualTo(requests[i].effectiveTimestamp),
          );
        }
      });
    });

    group('reply', () {
      test('moves a request to Inbox', () {
        final priya = conversationTitled('Priya Raman');
        expect(cubit.state.classification.requests, contains(priya));

        cubit.reply(priya.id);

        final inboxIds = cubit.state.classification.inbox.map((c) => c.id);
        expect(inboxIds, contains(priya.id));
      });
    });

    group('official reports', () {
      test('records the exact participant without removing their rooms', () {
        final participant = fixtures.officialIdentities.keys.first;
        final before = cubit.state.conversationCount;
        expect(before, fixtures.dmConversations.length);
        expect(cubit.state.session.reportedOfficial, isEmpty);
        cubit.reportOfficial(participant);
        expect(cubit.state.session.reportedOfficial, {participant});
        expect(cubit.state.conversationCount, before);
        cubit.reveal(fixtures.dmConversations.first.id);
        expect(cubit.state.session.reportedOfficial, {participant});
      });
    });

    group('block', () {
      test('hides every conversation with the blocked sender', () {
        final priya = conversationTitled('Priya Raman');
        final sender = priya.participantPubkeys.firstWhere(
          (pk) => pk != fixtures.userPubkey,
        );

        cubit.block(sender);

        final remaining = [
          for (final bucket in DmInboxBucket.values)
            ...cubit.state.classification.bucket(bucket),
        ];
        expect(remaining, isNotEmpty);
        expect(
          remaining.where((c) => c.participantPubkeys.contains(sender)),
          isEmpty,
        );
      });
    });

    group('conversationCount', () {
      test('drops a removed conversation', () {
        final before = cubit.state.conversationCount;
        expect(before, equals(fixtures.dmConversations.length));

        cubit.remove(conversationTitled('Priya Raman').id);

        expect(cubit.state.conversationCount, equals(before - 1));
      });
    });

    group('toggleReasons', () {
      test('expands, then collapses, one row', () {
        cubit.toggleReasons('row');
        expect(cubit.state.explained, equals({'row'}));

        cubit.toggleReasons('row');
        expect(cubit.state.explained, isEmpty);
      });
    });

    group('applySettings', () {
      test('a new presentation clears the session and expanded reasons', () {
        final priya = conversationTitled('Priya Raman');
        cubit
          ..remove(priya.id)
          ..toggleReasons(priya.id);
        expect(cubit.state.session.removed, contains(priya.id));

        cubit.applySettings(
          const DmPrototypeSettings(
            presentation: RequestPresentation.contextWithCaution,
          ),
        );

        expect(cubit.state.session.removed, isEmpty);
        expect(cubit.state.explained, isEmpty);
        expect(cubit.state.classification.requests, contains(priya));
      });

      test('a new placement keeps what the participant did', () {
        final priya = conversationTitled('Priya Raman');
        cubit.remove(priya.id);

        cubit.applySettings(
          const DmPrototypeSettings(
            placement: OfficialPlacement.pinnedInInbox,
          ),
        );

        expect(cubit.state.settings.placement, OfficialPlacement.pinnedInInbox);
        expect(cubit.state.session.removed, contains(priya.id));
      });
    });
  });
}
