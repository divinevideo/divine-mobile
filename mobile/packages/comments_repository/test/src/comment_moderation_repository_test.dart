import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _ownerKey = _hex(1);
final String _strangerKey = _hex(2);
final String _owner = getPublicKey(_ownerKey);
final String _stranger = getPublicKey(_strangerKey);
const _commenter =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _otherCommenter =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
final String _coordinate = '34236:$_owner:video-dtag';
final String _videoIdentifier = '$videoRepliesModerationPrefix$_coordinate';
const _videoReplyAddress = '34236:$_commenter:reply-dtag';

const _commentA =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _commentB =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _commentC =
    '3333333333333333333333333333333333333333333333333333333333333333';

Comment _comment(String id, {String? addressableId}) => Comment(
  id: id,
  content: 'comment',
  authorPubkey: _commenter,
  createdAt: DateTime.utc(2026),
  rootEventId: 'root',
  rootAuthorPubkey: _owner,
  rootAddressableId: _coordinate,
  addressableId: addressableId,
);

Event _moderationEvent({
  required String identifier,
  required List<List<String>> tags,
  String? pubkey,
  int createdAt = 1000,
  String content = '',
}) => Event(
  pubkey ?? _owner,
  commentModerationKind,
  [
    ['d', identifier],
    ...tags,
  ],
  content,
  createdAt: createdAt,
)..sign(pubkey == _stranger ? _strangerKey : _ownerKey);

