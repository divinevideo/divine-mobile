// ABOUTME: Tests for RepostResolver - kind 16 repost event resolution.
// ABOUTME: Verifies tag extraction, caching, and relay fetching logic.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/repost_resolver.dart';

void main() {
  group('RepostResolver', () {
    group('extractTags', () {
      test('extracts e tag (event ID reference)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['e', 'abc123eventid'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, equals('abc123eventid'));
        expect(tags.addressableId, isNull);
      });

      test('extracts a tag (addressable reference)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['a', '34236:pubkey123:d-tag-value'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, isNull);
        expect(tags.addressableId, equals('34236:pubkey123:d-tag-value'));
      });

      test('extracts both e and a tags', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['e', 'eventid123'],
            ['a', '34236:pubkey:dtag'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, equals('eventid123'));
        expect(tags.addressableId, equals('34236:pubkey:dtag'));
      });

      test('returns nulls when no relevant tags', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['p', 'somepubkey'],
            ['t', 'hashtag'],
          ],
        );

        final tags = resolver.extractTags(event);

        expect(tags.eventId, isNull);
        expect(tags.addressableId, isNull);
      });
    });

    group('parseAddressableId', () {
      test('parses valid addressable ID', () {
        final resolver = _createResolver();

        final parsed = resolver.parseAddressableId('34236:pubkey123:my-d-tag');

        expect(parsed, isNotNull);
        expect(parsed!.kind, equals(34236));
        expect(parsed.pubkey, equals('pubkey123'));
        expect(parsed.dTag, equals('my-d-tag'));
      });

      test('returns null for invalid format (too few parts)', () {
        final resolver = _createResolver();

        expect(resolver.parseAddressableId('34236:pubkey'), isNull);
        expect(resolver.parseAddressableId('34236'), isNull);
        expect(resolver.parseAddressableId(''), isNull);
      });

      test('returns null for non-numeric kind', () {
        final resolver = _createResolver();

        expect(resolver.parseAddressableId('notanumber:pubkey:dtag'), isNull);
      });

      test('preserves colons in the d tag', () {
        final resolver = _createResolver();

        final parsed = resolver.parseAddressableId(
          '34236:pubkey123:d-tag:with:colons',
        );

        expect(parsed, isNotNull);
        expect(parsed!.dTag, equals('d-tag:with:colons'));
      });
    });

    group('isLikelyVideoRepost', () {
      test('returns true for content with video keywords', () {
        final resolver = _createResolver();

        expect(
          resolver.isLikelyVideoRepost(
            _createRepostEvent(content: 'Check out this video!'),
          ),
          isTrue,
        );
        expect(
          resolver.isLikelyVideoRepost(
            _createRepostEvent(content: 'Amazing clip'),
          ),
          isTrue,
        );
        expect(
          resolver.isLikelyVideoRepost(_createRepostEvent(content: 'file.mp4')),
          isTrue,
        );
      });

      test('returns true for hashtags with video keywords', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['t', 'vine'],
          ],
        );

        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });

      test('returns true for k tag indicating video kind', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(
          tags: [
            ['k', '34236'],
          ],
        );

        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });

      test('returns true by default (conservative approach)', () {
        final resolver = _createResolver();
        final event = _createRepostEvent(content: 'just some text');

        // Current implementation defaults to true to avoid missing content
        expect(resolver.isLikelyVideoRepost(event), isTrue);
      });
    });

    group('createRepostVideoEvent', () {
      test('creates repost with correct metadata', () {
        final resolver = _createResolver();
        final original = _createVideoEvent(
          id: 'original-id',
          pubkey: 'original-author',
        );
        final repostEvent = _createRepostEvent(id: 'repost-id');

        final repost = resolver.createRepostVideoEvent(original, repostEvent);

        expect(repost.isRepost, isTrue);
        expect(repost.reposterPubkey, equals('reposter-pubkey'));
        expect(repost.id, equals('original-id'));
      });
    });

    group('resolve', () {
      test(
        'returns null when the repost has no references',
        () async {
          final resolver = _createResolver();
          final event = _createRepostEvent(
            content: 'not a video',
            tags: [],
          );

          final result = await resolver.resolve(event, fetchFromRelay: false);

          expect(result, isNull);
        },
      );

      test(
        'resolves from cache when original is cached (by addressable)',
        () async {
          final cachedVideo = _createVideoEvent(
            id: 'cached-video-id',
            pubkey: 'author123',
          );

          final resolver = RepostResolver(
            queryEvents: _emptyQuery,
            findByAddressable: (pubkey, dTag) {
              if (pubkey == 'author123' && dTag == 'my-video') {
                return cachedVideo;
              }
              return null;
            },
            findById: (_) => null,
          );

          final repostEvent = _createRepostEvent(
            tags: [
              ['a', '34236:author123:my-video'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNotNull);
          expect(result!.isRepost, isTrue);
          expect(result.id, equals('cached-video-id'));
        },
      );

      test(
        'resolves from cache when original is cached (by event ID)',
        () async {
          final cachedVideo = _createVideoEvent(
            id: 'event-123',
            pubkey: 'author',
          );

          final resolver = RepostResolver(
            queryEvents: _emptyQuery,
            findByAddressable: (_, _) => null,
            findById: (eventId) {
              if (eventId == 'event-123') {
                return cachedVideo;
              }
              return null;
            },
          );

          final repostEvent = _createRepostEvent(
            tags: [
              ['e', 'event-123'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNotNull);
          expect(result!.isRepost, isTrue);
        },
      );

      test(
        'returns null when not cached and fetchFromRelay is false',
        () async {
          final resolver = _createResolver();
          final repostEvent = _createRepostEvent(
            tags: [
              ['a', '34236:author:dtag'],
            ],
          );

          final result = await resolver.resolve(
            repostEvent,
            fetchFromRelay: false,
          );

          expect(result, isNull);
        },
      );

      test('queries both references once with one caller budget', () async {
        final eventId = _syntheticId(1);
        final pubkey = _syntheticId(2);
        const timeout = Duration(seconds: 3);
        var calls = 0;
        late List<Filter> capturedFilters;
        late Duration capturedTimeout;
        var requiredFullSettlement = false;
        final resolver = _createResolver(
          queryEvents:
              (
                filters, {
                required timeout,
                required requireAllRelaysSettled,
              }) async {
                calls++;
                capturedFilters = filters;
                capturedTimeout = timeout;
                requiredFullSettlement = requireAllRelaysSettled;
                return (events: <Event>[], timedOut: false, noRelays: false);
              },
        );

        await resolver.resolve(
          _createRepostEvent(
            tags: [
              ['a', '34236:$pubkey:video:cut'],
              ['e', eventId],
            ],
          ),
          timeout: timeout,
        );

        expect(calls, 1);
        expect(capturedFilters, hasLength(2));
        expect(capturedFilters.first.authors, [pubkey]);
        expect(capturedFilters.first.d, ['video:cut']);
        expect(capturedFilters.last.ids, [eventId]);
        expect(capturedFilters.last.kinds, [34236]);
        expect(capturedTimeout, timeout);
        expect(requiredFullSettlement, isTrue);
      });

      test('caches a conclusively settled miss', () async {
        var calls = 0;
        final resolver = _createResolver(
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (events: <Event>[], timedOut: false, noRelays: false);
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', _syntheticId(3)],
          ],
        );

        await resolver.resolve(repost);
        await resolver.resolve(repost);

        expect(calls, 1);
      });

      test('retries an inconclusive miss after its short TTL', () async {
        var now = DateTime.utc(2026);
        var calls = 0;
        final resolver = _createResolver(
          now: () => now,
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (events: <Event>[], timedOut: true, noRelays: false);
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', _syntheticId(4)],
          ],
        );

        await resolver.resolve(repost);
        now = now.add(const Duration(seconds: 29));
        await resolver.resolve(repost);
        expect(calls, 1);

        now = now.add(const Duration(seconds: 1));
        await resolver.resolve(repost);
        expect(calls, 2);
      });

      test('resolves a recovered original after the long TTL', () async {
        var now = DateTime.utc(2026);
        var calls = 0;
        final eventId = _syntheticId(5);
        final original = _createOriginalEvent(id: eventId);
        final resolver = _createResolver(
          now: () => now,
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (
                  events: calls == 1 ? <Event>[] : [original],
                  timedOut: false,
                  noRelays: false,
                );
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', eventId],
          ],
        );

        expect(await resolver.resolve(repost), isNull);
        now = now.add(const Duration(minutes: 10));

        final result = await resolver.resolve(repost);

        expect(calls, 2);
        expect(result, isNotNull);
        expect(result!.id, eventId);
        expect(result.isRepost, isTrue);
      });

      test('a positive memory lookup overrides an active miss', () async {
        final eventId = _syntheticId(6);
        var calls = 0;
        VideoEvent? cached;
        final resolver = _createResolver(
          findById: (_) => cached,
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (events: <Event>[], timedOut: false, noRelays: false);
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', eventId],
          ],
        );

        expect(await resolver.resolve(repost), isNull);
        cached = _createVideoEvent(id: eventId);

        final result = await resolver.resolve(repost);

        expect(calls, 1);
        expect(result, isNotNull);
        expect(result!.id, eventId);
      });

      test('coalesces concurrent lookups for the same references', () async {
        final queryCompleter = Completer<NostrQueryResult>();
        var calls = 0;
        final resolver = _createResolver(
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) {
                calls++;
                return queryCompleter.future;
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', _syntheticId(7)],
          ],
        );

        final first = resolver.resolve(repost);
        final second = resolver.resolve(repost);
        expect(calls, 1);

        queryCompleter.complete((
          events: <Event>[],
          timedOut: false,
          noRelays: false,
        ));
        await Future.wait([first, second]);
        expect(calls, 1);
      });

      test('treats an answered non-video event as a conclusive miss', () async {
        final eventId = _syntheticId(8);
        var calls = 0;
        final resolver = _createResolver(
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (
                  events: [_createOriginalEvent(id: eventId, kind: 1)],
                  timedOut: false,
                  noRelays: false,
                );
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', eventId],
          ],
        );

        await resolver.resolve(repost);
        await resolver.resolve(repost);

        expect(calls, 1);
      });

      test('bounds the miss cache and evicts the oldest reference', () async {
        var calls = 0;
        final resolver = _createResolver(
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (events: <Event>[], timedOut: false, noRelays: false);
              },
        );

        for (var index = 0; index < 513; index++) {
          await resolver.resolve(
            _createRepostEvent(
              id: _syntheticId(1000 + index),
              tags: [
                ['e', _syntheticId(2000 + index)],
              ],
            ),
          );
        }
        expect(calls, 513);

        await resolver.resolve(
          _createRepostEvent(
            tags: [
              ['e', _syntheticId(2000)],
            ],
          ),
        );
        expect(calls, 514);

        await resolver.resolve(
          _createRepostEvent(
            tags: [
              ['e', _syntheticId(2512)],
            ],
          ),
        );
        expect(calls, 514);
      });

      test('does not long-cache query errors', () async {
        var now = DateTime.utc(2026);
        var calls = 0;
        final resolver = _createResolver(
          now: () => now,
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                throw StateError('query failed');
              },
        );
        final repost = _createRepostEvent(
          tags: [
            ['e', _syntheticId(9)],
          ],
        );

        await resolver.resolve(repost);
        await resolver.resolve(repost);
        expect(calls, 1);

        now = now.add(const Duration(seconds: 30));
        await resolver.resolve(repost);
        expect(calls, 2);
      });

      test('explicit non-video kind skips a misleading video repost', () async {
        var calls = 0;
        final resolver = _createResolver(
          queryEvents:
              (_, {required timeout, required requireAllRelaysSettled}) async {
                calls++;
                return (events: <Event>[], timedOut: false, noRelays: false);
              },
        );
        final repost = _createRepostEvent(
          content: 'Watch this video',
          tags: [
            ['k', '1'],
            ['e', _syntheticId(10)],
          ],
        );

        expect(await resolver.resolve(repost), isNull);
        expect(calls, 0);
      });
    });
  });
}

