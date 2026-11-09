import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _Client extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  final key = '1'.padLeft(64, '0');
  final owner = getPublicKey(key);
  final commentId = '2' * 64;
  final replyId = '3' * 64;

  group('concurrent moderation writers', () {
    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(Duration.zero);
    });
    for (final kind in [34236, 34235]) {
      for (final commentsFirst in [true, false]) {
        test(
          'keeps both edits for kind $kind; comments first: $commentsFirst',
          () async {
            final address = '$kind:$owner:synthetic';
            final client = _Client();
            when(() => client.publicKey).thenReturn(owner);
            when(() => client.isDisposed).thenReturn(false);
            when(
              () => client.queryEventsDetailed(
                any(),
                timeout: any(named: 'timeout'),
                useCache: any(named: 'useCache'),
                requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              ),
            ).thenAnswer(
              (_) async =>
                  (events: <Event>[], timedOut: false, noRelays: false),
            );
            final started = Completer<void>();
            final release = Completer<void>();
            final published = <Event>[];
            when(
              () => client.publishEventAwaitOk(
                any(),
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((call) async {
              final event = call.positionalArguments.first as Event;
              event.sign(key);
              published.add(event);
              if (published.length == 1) {
                started.complete();
                await release.future;
              }
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const ['wss://relay.example'],
                rejectedBy: const {},
                noResponseFrom: const [],
              );
            });
            final store = LatestAddressableEvents();
            final comments = CommentModerationRepository(
              nostrClient: client,
              latestEvents: store,
            );
            final replies = VideoResponsesRepository(
              nostrClient: client,
              latestEvents: store,
              signEvent:
                  ({
                    required kind,
                    required content,
                    required tags,
                    createdAt,
                  }) async =>
                      Event(owner, kind, tags, content, createdAt: createdAt)
                        ..sign(key),
            );
            Future<void> hideComment() => comments.hideComment(
              rootAddressableId: address,
              comment: Comment(
                id: commentId,
                content: 'synthetic',
                authorPubkey: '4' * 64,
                createdAt: DateTime.utc(2026),
                rootEventId: '5' * 64,
                rootAuthorPubkey: owner,
                rootAddressableId: address,
              ),
            );
            Future<RepliesCuration> hideReply() => replies.saveCuration(
              RepliesCuration(hiddenIds: {replyId}),
              videoAddress: address,
              previous: const RepliesCuration(),
            );
            final first = commentsFirst ? hideComment() : hideReply();
            await started.future;
            final second = commentsFirst ? hideReply() : hideComment();
            release.complete();
            await Future.wait([first, second]);
            expect(published, hasLength(2));
            expect(
              published.last.createdAt,
              greaterThan(published.first.createdAt),
            );
            expect(
              published.last.tags,
              contains(equals(['e', commentId, '', 'hidden'])),
            );
            expect(
              published.last.tags,
              contains(equals(['e', replyId, '', 'hidden'])),
            );
          },
        );
      }
    }
  });
}
