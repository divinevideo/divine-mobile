// ABOUTME: Tests for the filters CommentsRepository.watchComments subscribes
// ABOUTME: with: a bounded backfill, and video replies on their own filter.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _rootId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _rootAddressableId =
    '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:d';

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('CommentsRepository.watchComments filters', () {
    late _MockNostrClient nostr;
    late CommentsRepository repository;
    late StreamController<Event> relay;

    Future<List<Filter>> subscribedFilters({
      required bool includeVideoReplies,
      String? rootAddressableId,
      DateTime? since,
    }) async {
      repository.watchComments(
        rootEventId: _rootId,
        rootEventKind: EventKind.videoVertical,
        rootAddressableId: rootAddressableId,
        includeVideoReplies: includeVideoReplies,
        since: since,
      );
      return verify(
            () => nostr.subscribe(
              captureAny(),
              subscriptionId: any(named: 'subscriptionId'),
              onEose: any(named: 'onEose'),
            ),
          ).captured.single
          as List<Filter>;
    }

    setUp(() {
      nostr = _MockNostrClient();
      relay = StreamController<Event>.broadcast();
      when(
        () => nostr.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => relay.stream);
      repository = CommentsRepository(nostrClient: nostr);
    });

    tearDown(() => relay.close());

    test('bounds the backfill of comments', () async {
      final filters = await subscribedFilters(includeVideoReplies: false);

      expect(filters, hasLength(1));
      expect(filters.single.kinds, equals([EventKind.comment]));
      expect(filters.single.uppercaseE, equals([_rootId]));
      expect(
        filters.single.limit,
        equals(CommentsRepository.watchBackfillLimit),
      );
    });

    test('asks for comments and video replies in one filter', () async {
      final filters = await subscribedFilters(
        includeVideoReplies: true,
        rootAddressableId: _rootAddressableId,
      );

      // One newest-first set per root tag, not one per kind. Two filters
      // reach back to different depths, and the oldest event the sheet holds
      // sets where paging resumes: a video reply from far back would carry the
      // cursor past every comment between it and the rest.
      expect(
        filters.map((f) => [f.kinds, f.uppercaseE, f.uppercaseA, f.limit]),
        equals([
          [
            [EventKind.comment, EventKind.videoVertical],
            [_rootId],
            null,
            CommentsRepository.watchBackfillLimit,
          ],
          [
            [EventKind.comment, EventKind.videoVertical],
            null,
            [_rootAddressableId],
            CommentsRepository.watchBackfillLimit,
          ],
        ]),
      );
    });

    test('carries the since cursor on every filter', () async {
      final since = DateTime.fromMillisecondsSinceEpoch(2000000);

      final filters = await subscribedFilters(
        includeVideoReplies: true,
        rootAddressableId: _rootAddressableId,
        since: since,
      );

      expect(filters, hasLength(2));
      expect(filters.map((f) => f.since).toSet(), equals({2000}));
    });
  });
}