/// Helper to create a resolver with empty/null callbacks
RepostResolver _createResolver({
  NostrQuery? queryEvents,
  VideoEvent? Function(String, String)? findByAddressable,
  VideoEvent? Function(String)? findById,
  DateTime Function()? now,
  Duration missTtl = const Duration(minutes: 10),
  Duration inconclusiveMissTtl = const Duration(seconds: 30),
}) {
  return RepostResolver(
    queryEvents: queryEvents ?? _emptyQuery,
    findByAddressable: findByAddressable ?? (_, _) => null,
    findById: findById ?? (_) => null,
    now: now,
    missTtl: missTtl,
    inconclusiveMissTtl: inconclusiveMissTtl,
  );
}

Future<NostrQueryResult> _emptyQuery(
  List<Filter> filters, {
  required Duration timeout,
  required bool requireAllRelaysSettled,
}) async => (events: <Event>[], timedOut: false, noRelays: false);

/// Helper to create a repost event (kind 16)
Event _createRepostEvent({
  String id = 'repost-event-id',
  String pubkey = 'reposter-pubkey',
  int createdAt = 1700000000,
  String content = '',
  List<List<String>> tags = const [],
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': 16,
    'tags': tags,
    'content': content,
    'sig': 'signature',
  });
}

/// Helper to create a video event for testing
VideoEvent _createVideoEvent({
  String id = 'video-id',
  String pubkey = 'author-pubkey',
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1700000000,
    content: 'Video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    videoUrl: 'https://example.com/video.mp4',
  );
}

Event _createOriginalEvent({
  required String id,
  String? pubkey,
  String dTag = 'video',
  int kind = 34236,
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey ?? _syntheticId(99),
    'created_at': 1700000000,
    'kind': kind,
    'tags': [
      ['d', dTag],
      ['url', 'https://example.com/video.mp4'],
    ],
    'content': 'Video content',
    'sig': _syntheticId(100),
  });
}

String _syntheticId(int value) => value.toRadixString(16).padLeft(64, '0');