void main() {
  group(CommentModerationRepository, () {
    late _MockNostrClient nostrClient;
    late CommentModerationRepository repository;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      when(() => nostrClient.publicKey).thenReturn(_owner);
      repository = CommentModerationRepository(nostrClient: nostrClient);
    });

    /// Answers every moderation read with [events].
    void answerReads(
      List<Event> events, {
      bool timedOut = false,
      bool noRelays = false,
    }) {
      final result = (events: events, timedOut: timedOut, noRelays: noRelays);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => result);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer((_) async => result);
    }

    /// Answers every publish with relays accepting it, or none when
    /// [accepted] is false.
    void answerPublishes({bool accepted = true}) {
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: accepted ? const ['wss://relay.test'] : const [],
          rejectedBy: accepted
              ? const {}
              : const {'wss://relay.test': 'blocked: test'},
          noResponseFrom: const [],
        ),
      );
    }

    /// The single event the repository published.
    Event publishedEvent() =>
        verify(
              () => nostrClient.publishEventAwaitOk(
                captureAny(),
                timeout: any(named: 'timeout'),
              ),
            ).captured.single
            as Event;

    void expectNothingPublished() => verifyNever(
      () => nostrClient.publishEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
      ),
    );

    group('account changes', () {
      test(
        'refuses publication if the account changes during the read',
        () async {
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer((_) async {
            when(() => nostrClient.publicKey).thenReturn(_stranger);
            return (events: <Event>[], timedOut: false, noRelays: false);
          });
          await expectLater(
            repository.hideComment(
              rootAddressableId: _coordinate,
              comment: _comment(_commentA),
            ),
            throwsA(isA<CommentModerationFailedException>()),
          );
          expectNothingPublished();
        },
      );
    });

    group('horizontal video coordinates', () {
      final horizontalRoot = '34235:$_owner:video-dtag';
      test(
        'reads moderation under the existing Divine curation identifier',
        () async {
          answerReads([
            _moderationEvent(
              identifier: _videoIdentifier,
              tags: [
                ['e', _commentA, '', 'hidden'],
              ],
            ),
          ]);
          final moderation = await repository.loadModeration(
            rootAddressableId: horizontalRoot,
          );
          expect(moderation.hides(_comment(_commentA)), isTrue);
          final filters =
              verify(
                    () => nostrClient.queryEventsDetailed(
                      captureAny(),
                      timeout: any(named: 'timeout'),
                    ),
                  ).captured.single
                  as List<Filter>;
          expect(filters.single.toJson()['#d'], contains(_videoIdentifier));
        },
      );

      test(
        'shares the identifier and clears legacy reply hides on restore',
        () async {
          answerReads([
            _moderationEvent(
              identifier: _videoIdentifier,
              tags: [
                ['a', _coordinate],
                ['a', _videoReplyAddress, '', 'hidden'],
              ],
            ),
          ]);
          answerPublishes();
          await repository.restoreComment(
            rootAddressableId: horizontalRoot,
            comment: _comment(
              _commentA,
              addressableId: '34235:$_commenter:reply-dtag',
            ),
            authorAutoHidden: false,
          );
          final event = publishedEvent();
          expect(event.dTagValue, _videoIdentifier);
          expect(event.tags, contains(equals(['a', horizontalRoot])));
          expect(
            event.tags,
            isNot(contains(equals(['a', _videoReplyAddress, '', 'hidden']))),
          );
          expect(
            event.tags.where(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'a' &&
                  (tag.length < 4 || tag[3].isEmpty),
            ),
            hasLength(1),
          );
        },
      );
    });

    group('moderation snapshots', () {
      test(
        'observes a native horizontal root through its shared Divine key',
        () async {
          final events = LatestAddressableEvents();
          addTearDown(events.dispose);
          final scoped = CommentModerationRepository(
            nostrClient: nostrClient,
            latestEvents: events,
          );
          final root = '34235:$_owner:video-dtag';
          final changes = StreamIterator<int>(
            scoped.watchModeration(rootAddressableId: root),
          );
          addTearDown(changes.cancel);
          expect(await changes.moveNext(), isTrue);
          expect(changes.current, 0);
          events.remember(
            _moderationEvent(
              identifier: _videoIdentifier,
              tags: [
                ['e', _commentA, '', 'hidden'],
              ],
            ),
          );
          expect(await changes.moveNext(), isTrue);
          expect(changes.current, 1);
          final snapshot = scoped.knownModeration(rootAddressableId: root);
          expect(snapshot.revision, 1);
          expect(snapshot.moderation.hiddenCommentIds, contains(_commentA));
        },
      );

      test(
        'watches only the video and creator-wide policy coordinates',
        () async {
          final events = LatestAddressableEvents();
          addTearDown(events.dispose);
          final scoped = CommentModerationRepository(
            nostrClient: nostrClient,
            latestEvents: events,
          );
          final changes = StreamIterator<int>(
            scoped.watchModeration(rootAddressableId: _coordinate),
          );
          addTearDown(changes.cancel);
          expect(await changes.moveNext(), isTrue);
          expect(changes.current, 0);
          events
            ..remember(
              _moderationEvent(
                pubkey: _stranger,
                identifier: _videoIdentifier,
                tags: const [],
              ),
            )
            ..remember(
              _moderationEvent(
                identifier: '${_videoIdentifier}other',
                tags: const [],
              ),
            )
            ..remember(
              _moderationEvent(
                identifier: hiddenCommentersIdentifier,
                tags: [
                  ['p', _commenter],
                ],
              ),
            );
          expect(await changes.moveNext(), isTrue);
          expect(changes.current, 3);
          expect(
            scoped
                .knownModeration(rootAddressableId: _coordinate)
                .moderation
                .autoHiddenAuthors,
            contains(_commenter),
          );
          events.remember(
            _moderationEvent(
              identifier: _videoIdentifier,
              tags: [
                ['e', _commentA, '', 'hidden'],
              ],
            ),
          );
          expect(await changes.moveNext(), isTrue);
          expect(changes.current, 4);
          final snapshot = scoped.knownModeration(
            rootAddressableId: _coordinate,
          );
          expect(snapshot.revision, 4);
          expect(snapshot.moderation.hiddenCommentIds, contains(_commentA));
        },
      );

      test(
        'has an empty snapshot and finite watch without a valid root',
        () async {
          final snapshot = repository.knownModeration(
            rootAddressableId: 'invalid',
          );
          expect(snapshot.moderation, CommentModeration.empty);
          expect(snapshot.revision, 0);
          expect(
            await repository
                .watchModeration(rootAddressableId: 'invalid')
                .toList(),
            [0],
          );
        },
      );
    });

    group('ownerOf', () {
      test('returns the pubkey a coordinate names', () {
        expect(CommentModerationRepository.ownerOf(_coordinate), _owner);
      });

      test('keeps a d-tag that contains colons', () {
        expect(
          CommentModerationRepository.ownerOf('34236:$_owner:a:b'),
          _owner,
        );
      });

      test('returns null for a coordinate without a valid pubkey', () {
        expect(CommentModerationRepository.ownerOf('34236:nope:d'), isNull);
        expect(CommentModerationRepository.ownerOf('34236'), isNull);
      });
    });

    group('loadModeration', () {
      test('returns no moderation for a coordinate without an owner', () async {
        final moderation = await repository.loadModeration(
          rootAddressableId: 'not-a-coordinate',
        );

        expect(moderation, CommentModeration.empty);
        verifyNever(
          () => nostrClient.queryEventsDetailed(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('asks the owner for the video and the account event', () async {
        answerReads(const []);

        await repository.loadModeration(rootAddressableId: _coordinate);

        final filters =
            verify(
                  () => nostrClient.queryEventsDetailed(
                    captureAny(),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as List<Filter>;
        expect(filters.single.kinds, [commentModerationKind]);
        expect(filters.single.authors, [_owner]);
        expect(filters.single.d, [
          _videoIdentifier,
          hiddenCommentersIdentifier,
        ]);
      });

      test('reads hidden, restored and auto-hidden entries', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['a', _coordinate],
              ['e', _commentA, '', 'hidden'],
              ['e', _commentB.toUpperCase(), '', 'restored'],
              ['a', _videoReplyAddress, '', 'hidden'],
              // Not moderation: a pin, an unmarked or unknown entry, and
              // entries that name no comment.
              ['e', _commentC, '', 'pinned'],
              ['e', _commentC],
              ['e', _commentC, '', 'other'],
              ['e', 'not-an-id', '', 'hidden'],
              ['a', 'not-an-address', '', 'hidden'],
            ],
          ),
          _moderationEvent(
            identifier: hiddenCommentersIdentifier,
            tags: [
              ['p', _commenter],
              ['p', 'not-a-pubkey'],
            ],
          ),
        ]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(
          moderation,
          const CommentModeration(
            hiddenCommentIds: {_commentA, _videoReplyAddress},
            restoredCommentIds: {_commentB},
            autoHiddenAuthors: {_commenter},
          ),
        );
      });

      test('ignores moderation signed by anyone but the owner', () async {
        answerReads([
          _moderationEvent(
            pubkey: _stranger,
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
            ],
          ),
          _moderationEvent(
            pubkey: _stranger,
            identifier: hiddenCommentersIdentifier,
            tags: [
              ['p', _commenter],
            ],
          ),
        ]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation, CommentModeration.empty);
      });

      test('ignores events of another kind or without a d tag', () async {
        answerReads([
          Event(_owner, 1, [
            ['d', _videoIdentifier],
            ['e', _commentA, '', 'hidden'],
          ], ''),
          Event(_owner, commentModerationKind, [
            ['e', _commentA, '', 'hidden'],
          ], ''),
        ]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation, CommentModeration.empty);
      });

      test('keeps the newest event of the owner', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            createdAt: 2000,
            tags: [
              ['e', _commentB, '', 'hidden'],
            ],
          ),
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
            ],
          ),
        ]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.hiddenCommentIds, {_commentB});
      });

      test(
        'falls back to the moderation seen last when a read fails',
        () async {
          answerReads([
            _moderationEvent(
              identifier: _videoIdentifier,
              tags: [
                ['e', _commentA, '', 'hidden'],
              ],
            ),
          ]);
          await repository.loadModeration(rootAddressableId: _coordinate);
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(Exception('relay down'));

          final moderation = await repository.loadModeration(
            rootAddressableId: _coordinate,
          );

          expect(moderation.hiddenCommentIds, {_commentA});
        },
      );

      test('shows every comment when the first read fails', () async {
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('relay down'));

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation, CommentModeration.empty);
      });
    });

    group('hideComment', () {
      test(
        'adds the hide and keeps every other entry, tag and the content',
        () async {
          answerReads([
            _moderationEvent(
              identifier: _videoIdentifier,
              content: 'kept',
              tags: [
                ['a', _coordinate],
                ['alt', 'kept'],
                ['client', 'divine'],
                ['a', _videoReplyAddress, '', 'pinned'],
                ['e', _commentB, '', 'restored'],
                ['e', _commentA, '', 'restored'],
              ],
            ),
          ]);
          answerPublishes();

          await repository.hideComment(
            rootAddressableId: _coordinate,
            comment: _comment(_commentA),
          );

          final event = publishedEvent();
          expect(event.kind, commentModerationKind);
          expect(event.pubkey, _owner);
          expect(event.content, 'kept');
          expect(event.tags, [
            ['d', _videoIdentifier],
            ['a', _coordinate],
            ['alt', 'kept'],
            ['a', _videoReplyAddress, '', 'pinned'],
            ['e', _commentB, '', 'restored'],
            ['e', _commentA, '', 'hidden'],
          ]);
        },
      );

      test('names a video reply by its address and keeps its pin', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['a', _videoReplyAddress, '', 'pinned'],
              ['e', _commentA, '', 'restored'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA, addressableId: _videoReplyAddress),
        );

        expect(publishedEvent().tags.skip(2), [
          ['a', _videoReplyAddress, '', 'pinned'],
          ['a', _videoReplyAddress, '', 'hidden'],
        ]);
      });

      test('publishes a replacement newer than the current event', () async {
        final future = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100;
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            createdAt: future,
            tags: [],
          ),
        ]);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
        );

        expect(publishedEvent().createdAt, future + 1);
      });

      test('starts the list when the owner has none', () async {
        answerReads(const []);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
        );

        final event = publishedEvent();
        expect(event.content, isEmpty);
        expect(event.tags, [
          ['d', _videoIdentifier],
          ['a', _coordinate],
          ['e', _commentA, '', 'hidden'],
        ]);
      });

      test('serves the saved hide before relays do', () async {
        answerReads(const []);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
        );
        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.hiddenCommentIds, {_commentA});
      });

      test('refuses to moderate a video the account does not own', () async {
        answerReads(const []);
        answerPublishes();

        await expectLater(
          repository.hideComment(
            rootAddressableId: '34236:$_stranger:video-dtag',
            comment: _comment(_commentA),
          ),
          throwsA(isA<CommentModerationFailedException>()),
        );
        expectNothingPublished();
      });

      test(
        'publishes nothing when the current list cannot be read in full',
        () async {
          answerReads(const [], timedOut: true);
          answerPublishes();

          await expectLater(
            repository.hideComment(
              rootAddressableId: _coordinate,
              comment: _comment(_commentA),
            ),
            throwsA(isA<CommentModerationFailedException>()),
          );
          expectNothingPublished();
        },
      );

      test('publishes nothing when no relay is reachable', () async {
        answerReads(const [], noRelays: true);
        answerPublishes();

        await expectLater(
          repository.hideComment(
            rootAddressableId: _coordinate,
            comment: _comment(_commentA),
          ),
          throwsA(isA<CommentModerationFailedException>()),
        );
        expectNothingPublished();
      });

      test('throws when the read itself throws', () async {
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
          ),
        ).thenThrow(Exception('socket closed'));

        await expectLater(
          repository.hideComment(
            rootAddressableId: _coordinate,
            comment: _comment(_commentA),
          ),
          throwsA(isA<CommentModerationFailedException>()),
        );
      });

      test(
        'throws and keeps the old moderation when no relay accepts',
        () async {
          answerReads(const []);
          answerPublishes(accepted: false);

          await expectLater(
            repository.hideComment(
              rootAddressableId: _coordinate,
              comment: _comment(_commentA),
            ),
            throwsA(isA<CommentModerationFailedException>()),
          );
          final moderation = await repository.loadModeration(
            rootAddressableId: _coordinate,
          );
          expect(moderation, CommentModeration.empty);
        },
      );

      test('throws when the publish itself throws', () async {
        answerReads(const []);
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('signer gone'));

        await expectLater(
          repository.hideComment(
            rootAddressableId: _coordinate,
            comment: _comment(_commentA),
          ),
          throwsA(isA<CommentModerationFailedException>()),
        );
      });
    });

    group('restoreComment', () {
      test('marks a comment by an auto-hidden author restored', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.restoreComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
          authorAutoHidden: true,
        );

        expect(publishedEvent().tags.skip(2), [
          ['e', _commentA, '', 'restored'],
        ]);
      });

      test('only lifts the hide of any other comment', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
              ['e', _commentB, '', 'hidden'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.restoreComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
          authorAutoHidden: false,
        );

        expect(publishedEvent().tags.skip(2), [
          ['e', _commentB, '', 'hidden'],
        ]);
      });

      test('lifts a video reply hidden by its event id as well', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
              ['a', _videoReplyAddress, '', 'hidden'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.restoreComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA, addressableId: _videoReplyAddress),
          authorAutoHidden: false,
        );

        expect(publishedEvent().tags.skip(2), isEmpty);
      });

      test('restores one version of a video reply by its event id', () async {
        answerReads([
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['a', _videoReplyAddress, '', 'hidden'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.restoreComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA, addressableId: _videoReplyAddress),
          authorAutoHidden: true,
        );

        expect(publishedEvent().tags.skip(2), [
          ['e', _commentA, '', 'restored'],
        ]);
      });
    });

    group('updateAutoHiddenAuthors', () {
      test('adds and removes authors and keeps the rest', () async {
        answerReads([
          _moderationEvent(
            identifier: hiddenCommentersIdentifier,
            tags: [
              ['p', _commenter],
              ['p', _stranger],
              ['alt', 'kept'],
              ['client', 'divine'],
            ],
          ),
        ]);
        answerPublishes();

        await repository.updateAutoHiddenAuthors(
          add: [_otherCommenter, _owner, ''],
          remove: [_stranger],
        );

        expect(publishedEvent().tags, [
          ['d', hiddenCommentersIdentifier],
          ['alt', 'kept'],
          ['p', _commenter],
          ['p', _otherCommenter],
        ]);
      });

      test('publishes nothing when nothing changes', () async {
        answerReads([
          _moderationEvent(
            identifier: hiddenCommentersIdentifier,
            tags: [
              ['p', _commenter],
            ],
          ),
        ]);
        answerPublishes();

        await repository.updateAutoHiddenAuthors(
          add: const [_commenter],
          remove: const [_otherCommenter],
        );

        expectNothingPublished();
      });

      test('publishes no empty list for an account without one', () async {
        answerReads(const []);
        answerPublishes();

        await repository.updateAutoHiddenAuthors(remove: const [_commenter]);

        expectNothingPublished();
      });

      test('auto-hides authors on every video of the account', () async {
        answerReads(const []);
        answerPublishes();

        await repository.updateAutoHiddenAuthors(add: const [_commenter]);
        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.autoHiddenAuthors, {_commenter});
      });

      test('throws without a signed-in account', () async {
        when(() => nostrClient.publicKey).thenReturn('');

        await expectLater(
          repository.updateAutoHiddenAuthors(add: const [_commenter]),
          throwsA(isA<CommentModerationFailedException>()),
        );
      });

      test('throws when the current list cannot be read in full', () async {
        answerReads(const [], timedOut: true);

        await expectLater(
          repository.updateAutoHiddenAuthors(add: const [_commenter]),
          throwsA(isA<CommentModerationFailedException>()),
        );
      });
    });

    group('with a store shared with the replies writer', () {
      test('builds on what that writer just published', () async {
        final shared = LatestAddressableEvents();
        repository = CommentModerationRepository(
          nostrClient: nostrClient,
          latestEvents: shared,
        );
        // The replies list hid a video reply; the relay does not serve it
        // back yet.
        shared.remember(
          _moderationEvent(
            identifier: _videoIdentifier,
            createdAt: 2000,
            tags: [
              ['a', _coordinate],
              ['a', _videoReplyAddress, '', 'hidden'],
            ],
          ),
        );
        answerReads([
          _moderationEvent(identifier: _videoIdentifier, tags: const []),
        ]);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
        );

        expect(publishedEvent().tags.skip(2), [
          ['a', _videoReplyAddress, '', 'hidden'],
          ['e', _commentA, '', 'hidden'],
        ]);
        expect(
          shared
              .latest(
                pubkey: _owner,
                kind: commentModerationKind,
                dTag: _videoIdentifier,
              )
              ?.tags
              .last,
          ['e', _commentA, '', 'hidden'],
        );
      });
    });

    // Relays keep the lowest id of two versions signed in the same second
    // (NIP-01), so that is the one whose decisions count.
    group('two versions signed in the same second', () {
      test('honors the one relays keep, whichever arrives first', () async {
        final versions = [
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
            ],
          ),
          _moderationEvent(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentB, '', 'hidden'],
            ],
          ),
        ]..sort((a, b) => b.id.compareTo(a.id));
        final kept = versions.last;
        final keptHides = kept.tags.any((tag) => tag[1] == _commentA)
            ? _commentA
            : _commentB;
        final droppedHides = keptHides == _commentA ? _commentB : _commentA;
        answerReads(versions);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.hides(_comment(keptHides)), isTrue);
        expect(moderation.hides(_comment(droppedHides)), isFalse);
      });
    });

    // Only the owner's own signed event may count, or be signed again.
    group('an event the owner did not sign', () {
      /// The owner's moderation with a signature that does not verify.
      Event unsigned({
        required String identifier,
        required List<List<String>> tags,
        String content = '',
      }) => _moderationEvent(
        identifier: identifier,
        tags: tags,
        content: content,
        createdAt: 2000,
      )..sig = 'ab' * 64;

      test('is not honored by loadModeration', () async {
        answerReads([
          unsigned(
            identifier: _videoIdentifier,
            tags: [
              ['e', _commentA, '', 'hidden'],
            ],
          ),
        ]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.hides(_comment(_commentA)), isFalse);
      });

      test('is not honored when altered after signing', () async {
        final altered = _moderationEvent(
          identifier: _videoIdentifier,
          tags: [
            ['e', _commentA, '', 'restored'],
          ],
        )..tags.add(['e', _commentB, '', 'hidden']);
        answerReads([altered]);

        final moderation = await repository.loadModeration(
          rootAddressableId: _coordinate,
        );

        expect(moderation.hides(_comment(_commentB)), isFalse);
      });

      test('does not have its tags or content signed again', () async {
        answerReads([
          unsigned(
            identifier: _videoIdentifier,
            tags: [
              ['a', _videoReplyAddress, '', 'pinned'],
              ['e', _commentB, '', 'hidden'],
            ],
            content: 'not the owner',
          ),
        ]);
        answerPublishes();

        await repository.hideComment(
          rootAddressableId: _coordinate,
          comment: _comment(_commentA),
        );

        final event = publishedEvent();
        expect(event.content, isEmpty);
        expect(event.tags, [
          ['d', _videoIdentifier],
          ['a', _coordinate],
          ['e', _commentA, '', 'hidden'],
        ]);
      });

      test('does not have its hidden commenters signed again', () async {
        answerReads([
          unsigned(
            identifier: hiddenCommentersIdentifier,
            tags: [
              ['p', _otherCommenter],
            ],
          ),
        ]);
        answerPublishes();

        await repository.updateAutoHiddenAuthors(add: const [_commenter]);

        expect(publishedEvent().tags, [
          ['d', hiddenCommentersIdentifier],
          ['p', _commenter],
        ]);
      });
    });
  });
}
