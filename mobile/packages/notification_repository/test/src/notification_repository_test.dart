// ABOUTME: Tests for NotificationRepository — covers enrichment, video-anchored
// ABOUTME: grouping by (referencedEventId, kind), follow consolidation, type
// ABOUTME: mapping, and comment truncation.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNotificationsDao extends Mock implements NotificationsDao {}

void main() {
  late _MockFunnelcakeApiClient funnelcakeApiClient;
  late _MockProfileRepository profileRepository;
  late _MockNotificationsDao notificationsDao;
  late NotificationRepository repository;

  const userPubkey = 'user1234567890abcdef';
  const stableCursorId =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const validPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  final validNpub = Nip19.encodePubKey(validPubkey);

  NotificationRepository buildRepository({
    BlockedNotificationFilter? blockFilter,
  }) {
    return NotificationRepository(
      funnelcakeApiClient: funnelcakeApiClient,
      profileRepository: profileRepository,
      notificationsDao: notificationsDao,
      userPubkey: userPubkey,
      blockFilter: blockFilter,
      hydrateOnStart: false,
    );
  }

  setUpAll(() {
    registerFallbackValue(<NotificationCacheRow>[]);
  });

  setUp(() {
    funnelcakeApiClient = _MockFunnelcakeApiClient();
    profileRepository = _MockProfileRepository();
    notificationsDao = _MockNotificationsDao();
    when(
      () => funnelcakeApiClient.notificationsUri(
        pubkey: any(named: 'pubkey'),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
        cursorId: any(named: 'cursorId'),
        types: any(named: 'types'),
      ),
    ).thenAnswer((invocation) {
      final pubkey = invocation.namedArguments[#pubkey] as String;
      final limit = invocation.namedArguments[#limit] as int? ?? 50;
      final cursor = invocation.namedArguments[#cursor] as String?;
      final cursorId = invocation.namedArguments[#cursorId] as String?;
      final types = invocation.namedArguments[#types] as List<String>?;
      final effectiveBefore =
          cursor ?? DateTime.now().millisecondsSinceEpoch.toString();
      final queryParameters = <String, String>{
        'limit': '$limit',
        'before': effectiveBefore,
        'before_id': ?cursorId,
        if (types != null && types.isNotEmpty) 'types': types.join(','),
      };
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications',
      ).replace(queryParameters: queryParameters);
    });
    when(
      () => funnelcakeApiClient.notificationsReadUri(
        pubkey: any(named: 'pubkey'),
      ),
    ).thenAnswer((invocation) {
      final pubkey = invocation.namedArguments[#pubkey] as String;
      return Uri.parse(
        'https://api.example.com/api/users/$pubkey/notifications/read',
      );
    });
    // Default: getVideoStats throws (no metadata fetched). Tests that need a
    // thumbnail override this stub explicitly.
    when(
      () => funnelcakeApiClient.getVideoStats(any()),
    ).thenThrow(const FunnelcakeException('no stats'));
    when(
      () =>
          profileRepository.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer((_) async => <String, UserProfile>{});
    // Default DAO stubs cover the new hydrate / write-through paths so
    // existing tests don't need to know about them. Tests exercising the
    // cache override these explicitly.
    when(
      () => notificationsDao.getAllNotifications(
        limit: any(named: 'limit'),
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => <NotificationRow>[]);
    when(
      () => notificationsDao.replaceAll(
        any(),
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async {});
    repository = buildRepository();
  });

  /// Helper to create a [RelayNotification] with sensible defaults.
  ///
  /// Defaults to a like notification with a non-null `referencedEventId`
  /// so the repository keeps it as a [VideoNotification]. Tests that want
  /// it dropped should pass `referencedEventId: null` explicitly.
  RelayNotification makeNotification({
    String id = 'n1',
    String sourcePubkey = 'pubkey_alice',
    String sourceEventId = 'evt1',
    int sourceKind = 7,
    String notificationType = 'reaction',
    DateTime? createdAt,
    bool read = false,
    String? referencedEventId = 'video_default',
    String? referencedDTag,
    String? rootEventId,
    int? rootEventKind,
    String? rootEventPubkey,
    String? rootDTag,
    String? rootAddressableId,
    String? targetCommentId,
    String? content,
    String? commentContent,
    bool isReferencedVideo = true,
    String? referencedVideoTitle,
    String? referencedVideoThumbnail,
    String? listTitle,
    String? listCoordinate,
  }) {
    return RelayNotification(
      id: id,
      sourcePubkey: sourcePubkey,
      sourceEventId: sourceEventId,
      sourceKind: sourceKind,
      notificationType: notificationType,
      createdAt: createdAt ?? DateTime(2025),
      read: read,
      referencedEventId: referencedEventId,
      referencedDTag: referencedDTag,
      rootEventId: rootEventId,
      rootEventKind: rootEventKind,
      rootEventPubkey: rootEventPubkey,
      rootDTag: rootDTag,
      rootAddressableId: rootAddressableId,
      targetCommentId: targetCommentId,
      content: content,
      commentContent: commentContent,
      isReferencedVideo: isReferencedVideo,
      referencedVideoTitle: referencedVideoTitle,
      referencedVideoThumbnail: referencedVideoThumbnail,
      listTitle: listTitle,
      listCoordinate: listCoordinate,
    );
  }

  void stubProfiles(Map<String, UserProfile> profiles) {
    when(
      () =>
          profileRepository.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer((_) async => profiles);
  }

  void stubNotifications(
    List<RelayNotification> notifications, {
    int unreadCount = 0,
    bool hasMore = false,
    String? nextCursor,
    String? nextCursorId,
  }) {
    when(
      () => funnelcakeApiClient.getNotifications(
        pubkey: any(named: 'pubkey'),
        cursor: any(named: 'cursor'),
        cursorId: any(named: 'cursorId'),
        types: any(named: 'types'),
        requestUri: any(named: 'requestUri'),
        authHeaders: any(named: 'authHeaders'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => NotificationResponse(
        notifications: notifications,
        unreadCount: unreadCount,
        hasMore: hasMore,
        nextCursor: nextCursor,
        nextCursorId: nextCursorId,
      ),
    );
  }

  /// Stubs `getVideoStats(eventId)` to return [stats].
  void stubVideoStats(String eventId, VideoStats stats) {
    when(
      () => funnelcakeApiClient.getVideoStats(eventId),
    ).thenAnswer((_) async => stats);
  }

  /// Stubs `getVideoStats(eventId)` to return a confirmed 404/not-found.
  void stubVideoStatsNotFound(String eventId) {
    when(
      () => funnelcakeApiClient.getVideoStats(eventId),
    ).thenAnswer((_) async => null);
  }

  UserProfile makeProfile(
    String pubkey, {
    String? displayName,
    String? name,
    String? picture,
  }) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const {},
      createdAt: DateTime(2024),
      eventId: 'evt_$pubkey',
      displayName: displayName,
      name: name,
      picture: picture,
    );
  }

  VideoStats makeVideoStats({
    required String id,
    String pubkey = userPubkey,
    String? thumbnail,
    String? title,
    String? dTag,
  }) {
    return VideoStats(
      id: id,
      pubkey: pubkey,
      createdAt: DateTime(2025),
      kind: 34236,
      dTag: dTag ?? 'd_$id',
      title: title ?? '',
      thumbnail: thumbnail ?? '',
      videoUrl: 'https://example.com/$id.mp4',
      reactions: 0,
      comments: 0,
      reposts: 0,
      engagementScore: 0,
    );
  }

  group(NotificationRepository, () {
    group('getNotifications', () {
      test('signs the full first-page notifications URL', () async {
        var signedUrl = '';
        var signedMethod = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            signedMethod = method;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([]);
        stubProfiles({});

        await repository.getNotifications();

        final signedUri = Uri.parse(signedUrl);
        expect(
          '${signedUri.scheme}://${signedUri.host}${signedUri.path}',
          equals('https://api.example.com/api/users/$userPubkey/notifications'),
        );
        expect(signedUri.queryParameters['limit'], equals('20'));
        expect(signedUri.queryParameters['before'], isNotNull);
        expect(int.tryParse(signedUri.queryParameters['before']!), isNotNull);
        expect(signedMethod, equals('GET'));
      });

      test('signs the full paginated notifications URL with cursor', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
        stubProfiles({});

        await repository.getNotifications();
        stubNotifications([], nextCursor: 'cursor_def');

        await repository.getNotifications();

        expect(
          signedUrl,
          equals(
            'https://api.example.com/api/users/$userPubkey/notifications'
            '?limit=20&before=cursor_abc',
          ),
        );
      });

      test(
        'signs the full paginated notifications URL with cursor id',
        () async {
          var signedUrl = '';
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications(
            [],
            nextCursor: '1700000000',
            nextCursorId: stableCursorId,
            hasMore: true,
          );
          stubProfiles({});

          await repository.getNotifications();
          stubNotifications([], nextCursor: '1699999999');

          await repository.getNotifications();

          expect(
            signedUrl,
            equals(
              'https://api.example.com/api/users/$userPubkey/notifications'
              '?limit=20&before=1700000000'
              '&before_id=$stableCursorId',
            ),
          );
        },
      );

      test('signs filtered notifications URL with server types', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([]);
        stubProfiles({});

        await repository.getNotifications(filter: NotificationKind.follow);

        expect(
          signedUrl,
          startsWith(
            'https://api.example.com/api/users/$userPubkey/notifications',
          ),
        );
        final signedUri = Uri.parse(signedUrl);
        expect(signedUri.queryParameters['types'], equals('follow'));
      });

      test('maps likes tab to reaction and zap server types', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([]);
        stubProfiles({});

        await repository.getNotifications(filter: NotificationKind.like);

        final signedUri = Uri.parse(signedUrl);
        expect(signedUri.queryParameters['types'], equals('reaction,zap'));
      });

      test('maps list-add filter to list_add server type', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications([]);
        stubProfiles({});

        await repository.getNotifications(filter: NotificationKind.listAdd);

        final signedUri = Uri.parse(signedUrl);
        expect(signedUri.queryParameters['types'], equals('list_add'));
      });

      test('comment feed keeps comment-target mentions', () async {
        stubNotifications([
          makeNotification(
            id: 'comment_mention',
            notificationType: 'mention',
            sourceKind: 1,
            referencedEventId: null,
            targetCommentId: 'comment_target',
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });

        final page = await repository.getNotifications(
          filter: NotificationKind.comment,
        );

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.mention));
        expect(item.hasCommentTarget, isTrue);
      });

      test('comment feed keeps nested replies', () async {
        stubNotifications([
          makeNotification(
            id: 'nested_reply',
            notificationType: 'reply',
            sourceKind: 1111,
            referencedEventId: 'parent_comment',
            rootEventId: 'root_video',
            targetCommentId: 'parent_comment',
            isReferencedVideo: false,
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });

        final page = await repository.getNotifications(
          filter: NotificationKind.comment,
        );

        expect(page.items, hasLength(1));
        expect(page.items.single.type, equals(NotificationKind.reply));
      });

      test('comment feed excludes video mentions', () async {
        stubNotifications([
          makeNotification(
            id: 'video_mention',
            sourceEventId: 'video_source',
            notificationType: 'mention',
            sourceKind: 34236,
            referencedEventId: 'mentioned_video',
            rootEventId: 'mentioned_video',
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });

        final page = await repository.getNotifications(
          filter: NotificationKind.comment,
        );

        expect(page.items, isEmpty);
      });

      test('keeps independent cursors for filtered feeds', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubProfiles({});
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: any(named: 'types'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) async {
          final types = invocation.namedArguments[#types] as List<String>?;
          final cursor = invocation.namedArguments[#cursor] as String?;
          if (types?.contains('follow') ?? false) {
            return NotificationResponse(
              notifications: const [],
              unreadCount: 0,
              hasMore: cursor == null,
              nextCursor: cursor == null ? 'follow_cursor' : null,
            );
          }
          return NotificationResponse(
            notifications: const [],
            unreadCount: 0,
            hasMore: cursor == null,
            nextCursor: cursor == null ? 'like_cursor' : null,
          );
        });

        await repository.getNotifications(filter: NotificationKind.follow);
        await repository.getNotifications(filter: NotificationKind.like);
        await repository.loadNextPageFor(NotificationKind.follow);

        final signedUri = Uri.parse(signedUrl);
        expect(signedUri.queryParameters['types'], equals('follow'));
        expect(signedUri.queryParameters['before'], equals('follow_cursor'));
      });

      test('explicit cursor override does not leak stored cursor id', () async {
        var signedUrl = '';
        repository = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async {
            signedUrl = url;
            return {'Authorization': 'Nostr test-token'};
          },
        );
        stubNotifications(
          [],
          nextCursor: '1700000000',
          nextCursorId: stableCursorId,
          hasMore: true,
        );
        stubProfiles({});

        await repository.getNotifications();
        stubNotifications([], nextCursor: 'manual_next');

        await repository.getNotifications(cursor: 'manual_cursor');

        expect(
          signedUrl,
          equals(
            'https://api.example.com/api/users/$userPubkey/notifications'
            '?limit=20&before=manual_cursor',
          ),
        );
      });

      test('one like becomes a $VideoNotification with totalCount 1', () async {
        stubNotifications([
          makeNotification(
            sourcePubkey: 'alice_pub',
            referencedEventId: 'video1',
          ),
        ]);
        stubVideoStats(
          'video1',
          makeVideoStats(id: 'video1', thumbnail: 'thumb', title: 'Hello'),
        );
        stubProfiles({
          'alice_pub': makeProfile(
            'alice_pub',
            displayName: 'Alice',
            picture: 'https://example.com/alice.jpg',
          ),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.actors, hasLength(1));
        expect(item.actors.first.displayName, equals('Alice'));
        expect(
          item.actors.first.pictureUrl,
          equals('https://example.com/alice.jpg'),
        );
        expect(item.totalCount, equals(1));
        expect(item.videoEventId, equals('video1'));
        expect(item.videoThumbnailUrl, equals('thumb'));
        expect(item.videoTitle, equals('Hello'));
      });

      test(
        'falls back to a generated display name for missing profiles',
        () async {
          stubNotifications([makeNotification(sourcePubkey: 'unknown_pub')]);
          stubProfiles({});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.first as VideoNotification;
          expect(
            item.actors.first.displayName,
            equals(UserProfile.defaultDisplayNameFor('unknown_pub')),
          );
          expect(item.actors.first.pictureUrl, isNull);
        },
      );

      test('sanitizes explicit display names before rendering', () async {
        stubNotifications([makeNotification(sourcePubkey: 'zalgo_pub')]);
        stubProfiles({
          'zalgo_pub': makeProfile(
            'zalgo_pub',
            displayName: 'A\u0300\u0301\u0302',
          ),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.actors.first.displayName, equals('A\u0300\u0301'));
      });

      test('replaces unpaired surrogates in explicit display names', () async {
        stubNotifications([makeNotification(sourcePubkey: 'surrogate_pub')]);
        stubProfiles({
          'surrogate_pub': makeProfile(
            'surrogate_pub',
            displayName: String.fromCharCodes([0x68, 0x69, 0xD83D]),
          ),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.actors.first.displayName, equals('hi\uFFFD'));
      });

      test('rethrows on API error after logging', () async {
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );

        // BehaviorSubject preserves its prior items across the throw —
        // the seeded empty list stays so downstream consumers don't see
        // spurious item updates — but `lastRefreshError` flips to `true`
        // so the BLoC can render the inline refresh-error affordance.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
        expect(snapshot.lastRefreshError, isTrue);
      });

      test('preserves populated snapshot when refresh throws', () async {
        // First refresh succeeds and populates the snapshot.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final populated = await repository.watchSnapshot().first;
        expect(populated.items, hasLength(1));
        expect(populated.lastRefreshError, isFalse);

        // Second refresh throws — the snapshot must keep the populated
        // items from the first refresh, not revert to empty. This pins
        // the design contract that lets the BLoC's failure state coexist
        // with previously-loaded data (the BehaviorSubject value the
        // snapshot stream emits to subscribers stays at the populated
        // page). `lastRefreshError` flips so the view can render the
        // inline banner.
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.refresh(),
          throwsA(isA<FunnelcakeException>()),
        );

        final after = await repository.watchSnapshot().first;
        expect(after.items, equals(populated.items));
        expect(after.lastRefreshError, isTrue);
      });

      test('repeated throws keep snapshot stable', () async {
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );
        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );

        // Two consecutive throws must not corrupt the items list. The
        // refresh-error flag stays sticky between throws — it only
        // clears on the next successful refresh.
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
        expect(snapshot.lastRefreshError, isTrue);
      });

      test('clears lastRefreshError on next successful refresh', () async {
        // First call throws — flips lastRefreshError to true.
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeException('network error'));

        await expectLater(
          repository.getNotifications(),
          throwsA(isA<FunnelcakeException>()),
        );
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isTrue,
        );

        // Second call succeeds — flag clears.
        stubProfiles({});
        stubNotifications([]);
        await repository.refresh();
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isFalse,
        );
      });

      test('retries first-page fetch on transient 5xx and succeeds on second '
          'attempt', () async {
        stubProfiles({});
        var calls = 0;
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw const FunnelcakeApiException(
              message: 'Internal server error',
              statusCode: 500,
              url: 'https://api.example.com/api/users/x/notifications',
            );
          }
          return const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          );
        });

        final page = await repository.getNotifications();
        expect(page.items, isEmpty);
        expect(calls, equals(2));
        expect(
          (await repository.watchSnapshot().first).lastRefreshError,
          isFalse,
        );
      });

      test(
        'does not retry first-page fetch on 4xx — surfaces error immediately',
        () async {
          var calls = 0;
          when(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async {
            calls++;
            throw const FunnelcakeApiException(
              message: 'unauthorized',
              statusCode: 401,
              url: 'https://api.example.com/api/users/x/notifications',
            );
          });

          await expectLater(
            repository.getNotifications(),
            throwsA(isA<FunnelcakeApiException>()),
          );
          expect(calls, equals(1));
        },
      );

      test('persists first-page items to DAO on success', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        verify(
          () => notificationsDao.replaceAll(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });

      test(
        'persists listAdd cache fields without degrading to system',
        () async {
          const listCoordinate = '30005:pubkey_alice:literature';
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([
            makeNotification(
              id: 'list_add_1',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: 'video_1',
              listTitle: 'Literature',
              listCoordinate: listCoordinate,
            ),
          ]);

          await repository.refresh();

          final rows =
              verify(
                    () => notificationsDao.replaceAll(
                      captureAny(),
                      ownerPubkey: any(named: 'ownerPubkey'),
                    ),
                  ).captured.single
                  as List<NotificationCacheRow>;
          final row = rows.singleWhere((r) => r.type != 'seen_marker');
          expect(row.type, equals('listAdd'));
          expect(row.targetEventId, equals('video_1'));
          expect(row.targetPubkey, equals(listCoordinate));
          expect(row.content, equals('Literature'));
        },
      );

      test('passes cursor for pagination', () async {
        stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
        stubProfiles({});

        final page = await repository.getNotifications();
        expect(page.nextCursor, equals('cursor_abc'));
        expect(page.hasMore, isTrue);

        stubNotifications([], nextCursor: 'cursor_def');

        await repository.getNotifications();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: 'cursor_abc',
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      test(
        'passes the same first-page URI to signing and request execution',
        () async {
          var signedUrl = '';
          Uri? requestedUri;
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([]);
          stubProfiles({});

          await repository.getNotifications();

          final captured = verify(
            () => funnelcakeApiClient.getNotifications(
              pubkey: userPubkey,
              cursor: any(named: 'cursor'),
              requestUri: captureAny(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: captureAny(named: 'limit'),
            ),
          ).captured;
          requestedUri = captured.whereType<Uri>().single;
          final requestedLimit = captured.whereType<int>().single;

          expect(requestedUri.toString(), equals(signedUrl));
          expect(requestedLimit, equals(20));
        },
      );

      test(
        'passes the same paginated URI to signing and request execution',
        () async {
          var signedUrl = '';
          Uri? requestedUri;
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              signedUrl = url;
              return {'Authorization': 'Nostr test-token'};
            },
          );
          stubNotifications([], nextCursor: 'cursor_abc', hasMore: true);
          stubProfiles({});

          await repository.getNotifications();
          stubNotifications([], nextCursor: 'cursor_def');

          await repository.getNotifications();

          final captured = verify(
            () => funnelcakeApiClient.getNotifications(
              pubkey: userPubkey,
              cursor: 'cursor_abc',
              requestUri: captureAny(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: captureAny(named: 'limit'),
            ),
          ).captured;
          requestedUri = captured.whereType<Uri>().single;
          final requestedLimit = captured.whereType<int>().single;

          expect(requestedUri.toString(), equals(signedUrl));
          expect(requestedLimit, equals(20));
        },
      );
    });

    group('video-anchored grouping', () {
      test('5 likes on same video become 1 $VideoNotification '
          'with totalCount 5 and 3 actors', () async {
        stubNotifications([
          for (var i = 0; i < 5; i++)
            makeNotification(
              id: 'l$i',
              sourcePubkey: 'pub_$i',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 1, 5 - i),
            ),
        ]);
        stubProfiles({
          for (var i = 0; i < 5; i++)
            'pub_$i': makeProfile('pub_$i', displayName: 'Actor$i'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
        expect(item.totalCount, equals(5));
        // Cap is 3 actors for the stack.
        expect(item.actors, hasLength(3));
        // Newest first — pub_0 had the latest createdAt.
        expect(item.actors.first.displayName, equals('Actor0'));
        expect(item.videoEventId, equals('video_x'));
      });

      test('grouped video notifications lead with a named actor', () async {
        const hashPubkey =
            '2949ede154d1f121402761cbd73f2b8c490b5041cdd85c9908c5322f1a2fe3f6';
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: hashPubkey,
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 5),
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_named',
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 4),
          ),
          makeNotification(
            id: 'l3',
            sourcePubkey: 'pub_missing',
            referencedEventId: 'video_x',
            createdAt: DateTime(2025, 1, 3),
          ),
        ]);
        stubProfiles({
          hashPubkey: makeProfile(hashPubkey, displayName: hashPubkey),
          'pub_named': makeProfile(
            'pub_named',
            displayName: 'Sally Strawberry',
          ),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.totalCount, equals(3));
        expect(item.actors.first.pubkey, equals('pub_named'));
        expect(item.actors.first.displayName, equals('Sally Strawberry'));
      });

      test('grouped video notifications build the addressable id from the '
          'authoritative VideoStats d-tag when the recipient owns the '
          'referenced video (#4730)', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'payload-dtag',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
            referencedDTag: 'payload-dtag',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });
        // Authoritative ownership: video stats resolve and the owner is the
        // recipient (makeVideoStats defaults pubkey == userPubkey, d-tag
        // 'd_video_x'). The payload referencedDTag intentionally DIFFERS so the
        // assertion proves the route uses the authoritative VideoStats d-tag,
        // not the payload — a mismatched referenced_video block can't poison
        // the route.
        stubVideoStats('video_x', makeVideoStats(id: 'video_x'));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:d_video_x',
          ),
        );
      });

      test('grouped video notifications fall back to the payload d-tag when '
          'the authoritative VideoStats omits one (#4730)', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
        // Owner confirmed, but VideoStats carries no d-tag → use the payload
        // d-tag rather than drop the stable route.
        stubVideoStats('video_x', makeVideoStats(id: 'video_x', dTag: ''));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:vine-id',
          ),
        );
      });

      test('grouped video notifications synthesize the addressable id from the '
          'payload d-tag when the referenced video metadata is missing '
          '(#4730 broken-link fix)', () async {
        // No video stats stubbed → ownership cannot be confirmed (e.g. a
        // stale/edited event id whose old metadata no longer resolves). The
        // notification is structurally about the recipient's own video, so we
        // synthesize the recipient-scoped stable route from the server-provided
        // d-tag rather than dropping to the (often stale) raw event id. The
        // pubkey is pinned to the recipient, so the route can never address
        // another creator's video.
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
            referencedDTag: 'vine-id',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:vine-id',
          ),
        );
        // The canonical event id is still carried for the resolver fallback.
        expect(item.videoEventId, equals('video_x'));
      });

      test('grouped video notifications leave addressable id null on a '
          'metadata miss when no payload d-tag is available', () async {
        // Metadata miss AND no usable d-tag → nothing to synthesize from, so
        // the route stays null and navigation falls back to the raw event id.
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: '',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.videoAddressableId, isNull);
        expect(item.videoEventId, equals('video_x'));
      });

      test('comment with empty referencedEventId fetches root metadata and '
          'keeps the root video event id (#6369)', () async {
        // NIP-22 comment whose referenced_event_id is empty carries the video
        // via rootEventId. Fetching metadata for the same anchor used by
        // grouping lets ownership and the stable d-tag come from the root.
        stubNotifications([
          makeNotification(
            id: 'c1',
            sourcePubkey: 'pub_a',
            sourceKind: 1111,
            notificationType: 'comment',
            referencedEventId: '',
            rootEventId: 'video_root',
            referencedDTag: 'vine-id',
            content: 'nice one',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
        stubVideoStats('video_root', makeVideoStats(id: 'video_root'));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:d_video_root',
          ),
        );
        expect(item.videoEventId, equals('video_root'));
        verify(() => funnelcakeApiClient.getVideoStats('video_root')).called(1);
      });

      test("comment on another creator's root video leaves the addressable "
          'id null when metadata misses (#6369)', () async {
        // Transient metadata miss (default getVideoStats stub throws) plus a
        // payload root author naming another creator: synthesizing
        // `userPubkey:<d-tag>` would route to a video that does not exist.
        stubNotifications([
          makeNotification(
            id: 'c-foreign-root',
            sourcePubkey: 'pub_a',
            sourceKind: 1111,
            notificationType: 'comment',
            referencedEventId: '',
            rootEventId: 'foreign_root',
            rootEventPubkey: 'other_creator',
            referencedDTag: 'foreign-vine',
            content: 'nice one',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
        expect(item.videoAddressableId, isNull);
        expect(item.videoEventId, equals('foreign_root'));
      });

      test(
        'comment group stays guarded when the newest member omits '
        'root_event_pubkey but an older member carries a foreign one (#6369)',
        () async {
          // Notifications sharing an anchor can disagree: a transient
          // Funnelcake gap leaves the newest member's root_event_pubkey empty
          // while an older member carries it. Sampling only the newest member
          // would miss the foreign root author and mint the #6369 route.
          stubNotifications([
            makeNotification(
              id: 'c-newest-gap',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'foreign_root',
              rootEventPubkey: '',
              referencedDTag: 'foreign-vine',
              content: 'newest',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'c-older-evidence',
              sourcePubkey: 'pub_b',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'foreign_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'foreign-vine',
              content: 'older',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(item.videoAddressableId, isNull);
          expect(item.videoEventId, equals('foreign_root'));
        },
      );

      test(
        'comment group stays guarded when the newest member names the user '
        'but an older member names another creator (#6369)',
        () async {
          // Contradictory payloads on a metadata miss: any root-anchored
          // member carrying a foreign root author suppresses the route —
          // minting `userPubkey:<d-tag>` on contradictory ownership evidence
          // is the #6369 failure.
          stubNotifications([
            makeNotification(
              id: 'c-newest-own',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'disputed_root',
              rootEventPubkey: userPubkey,
              referencedDTag: 'disputed-vine',
              content: 'newest',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'c-older-foreign',
              sourcePubkey: 'pub_b',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'disputed_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'disputed-vine',
              content: 'older',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.videoAddressableId, isNull);
          expect(item.videoEventId, equals('disputed_root'));
        },
      );

      test(
        'comment group without root-author evidence still mints the '
        'recipient-scoped route (#6369 guard does not over-fire)',
        () async {
          // No member carries a root author, so there is no foreign evidence
          // to act on — the #4730 stable route must survive.
          stubNotifications([
            makeNotification(
              id: 'c-newest-no-evidence',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'video_root',
              referencedDTag: 'vine-id',
              content: 'newest',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'c-older-no-evidence',
              sourcePubkey: 'pub_b',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: '',
              rootEventId: 'video_root',
              referencedDTag: 'vine-id',
              content: 'older',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(
            item.videoAddressableId,
            equals(
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:vine-id',
            ),
          );
        },
      );

      test(
        "comment on the user's own video reply keeps the recipient-scoped "
        'route when the thread root belongs to another creator',
        () async {
          // The payload root author describes the thread root, not the
          // anchored reply video — the #6369 guard must not fire here, or
          // every comment on a video reply loses its stable route (#4730).
          stubNotifications([
            makeNotification(
              id: 'c-own-reply',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              referencedEventId: 'reply_video_event',
              rootEventId: 'foreign_thread_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'reply-video-dtag',
              content: 'great reply',
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(
            item.videoAddressableId,
            equals(
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:reply-video-dtag',
            ),
          );
        },
      );

      test('resolved metadata wins over a contradictory payload root author '
          '(#6805)', () async {
        // Metadata resolves the anchored root video as the user's own; a
        // stale payload `root_event_pubkey` must not override it.
        stubNotifications([
          makeNotification(
            id: 'c-contradictory',
            sourcePubkey: 'pub_a',
            sourceKind: 1111,
            notificationType: 'comment',
            referencedEventId: '',
            rootEventId: 'video_root',
            rootEventPubkey: 'other_creator',
            referencedDTag: 'vine-id',
            content: 'nice one',
          ),
        ]);
        stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
        stubVideoStats('video_root', makeVideoStats(id: 'video_root'));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:d_video_root',
          ),
        );
      });

      test(
        'comment on a video reply anchors to the referenced video, not root',
        () async {
          stubNotifications([
            makeNotification(
              id: 'c-reply-video',
              sourcePubkey: 'pub_a',
              sourceKind: 1111,
              notificationType: 'comment',
              sourceEventId: 'comment_event_id',
              referencedEventId: 'reply_video_event',
              rootEventId: 'thread_root_event',
              targetCommentId: 'reply_video_event',
              referencedDTag: 'reply-video-dtag',
              content: 'comment on a video reply',
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(item.videoEventId, equals('reply_video_event'));
          expect(
            item.videoAddressableId,
            equals(
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:reply-video-dtag',
            ),
          );
        },
      );

      test('grouped video notifications leave addressable id null when neither '
          'VideoStats nor the payload carries a usable d-tag', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
            referencedDTag: '',
          ),
          makeNotification(
            id: 'l2',
            sourcePubkey: 'pub_b',
            referencedEventId: 'video_x',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });
        // Owner confirmed, but no d-tag from either source → cannot synthesize.
        // (Without this stub the row would be null for the unrelated
        // ownership-unknown reason, masking the d-tag branch under test.)
        stubVideoStats('video_x', makeVideoStats(id: 'video_x', dTag: ''));

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as VideoNotification;
        expect(item.videoAddressableId, isNull);
      });

      test(
        '5 likes on 5 different videos produce 5 ${VideoNotification}s',
        () async {
          stubNotifications([
            for (var i = 0; i < 5; i++)
              makeNotification(
                id: 'l$i',
                sourcePubkey: 'pub_$i',
                referencedEventId: 'video_$i',
                createdAt: DateTime(2025, 1, 5 - i),
              ),
          ]);
          stubProfiles({
            for (var i = 0; i < 5; i++)
              'pub_$i': makeProfile('pub_$i', displayName: 'Actor$i'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(5));
          for (final item in page.items) {
            expect(item, isA<VideoNotification>());
            expect((item as VideoNotification).totalCount, equals(1));
          }
        },
      );

      test('likes + comments on same video become 2 ${VideoNotification}s '
          'differing by kind', () async {
        stubNotifications([
          makeNotification(
            id: 'l1',
            sourcePubkey: 'pub_a',
            referencedEventId: 'video_x',
          ),
          makeNotification(
            id: 'c1',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_x',
            content: 'Cool',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        final kinds = page.items
            .whereType<VideoNotification>()
            .map((v) => v.type)
            .toSet();
        expect(
          kinds,
          equals({NotificationKind.like, NotificationKind.comment}),
        );
      });

      test(
        'a-tag-only reaction maps to an actor like instead of being dropped',
        () async {
          const rootAddressableId =
              '34236:user1234567890abcdef:addressable-video';
          stubNotifications([
            makeNotification(
              sourcePubkey: 'pub_a',
              sourceEventId: 'reaction_event',
              referencedEventId: null,
              rootAddressableId: rootAddressableId,
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.targetEventId, equals('reaction_event'));
          expect(item.videoAddressableId, equals(rootAddressableId));

          final rows =
              verify(
                    () => notificationsDao.replaceAll(
                      captureAny(),
                      ownerPubkey: any(named: 'ownerPubkey'),
                    ),
                  ).captured.single
                  as List<NotificationCacheRow>;
          final row = rows.singleWhere((r) => r.type != 'seen_marker');
          expect(row.type, equals('actorLike'));
          expect(row.targetEventId, equals('reaction_event'));
          expect(row.videoAddressableId, equals(rootAddressableId));
        },
      );

      test(
        'anchorless actor like does not trust a foreign root coordinate',
        () async {
          const foreignRootAddressableId =
              '34236:other_owner:addressable-video';
          stubNotifications([
            makeNotification(
              sourcePubkey: 'pub_a',
              sourceEventId: 'reaction_event',
              referencedEventId: null,
              rootAddressableId: foreignRootAddressableId,
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.targetEventId, equals('reaction_event'));
          expect(item.videoAddressableId, isNull);

          final rows =
              verify(
                    () => notificationsDao.replaceAll(
                      captureAny(),
                      ownerPubkey: any(named: 'ownerPubkey'),
                    ),
                  ).captured.single
                  as List<NotificationCacheRow>;
          final row = rows.singleWhere((r) => r.type != 'seen_marker');
          expect(row.type, equals('actorLike'));
          expect(row.targetEventId, equals('reaction_event'));
          expect(row.videoAddressableId, isNull);
        },
      );

      test(
        'likeComment can keep a foreign root coordinate for comment routing',
        () async {
          const foreignRootAddressableId =
              '34236:other_owner:addressable-video';
          stubNotifications([
            makeNotification(
              sourcePubkey: 'pub_a',
              targetCommentId: 'comment_event',
              rootAddressableId: foreignRootAddressableId,
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
          expect(item.targetEventId, equals('comment_event'));
          expect(item.videoAddressableId, equals(foreignRootAddressableId));
        },
      );

      test(
        'getVideoStats throws → row still rendered with null thumbnail',
        () async {
          stubNotifications([
            makeNotification(
              sourcePubkey: 'pub_a',
              referencedEventId: 'video_x',
            ),
          ]);
          stubProfiles({'pub_a': makeProfile('pub_a', displayName: 'Alice')});
          when(
            () => funnelcakeApiClient.getVideoStats('video_x'),
          ).thenThrow(const FunnelcakeException('boom'));

          final page = await repository.getNotifications();

          expect(page.items, hasLength(1));
          final item = page.items.single as VideoNotification;
          expect(item.videoThumbnailUrl, isNull);
          expect(item.videoTitle, isNull);
        },
      );
    });

    group('follow consolidation', () {
      test('2 follows from same pubkey become 1 $ActorNotification '
          'with most-recent timestamp', () async {
        final earlier = DateTime(2025);
        final later = DateTime(2025, 1, 5);
        stubNotifications([
          makeNotification(
            id: 'f1',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: later,
          ),
          makeNotification(
            id: 'f2',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: earlier,
          ),
        ]);
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
        // The consolidated row carries the most recent follow timestamp so a
        // fresh follow surfaces at the top of the Follows tab rather than
        // being buried (and paginated off the first page) with a stale
        // timestamp.
        expect(item.timestamp, equals(later));
      });

      test('follows from different pubkeys are not consolidated', () async {
        stubNotifications([
          makeNotification(
            id: 'f1',
            sourcePubkey: 'pub_a',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
          makeNotification(
            id: 'f2',
            sourcePubkey: 'pub_b',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
      });

      test('a re-published follow sorts above older notifications by its '
          'latest timestamp', () async {
        // A replaceable kind-3 contact list arrives twice for the same
        // follower: once with a stale timestamp and once fresh. The
        // consolidated row must inherit the fresh timestamp so it sorts
        // above an older like — otherwise the follow sinks below the fold
        // and the Follows tab reads "no activity" (regression for the
        // reported follows-tab bug).
        final stale = DateTime(2025);
        final older = DateTime(2025, 1, 3);
        final fresh = DateTime(2025, 1, 10);
        stubNotifications([
          makeNotification(
            id: 'follow_stale',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: stale,
          ),
          makeNotification(
            id: 'old_like',
            sourcePubkey: 'liker_pub',
            referencedEventId: 'video_a',
            createdAt: older,
          ),
          makeNotification(
            id: 'follow_fresh',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            createdAt: fresh,
          ),
        ]);
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
          'liker_pub': makeProfile('liker_pub', displayName: 'Liker'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        final follow = page.items.first as ActorNotification;
        expect(follow.type, equals(NotificationKind.follow));
        expect(follow.actor.pubkey, equals('follower_pub'));
        expect(follow.timestamp, equals(fresh));
      });

      test('same follower is consolidated across appended pages', () async {
        final stale = DateTime(2025);
        final fresh = DateTime(2025, 1, 10);
        var call = 0;
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: any(named: 'types'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call++;
          return call == 1
              ? NotificationResponse(
                  notifications: [
                    makeNotification(
                      id: 'follow_stale',
                      sourceEventId: 'follow_evt_stale',
                      sourcePubkey: 'follower_pub',
                      notificationType: 'follow',
                      sourceKind: 3,
                      referencedEventId: null,
                      createdAt: stale,
                      read: true,
                    ),
                  ],
                  unreadCount: 0,
                  hasMore: true,
                  nextCursor: 'cursor_1',
                )
              : NotificationResponse(
                  notifications: [
                    makeNotification(
                      id: 'follow_fresh',
                      sourceEventId: 'follow_evt_fresh',
                      sourcePubkey: 'follower_pub',
                      notificationType: 'follow',
                      sourceKind: 3,
                      referencedEventId: null,
                      createdAt: fresh,
                    ),
                  ],
                  unreadCount: 1,
                  hasMore: false,
                );
        });
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
        });

        await repository.getNotifications(filter: NotificationKind.follow);
        await repository.loadNextPageFor(NotificationKind.follow);

        final page = await repository
            .watchSnapshot(filter: NotificationKind.follow)
            .first;
        expect(page.items, hasLength(1));
        final follow = page.items.single as ActorNotification;
        expect(follow.timestamp, equals(fresh));
        expect(follow.isRead, isFalse);
        expect(
          follow.notificationIds,
          containsAll(['follow_stale', 'follow_fresh']),
        );
      });
    });

    group('comments stay individual when on different videos', () {
      test(
        'comments on different videos are 2 separate ${VideoNotification}s',
        () async {
          stubNotifications([
            makeNotification(
              id: 'c1',
              sourcePubkey: 'pub_a',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_a',
              content: 'Great video!',
            ),
            makeNotification(
              id: 'c2',
              sourcePubkey: 'pub_b',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_b',
              content: 'Amazing!',
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          expect(page.items, hasLength(2));
          expect(page.items[0], isA<VideoNotification>());
          expect(page.items[1], isA<VideoNotification>());
        },
      );
    });

    group('type mapping', () {
      test('reaction on a video maps to like', () async {
        stubNotifications([makeNotification()]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test(
        'list_add maps to video-anchored listAdd with list context',
        () async {
          const listCoordinate = '30005:pubkey_alice:literature';
          stubNotifications([
            makeNotification(
              id: 'list_add_1',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: 'video_1',
              referencedDTag: 'vine-1',
              listTitle: 'Literature',
              listCoordinate: listCoordinate,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.listAdd));
          expect(item.videoEventId, equals('video_1'));
          expect(item.videoAddressableId, equals('34236:$userPubkey:vine-1'));
          expect(item.listTitle, equals('Literature'));
          expect(item.listCoordinate, equals(listCoordinate));
          expect(item.actors.single.displayName, equals('Alice'));
        },
      );

      test(
        'list_add with addressable target anchors on rootAddressableId',
        () async {
          const videoCoordinate = '34236:$userPubkey:addressable-vine';
          const listCoordinate = '30005:pubkey_alice:literature';
          stubNotifications([
            makeNotification(
              id: 'list_add_addressable',
              sourceEventId: 'list_evt_1',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventKind: 34236,
              rootEventPubkey: userPubkey,
              rootDTag: 'addressable-vine',
              rootAddressableId: videoCoordinate,
              listTitle: 'Literature',
              listCoordinate: listCoordinate,
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.listAdd));
          expect(item.videoEventId, equals(videoCoordinate));
          expect(item.videoAddressableId, equals(videoCoordinate));
          expect(item.totalCount, equals(1));
          expect(item.addedVideoCount, equals(1));
          expect(item.listTitle, equals('Literature'));
          expect(item.listCoordinate, equals(listCoordinate));
          verifyNever(() => funnelcakeApiClient.getVideoStats(videoCoordinate));
        },
      );

      test(
        "list_add of another creator's root video leaves the addressable id "
        'null when metadata misses (#6369)',
        () async {
          // Transient metadata miss plus a payload root author naming another
          // creator: a recipient-scoped coordinate would route to a video
          // that does not exist.
          stubNotifications([
            makeNotification(
              id: 'list_add_foreign_root',
              sourceEventId: 'list_evt_foreign_root',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventId: 'foreign_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'foreign-vine',
              listTitle: 'Literature',
              listCoordinate: '30005:pubkey_alice:literature',
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.listAdd));
          expect(item.videoEventId, equals('foreign_root'));
          expect(item.videoAddressableId, isNull);
        },
      );

      test(
        'list_add group stays guarded when the newest member omits '
        'root_event_pubkey but an older member carries a foreign one (#6369)',
        () async {
          // Same transient Funnelcake gap the comment path guards against:
          // list_add notifications sharing an anchor can disagree, and the
          // newest member is the one the row samples. Deriving the root author
          // across the group is what keeps the guard order-independent.
          stubNotifications([
            makeNotification(
              id: 'list_add_newest_gap',
              sourcePubkey: 'pub_a',
              sourceEventId: 'list_evt_newest_gap',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventId: 'foreign_root',
              rootEventPubkey: '',
              referencedDTag: 'foreign-vine',
              listTitle: 'Literature',
              listCoordinate: '30005:pubkey_alice:literature',
              createdAt: DateTime(2025, 1, 2),
            ),
            makeNotification(
              id: 'list_add_older_evidence',
              sourcePubkey: 'pub_b',
              sourceEventId: 'list_evt_older_evidence',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventId: 'foreign_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'foreign-vine',
              listTitle: 'Literature',
              listCoordinate: '30005:pubkey_alice:literature',
              createdAt: DateTime(2025),
            ),
          ]);
          stubProfiles({
            'pub_a': makeProfile('pub_a', displayName: 'Alice'),
            'pub_b': makeProfile('pub_b', displayName: 'Bob'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.listAdd));
          expect(item.videoEventId, equals('foreign_root'));
          expect(item.videoAddressableId, isNull);
        },
      );

      test(
        "list_add of the user's own video reply keeps the recipient-scoped "
        'route when the thread root belongs to another creator',
        () async {
          // The payload root author describes the thread root, not the added
          // reply video — the #6369 guard must not fire here.
          stubNotifications([
            makeNotification(
              id: 'list_add_own_reply',
              sourceEventId: 'list_evt_own_reply',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: 'reply_video_event',
              rootEventId: 'foreign_thread_root',
              rootEventPubkey: 'other_creator',
              referencedDTag: 'reply-video-dtag',
              listTitle: 'Literature',
              listCoordinate: '30005:pubkey_alice:literature',
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.listAdd));
          expect(
            item.videoAddressableId,
            equals(
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:reply-video-dtag',
            ),
          );
        },
      );

      test(
        'list_add with foreign addressable target is not rendered as your vine',
        () async {
          const foreignCoordinate = '34236:pubkey_foreign:foreign-vine';
          stubNotifications([
            makeNotification(
              id: 'list_add_foreign_addressable',
              sourceEventId: 'list_evt_foreign',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventKind: 34236,
              rootEventPubkey: 'pubkey_foreign',
              rootDTag: 'foreign-vine',
              rootAddressableId: foreignCoordinate,
              listTitle: 'Literature',
              listCoordinate: '30005:pubkey_alice:literature',
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          expect(page.items, isEmpty);
          verifyNever(
            () => funnelcakeApiClient.getVideoStats(foreignCoordinate),
          );
        },
      );

      test('list_add groups multiple videos by list coordinate', () async {
        const listCoordinate = '30005:pubkey_alice:literature';
        stubNotifications([
          makeNotification(
            id: 'list_add_1',
            sourceEventId: 'list_evt_1',
            sourceKind: 30005,
            notificationType: 'list_add',
            referencedEventId: 'video_1',
            listTitle: 'Literature',
            listCoordinate: listCoordinate,
            createdAt: DateTime(2026, 1, 2),
          ),
          makeNotification(
            id: 'list_add_2',
            sourceEventId: 'list_evt_2',
            sourceKind: 30005,
            notificationType: 'list_add',
            referencedEventId: 'video_2',
            listTitle: 'Literature',
            listCoordinate: listCoordinate,
            createdAt: DateTime(2026, 1, 1, 1),
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.listAdd));
        expect(item.totalCount, equals(1));
        expect(item.addedVideoCount, equals(2));
        expect(item.actors, hasLength(1));
        expect(item.videoEventId, equals('video_1'));
        expect(item.sourceEventIds, equals(['list_evt_1', 'list_evt_2']));
        expect(item.notificationIds, equals(['list_add_1', 'list_add_2']));
      });

      test(
        'list_add mixed anchor group uses newest notification '
        'for event and route',
        () async {
          const listCoordinate = '30005:pubkey_alice:literature';
          const newestCoordinate = '34236:$userPubkey:newest-vine';
          stubNotifications([
            makeNotification(
              id: 'list_add_old_event',
              sourceEventId: 'list_evt_old',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: 'old_video_event',
              referencedDTag: 'old-vine',
              listTitle: 'Literature',
              listCoordinate: listCoordinate,
              createdAt: DateTime(2026),
            ),
            makeNotification(
              id: 'list_add_new_addressable',
              sourceEventId: 'list_evt_new',
              sourceKind: 30005,
              notificationType: 'list_add',
              referencedEventId: null,
              rootEventKind: 34236,
              rootEventPubkey: userPubkey,
              rootDTag: 'newest-vine',
              rootAddressableId: newestCoordinate,
              listTitle: 'Literature',
              listCoordinate: listCoordinate,
              isReferencedVideo: false,
              createdAt: DateTime(2026, 1, 2),
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.videoEventId, equals(newestCoordinate));
          expect(item.videoAddressableId, equals(newestCoordinate));
          expect(item.addedVideoCount, equals(2));
          verifyNever(
            () => funnelcakeApiClient.getVideoStats(newestCoordinate),
          );
        },
      );

      test('block filter preserves list_add added video count', () async {
        repository = buildRepository(
          blockFilter: (pubkey) => pubkey == 'pubkey_bob',
        );
        const listCoordinate = '30005:pubkey_alice:literature';
        stubNotifications([
          makeNotification(
            id: 'list_add_alice',
            sourceEventId: 'list_evt_1',
            sourceKind: 30005,
            notificationType: 'list_add',
            referencedEventId: 'video_1',
            listTitle: 'Literature',
            listCoordinate: listCoordinate,
            createdAt: DateTime(2026, 1, 2),
          ),
          makeNotification(
            id: 'list_add_bob',
            sourcePubkey: 'pubkey_bob',
            sourceEventId: 'list_evt_2',
            sourceKind: 30005,
            notificationType: 'list_add',
            referencedEventId: 'video_2',
            listTitle: 'Literature',
            listCoordinate: listCoordinate,
            createdAt: DateTime(2026),
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.actors.single.pubkey, equals('pubkey_alice'));
        expect(item.totalCount, equals(1));
        expect(item.addedVideoCount, equals(2));
      });

      test('reaction with a target comment maps to likeComment even when '
          'referenced_video is populated from the root video', () async {
        // Funnelcake fills referenced_video from the notification's root
        // video, so isReferencedVideo is true for a like on a comment exactly
        // as for a like on the video itself. targetCommentId is the reliable
        // comment signal. Without an owner mismatch the #4813 path never fires
        // (this is a like on your own comment on your own video), so before
        // this fix the like was surfaced as "liked your video".
        stubNotifications([
          makeNotification(targetCommentId: 'comment_event_xyz'),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
        expect(item.targetEventId, equals('comment_event_xyz'));
      });

      test('reaction on a non-owned video is reclassified as likeComment '
          'instead of liked your video (#4813)', () async {
        // No targetCommentId, so this genuinely exercises the owner-mismatch
        // reclassification: _mapNotificationKind returns `like`, which the
        // #4813 path rewrites to likeComment. A comment-like that *does* carry
        // a targetCommentId is covered by the direct-classification test above.
        stubNotifications([
          makeNotification(referencedEventId: 'foreign_video'),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
        expect(item.targetEventId, equals('foreign_video'));
      });

      test('comment anchored on a non-owned root video is reclassified as '
          'reply instead of commented on your video (#6369)', () async {
        stubNotifications([
          makeNotification(
            id: '',
            sourceEventId: 'comment_evt_id',
            sourceKind: 1111,
            notificationType: 'mention',
            referencedEventId: '',
            rootEventId: 'foreign_root_video',
            targetCommentId: 'target_comment_id',
            referencedDTag: 'foreign-d-tag',
            content: 'Reply from another creator',
            isReferencedVideo: false,
          ),
        ]);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubVideoStats(
          'foreign_root_video',
          makeVideoStats(
            id: 'foreign_root_video',
            pubkey: 'other_owner_pubkey',
          ),
        );

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.id, equals('comment_evt_id'));
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('target_comment_id'));
        expect(item.videoAddressableId, isNull);
        verify(
          () => funnelcakeApiClient.getVideoStats('foreign_root_video'),
        ).called(1);
      });

      test(
        "reaction on the user's comment (non-owned root_event_pubkey) is "
        'reclassified as likeComment after a confirmed metadata 404 (#5634)',
        () async {
          // Residual edge of #5634/#5949: Funnelcake left target_comment_id
          // empty but populated the root video (referenced_video +
          // root_event_pubkey). The anchor id is the comment, so videosById
          // gets a confirmed not-found and cannot resolve ownership; the
          // fallback owner is the payload's root_event_pubkey.
          stubNotifications([
            makeNotification(
              referencedEventId: 'my_comment',
              rootEventPubkey: 'other_owner_pubkey',
            ),
          ]);
          stubProfiles({});
          stubVideoStatsNotFound('my_comment');

          final page = await repository.getNotifications();

          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
        },
      );

      test("reaction on the user's own video (root_event_pubkey == user) "
          'stays like', () async {
        stubNotifications([
          makeNotification(
            referencedEventId: 'own_video',
            rootEventPubkey: userPubkey,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('repost on the user-owned referenced video survives when metadata '
          'throws and root_event_pubkey is another creator', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'repost',
            sourceKind: 6,
            referencedEventId: 'my_video_reply',
            rootEventPubkey: 'other_owner_pubkey',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.repost));
        expect(item.videoEventId, equals('my_video_reply'));
      });

      test(
        'repost does not get dropped from the root_event_pubkey fallback alone',
        () async {
          stubNotifications([
            makeNotification(
              notificationType: 'repost',
              sourceKind: 6,
              referencedEventId: 'unknown_anchor',
              rootEventPubkey: 'other_owner_pubkey',
            ),
          ]);
          stubProfiles({});
          stubVideoStatsNotFound('unknown_anchor');

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.repost));
          expect(item.videoEventId, equals('unknown_anchor'));
        },
      );

      test(
        'like on the user-owned referenced video stays like even when '
        'root_event_pubkey is another creator (video-reply; metadata wins)',
        () async {
          // Reliability order: the anchor event's own metadata is authoritative
          // over the payload's root author. A like on the user's own
          // video-reply resolves to the user in videosById, while the thread's
          // root video belongs to someone else. It must stay "liked your video"
          // — trusting root_event_pubkey here would mislabel it as likeComment.
          stubNotifications([
            makeNotification(
              referencedEventId: 'my_video_reply',
              rootEventPubkey: 'other_owner_pubkey',
            ),
          ]);
          stubProfiles({});
          stubVideoStats(
            'my_video_reply',
            makeVideoStats(id: 'my_video_reply'),
          );

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.like));
        },
      );

      test(
        'repost on the user-owned referenced video stays repost even when '
        'root_event_pubkey is another creator (not silently dropped)',
        () async {
          // The repost case is the sharper failure: a misattributed repost is
          // dropped by _reclassifiedMisattributedKind. If the payload root
          // author overrode the user-owned anchor metadata, a genuine
          // "reposted your video" on the user's own video-reply would vanish.
          stubNotifications([
            makeNotification(
              notificationType: 'repost',
              sourceKind: 6,
              referencedEventId: 'my_video_reply',
              rootEventPubkey: 'other_owner_pubkey',
            ),
          ]);
          stubProfiles({});
          stubVideoStats(
            'my_video_reply',
            makeVideoStats(id: 'my_video_reply'),
          );

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.repost));
        },
      );

      test('comment on a non-owned video is reclassified as reply '
          'instead of commented on your video (#4813)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1,
            referencedEventId: 'foreign_video',
            rootEventId: 'foreign_video',
            targetCommentId: 'comment_event_xyz',
          ),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, hasLength(1));
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('comment_event_xyz'));
      });

      test('repost on a non-owned video is dropped entirely', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'repost',
            sourceKind: 6,
            referencedEventId: 'foreign_video',
          ),
        ]);
        stubProfiles({});
        stubVideoStats(
          'foreign_video',
          makeVideoStats(id: 'foreign_video', pubkey: 'other_owner_pubkey'),
        );

        final page = await repository.getNotifications();

        expect(page.items, isEmpty);
      });

      test(
        'reaction without a target comment stays like when the referenced '
        'video did not resolve',
        () async {
          // An unresolved root video leaves referenced_video absent, which is
          // a Funnelcake join miss (unindexed / deleted video), not evidence
          // of a comment target. Reading it as one relabelled ordinary video
          // likes "liked your comment" — with no thumbnail and no quote, so
          // the row named neither a comment nor a video.
          stubNotifications([
            makeNotification(
              isReferencedVideo: false,
              referencedEventId: 'my_video',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.videoEventId, equals('my_video'));
        },
      );

      test('likeComment quotes the liked comment body', () async {
        // The source event is a kind 7 reaction, so `content` is the emoji.
        // Funnelcake resolves the liked comment's text into comment_content.
        stubNotifications([
          makeNotification(
            targetCommentId: 'comment_event_xyz',
            content: '+',
            commentContent: 'this vine still holds up',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.likeComment));
        expect(item.commentText, equals('this vine still holds up'));
      });

      test('likeComment truncates a long liked comment body', () async {
        final body = 'a' * 200;
        stubNotifications([
          makeNotification(
            targetCommentId: 'comment_event_xyz',
            content: '+',
            commentContent: body,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.commentText, equals('${'a' * 120}...'));
      });

      test(
        'likeComment leaves commentText null when the server omits the body',
        () async {
          stubNotifications([
            makeNotification(
              targetCommentId: 'comment_event_xyz',
              content: '+',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
          // Never the reaction emoji — a row quoting "+" is worse than one
          // quoting nothing.
          expect(item.commentText, isNull);
        },
      );

      test(
        'likeComment carries root addressable id for direct video routing',
        () async {
          const rootAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:other_owner:root-d-tag';
          stubNotifications([
            makeNotification(
              targetCommentId: 'comment_event_xyz',
              rootAddressableId: rootAddressableId,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
          expect(item.videoAddressableId, equals(rootAddressableId));
        },
      );

      test(
        'likeComment leaves videoAddressableId null even when referencedDTag '
        'is set without an authoritative owner pubkey',
        () async {
          stubNotifications([
            makeNotification(
              targetCommentId: 'comment_event_xyz',
              referencedDTag: 'vine-abc',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.likeComment));
          expect(item.videoAddressableId, isNull);
        },
      );

      test(
        'likeComment videoAddressableId is null when referencedDTag is absent',
        () async {
          stubNotifications([
            makeNotification(
              targetCommentId: 'comment_event_xyz',
              // referencedDTag intentionally omitted
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.videoAddressableId, isNull);
        },
      );

      test('reply on a video maps to comment ($VideoNotification)', () async {
        stubNotifications([
          makeNotification(notificationType: 'reply', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        // A reply directly on a video is indistinguishable from a comment
        // for the user, so it lands in the comment grouping path.
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('reply to user comment with root video metadata maps to reply '
          '($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1111,
            sourceEventId: 'reply_event_id',
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
            rootEventId: 'someone_else_video_id',
            targetCommentId: 'parent_comment_id',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
      });

      test('reply to user comment targets parent comment when '
          'referencedEventId is the root video', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1111,
            sourceEventId: 'reply_event_id',
            referencedEventId: 'someone_else_video_id',
            rootEventId: 'someone_else_video_id',
            targetCommentId: 'parent_comment_id',
            content: 'Reply with video anchor',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
        expect(item.commentText, equals('Reply with video anchor'));
      });

      test('comment-typed nested NIP-22 reply maps to reply '
          '($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1111,
            sourceEventId: 'reply_event_id',
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
            rootEventId: 'someone_else_video_id',
            targetCommentId: 'parent_comment_id',
            content: 'Nested reply to my comment',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
        expect(item.commentText, equals('Nested reply to my comment'));
      });

      test('reply on a non-video target maps to reply ($ActorNotification) '
          'with targetEventId', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'reply',
            sourceKind: 1,
            isReferencedVideo: false,
            referencedEventId: 'parent_comment_id',
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.reply));
        expect(item.targetEventId, equals('parent_comment_id'));
      });

      test(
        'reply falls back to sourceEventId when referencedEventId is null',
        () async {
          stubNotifications([
            makeNotification(
              notificationType: 'reply',
              sourceKind: 1,
              isReferencedVideo: false,
              sourceEventId: 'reply_event_id',
              referencedEventId: null,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.reply));
          // targetEventId must be non-null so _onItemTap can call the resolver
          // instead of falling back to the actor's profile screen.
          expect(item.targetEventId, equals('reply_event_id'));
        },
      );

      test(
        'reply falls back to sourceEventId when referencedEventId is empty',
        () async {
          stubNotifications([
            makeNotification(
              notificationType: 'reply',
              sourceKind: 1,
              isReferencedVideo: false,
              sourceEventId: 'reply_event_id',
              referencedEventId: '',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.reply));
          expect(item.targetEventId, equals('reply_event_id'));
        },
      );

      test('comment maps to comment', () async {
        stubNotifications([
          makeNotification(notificationType: 'comment', sourceKind: 1),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.comment));
      });

      test('repost maps to repost', () async {
        stubNotifications([
          makeNotification(notificationType: 'repost', sourceKind: 6),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.repost));
      });

      test(
        'kind 16 generic repost with no type falls back to repost',
        () async {
          stubNotifications([
            makeNotification(notificationType: '', sourceKind: 16),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.repost));
        },
      );

      test('mention maps to mention ($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourceKind: 1,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.mention));
      });

      test(
        'mention carries sourceEventId as targetEventId for resolver',
        () async {
          // A mention's referencedEventId is null (no video anchor); the
          // client resolver uses sourceEventId — the kind-1 event that
          // mentioned the user — to walk E-tags and find the root video.
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourceKind: 1,
              sourceEventId: 'mention_evt_id',
              referencedEventId: null,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as ActorNotification;
          expect(item.type, equals(NotificationKind.mention));
          expect(item.targetEventId, equals('mention_evt_id'));
        },
      );

      test(
        'kind 34236 video-sourced mention maps to video notification',
        () async {
          const rootAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:video-d-tag';
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourcePubkey: 'source_author',
              sourceKind: NIP71VideoKinds.addressableShortVideo,
              sourceEventId: 'source_video_evt_current',
              referencedEventId: null,
              rootEventId: 'parent_video_evt',
              rootEventKind: NIP71VideoKinds.addressableShortVideo,
              rootDTag: 'video-d-tag',
              rootAddressableId: rootAddressableId,
              referencedVideoTitle: 'Source video',
              referencedVideoThumbnail: 'https://example.com/thumb.jpg',
            ),
          ]);
          stubProfiles({
            'source_author': makeProfile('source_author', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.mention));
          expect(item.videoEventId, equals('source_video_evt_current'));
          expect(item.videoAddressableId, equals(rootAddressableId));
          expect(item.videoTitle, equals('Source video'));
          expect(
            item.videoThumbnailUrl,
            equals('https://example.com/thumb.jpg'),
          );
          expect(item.actors.single.displayName, equals('Alice'));
        },
      );

      test(
        'kind 34236 video reply mention uses source video metadata',
        () async {
          const badRootAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:parent-video-d-tag';
          const expectedAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:source-video-d-tag';
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourcePubkey: 'source_author',
              sourceKind: NIP71VideoKinds.addressableShortVideo,
              sourceEventId: 'source_video_evt',
              referencedEventId: null,
              rootEventId: 'parent_video_evt',
              rootEventKind: NIP71VideoKinds.addressableShortVideo,
              rootDTag: 'parent-video-d-tag',
              rootAddressableId: badRootAddressableId,
              referencedVideoTitle: 'Parent video',
              referencedVideoThumbnail: 'https://example.com/parent.jpg',
            ),
          ]);
          stubVideoStats(
            'source_video_evt',
            makeVideoStats(
              id: 'source_video_evt',
              pubkey: 'source_author',
              dTag: 'source-video-d-tag',
              title: 'Source reply video',
              thumbnail: 'https://example.com/source.jpg',
            ),
          );
          stubProfiles({});

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.videoEventId, equals('source_video_evt'));
          expect(item.videoAddressableId, equals(expectedAddressableId));
          expect(item.videoTitle, equals('Source reply video'));
          expect(
            item.videoThumbnailUrl,
            equals('https://example.com/source.jpg'),
          );
        },
      );

      test('kind 34236 mention edits dedupe by root addressable id', () async {
        const rootAddressableId =
            '${NIP71VideoKinds.addressableShortVideo}:'
            'source_author:video-d-tag';
        stubNotifications([
          makeNotification(
            id: 'new-row',
            notificationType: 'mention',
            sourcePubkey: 'source_author',
            sourceKind: NIP71VideoKinds.addressableShortVideo,
            sourceEventId: 'source_video_evt_new',
            referencedEventId: null,
            rootEventId: 'source_video_evt_new',
            rootAddressableId: rootAddressableId,
            createdAt: DateTime(2025, 1, 2),
          ),
          makeNotification(
            id: 'old-row',
            notificationType: 'mention',
            sourcePubkey: 'source_author',
            sourceKind: NIP71VideoKinds.addressableShortVideo,
            sourceEventId: 'source_video_evt_old',
            referencedEventId: null,
            rootEventId: 'source_video_evt_old',
            rootAddressableId: rootAddressableId,
            createdAt: DateTime(2025),
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.id, equals('new-row'));
        expect(item.type, equals(NotificationKind.mention));
        expect(item.actors.map((a) => a.pubkey), equals(['source_author']));
        expect(item.totalCount, equals(1));
        expect(item.videoEventId, equals('source_video_evt_new'));
        expect(item.videoAddressableId, equals(rootAddressableId));
        expect(item.sourceEventIds, [
          'source_video_evt_new',
          'source_video_evt_old',
        ]);
      });

      test(
        'kind 34236 mention ignores root addressable id from another owner',
        () async {
          const badRootAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              '$userPubkey:video-d-tag';
          const expectedAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:video-d-tag';
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourcePubkey: 'source_author',
              sourceKind: NIP71VideoKinds.addressableShortVideo,
              sourceEventId: 'source_video_evt_old',
              referencedEventId: null,
              rootEventId: 'recipient_video_evt',
              rootEventKind: NIP71VideoKinds.addressableShortVideo,
              rootDTag: 'video-d-tag',
              rootAddressableId: badRootAddressableId,
            ),
          ]);
          stubVideoStats(
            'source_video_evt_old',
            makeVideoStats(
              id: 'source_video_evt_old',
              pubkey: 'source_author',
              dTag: 'video-d-tag',
            ),
          );
          stubProfiles({});

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.videoEventId, equals('source_video_evt_old'));
          expect(item.videoAddressableId, equals(expectedAddressableId));
        },
      );

      test(
        'kind 34236 mention ignores root addressable id with non-video kind',
        () async {
          const badRootAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:video-d-tag';
          const expectedAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:source-video-d-tag';
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourcePubkey: 'source_author',
              sourceKind: NIP71VideoKinds.addressableShortVideo,
              sourceEventId: 'source_video_evt',
              referencedEventId: null,
              rootEventId: 'source_video_evt',
              rootEventKind: 1,
              rootDTag: 'video-d-tag',
              rootAddressableId: badRootAddressableId,
            ),
          ]);
          stubVideoStats(
            'source_video_evt',
            makeVideoStats(
              id: 'source_video_evt',
              pubkey: 'source_author',
              dTag: 'source-video-d-tag',
            ),
          );
          stubProfiles({});

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.videoEventId, equals('source_video_evt'));
          expect(item.videoAddressableId, equals(expectedAddressableId));
        },
      );

      test('kind 34236 mention rejects a foreign root coordinate even when the '
          'source video does not resolve', () async {
        // Funnelcake derives the root from the `a`/`A` tag when a kind 34236
        // ships without a `d` tag, which points at the *original* creator —
        // here the recipient. With no VideoStats the sender-owner check is
        // the only defence, so the row must not route at the recipient.
        const recipientCoordinate =
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:recipient-d-tag';
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourcePubkey: 'source_author',
            sourceKind: NIP71VideoKinds.addressableShortVideo,
            sourceEventId: 'source_video_evt',
            referencedEventId: null,
            rootEventId: 'recipient_video_evt',
            rootEventKind: NIP71VideoKinds.addressableShortVideo,
            rootDTag: 'recipient-d-tag',
            referencedDTag: 'recipient-d-tag',
            rootAddressableId: recipientCoordinate,
          ),
        ]);
        stubVideoStatsNotFound('source_video_evt');
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.videoEventId, equals('source_video_evt'));
        expect(item.videoAddressableId, isNull);
      });

      test('kind 34236 mention drops payload media when the root coordinate is '
          'rejected', () async {
        // `referenced_video` is joined on the root coordinate, so once that
        // coordinate is rejected its title/thumbnail describe the recipient's
        // own video and must not render under "mentioned you".
        const recipientCoordinate =
            '${NIP71VideoKinds.addressableShortVideo}:'
            '$userPubkey:recipient-d-tag';
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourcePubkey: 'source_author',
            sourceKind: NIP71VideoKinds.addressableShortVideo,
            sourceEventId: 'source_video_evt',
            referencedEventId: null,
            rootEventId: 'recipient_video_evt',
            rootEventKind: NIP71VideoKinds.addressableShortVideo,
            rootDTag: 'recipient-d-tag',
            rootAddressableId: recipientCoordinate,
            referencedVideoTitle: 'Recipient own video',
            referencedVideoThumbnail: 'https://example.com/recipient.jpg',
          ),
        ]);
        stubVideoStats(
          'source_video_evt',
          makeVideoStats(
            id: 'source_video_evt',
            pubkey: 'source_author',
            dTag: 'source-video-d-tag',
          ),
        );
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.videoTitle, isNull);
        expect(item.videoThumbnailUrl, isNull);
        expect(
          item.videoAddressableId,
          equals(
            '${NIP71VideoKinds.addressableShortVideo}:'
            'source_author:source-video-d-tag',
          ),
        );
      });

      test('kind 34236 mention keeps payload media when the root coordinate is '
          'trusted', () async {
        const senderCoordinate =
            '${NIP71VideoKinds.addressableShortVideo}:'
            'source_author:source-video-d-tag';
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourcePubkey: 'source_author',
            sourceKind: NIP71VideoKinds.addressableShortVideo,
            sourceEventId: 'source_video_evt',
            referencedEventId: null,
            rootEventId: 'source_video_evt',
            rootEventKind: NIP71VideoKinds.addressableShortVideo,
            rootDTag: 'source-video-d-tag',
            rootAddressableId: senderCoordinate,
            referencedVideoTitle: 'Sender video',
            referencedVideoThumbnail: 'https://example.com/sender.jpg',
          ),
        ]);
        stubVideoStatsNotFound('source_video_evt');
        stubProfiles({});

        final page = await repository.getNotifications();

        final item = page.items.single as VideoNotification;
        expect(item.videoTitle, equals('Sender video'));
        expect(
          item.videoThumbnailUrl,
          equals('https://example.com/sender.jpg'),
        );
        expect(item.videoAddressableId, equals(senderCoordinate));
      });

      test(
        'kind 34236 mention persists under the videoMention cache type',
        () async {
          const senderCoordinate =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:source-video-d-tag';
          stubNotifications([
            makeNotification(
              notificationType: 'mention',
              sourcePubkey: 'source_author',
              sourceKind: NIP71VideoKinds.addressableShortVideo,
              sourceEventId: 'source_video_evt',
              referencedEventId: null,
              rootEventId: 'source_video_evt',
              rootEventKind: NIP71VideoKinds.addressableShortVideo,
              rootDTag: 'source-video-d-tag',
              rootAddressableId: senderCoordinate,
            ),
          ]);
          stubVideoStatsNotFound('source_video_evt');
          stubProfiles({});

          await repository.getNotifications();

          final captured =
              verify(
                    () => notificationsDao.replaceAll(
                      captureAny(),
                      ownerPubkey: any(named: 'ownerPubkey'),
                    ),
                  ).captured.single
                  as List<NotificationCacheRow>;
          final row = captured.singleWhere((r) => r.type != 'seen_marker');
          expect(row.type, equals('videoMention'));
          expect(row.videoAddressableId, equals(senderCoordinate));
        },
      );

      test(
        'kind 1111 staging mention with rootEventId maps to video comment',
        () async {
          stubNotifications([
            makeNotification(
              id: '',
              sourceEventId: 'comment_evt_id',
              sourceKind: 1111,
              notificationType: 'mention',
              referencedEventId: '',
              rootEventId: 'root_video_evt_id',
              targetCommentId: 'comment_evt_id',
              content: 'Fake staging comment from Codex',
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as VideoNotification;
          expect(item.id, equals('comment_evt_id'));
          expect(item.type, equals(NotificationKind.comment));
          expect(item.videoEventId, equals('root_video_evt_id'));
          expect(item.commentText, equals('Fake staging comment from Codex'));
          expect(item.sourceEventIds, equals(['comment_evt_id']));
        },
      );

      test(
        'kind 1111 reply with rootEventId stays reply and keeps actor anchor',
        () async {
          stubNotifications([
            makeNotification(
              id: '',
              sourceEventId: 'reply_evt_id',
              sourceKind: 1111,
              notificationType: 'reply',
              referencedEventId: '',
              rootEventId: 'root_video_evt_id',
              targetCommentId: 'parent_comment_evt_id',
              content: 'Nested reply from staging payload',
              isReferencedVideo: false,
            ),
          ]);
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });

          final page = await repository.getNotifications();

          final item = page.items.single as ActorNotification;
          expect(item.id, equals('reply_evt_id'));
          expect(item.type, equals(NotificationKind.reply));
          expect(item.targetEventId, equals('parent_comment_evt_id'));
          expect(item.commentText, equals('Nested reply from staging payload'));
          expect(item.sourceEventIds, equals(['reply_evt_id']));
        },
      );

      test('follow maps to follow ($ActorNotification)', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('contact maps to follow', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'contact',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.follow));
      });

      test('zap maps to like', () async {
        stubNotifications([
          makeNotification(notificationType: 'zap', sourceKind: 9735),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.type, equals(NotificationKind.like));
      });

      test('completely unknown type and kind maps to system', () async {
        stubNotifications([
          makeNotification(
            notificationType: 'unknown',
            sourceKind: 9999,
            referencedEventId: null,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        expect(item.type, equals(NotificationKind.system));
      });
    });

    group('comment text truncation', () {
      test('truncates comment text > 50 chars on $VideoNotification', () async {
        // Comment-on-video is now a VideoNotification, but the repository
        // does not currently surface commentText on that type. So we test
        // truncation through the actor-anchored path (mention with content)
        // since mention/reply/system go through _truncateComment too.
        final longComment = 'A' * 60;
        stubNotifications([
          makeNotification(
            notificationType: 'mention',
            sourceKind: 1,
            referencedEventId: null,
            content: longComment,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as ActorNotification;
        // Mention is not in the comment/reply truncation path → null.
        expect(item.commentText, isNull);
      });

      test(
        'comment kind on video is a $VideoNotification with commentText',
        () async {
          // The repository carries the comment body through to the row
          // so it can quote the most recent comment under the message.
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: 'Short comment',
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.comment));
          expect(item.commentText, equals('Short comment'));
        },
      );

      test(
        'truncates a long comment on $VideoNotification (120 chars + ellipsis)',
        () async {
          final longComment = 'A' * 200;
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: longComment,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          // Reuses _truncateComment: caps at 120 chars and appends "..."
          // so the row never tries to render an unbounded comment body.
          expect(item.commentText, equals('${'A' * 120}...'));
        },
      );

      test(
        'keeps a valid bech32 npub intact',
        () async {
          // Regression: a reply whose content begins with a raw npub longer
          // than the 50-char preview cap must keep the token intact so the
          // row widget can decode it to a display name. Slicing it
          // mid-bech32 destroyed the checksum and the row fell back to
          // rendering a raw "npub1..." fragment verbatim.
          final npub = validNpub;
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: npub,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, equals(npub));
        },
      );

      test(
        'keeps a bech32 npub after leading whitespace or punctuation',
        () async {
          final npub = validNpub;
          final content = ' @$npub';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, equals(content));
        },
      );

      test("keeps the mention in #6763's reported example", () async {
        // The issue's own example. It no longer straddles the cap at 120, so
        // this guards the cap; the straddle POLICY is guarded separately
        // below. Previously this rendered as 'Reply to...' — the mention,
        // the only meaningful part of the preview, was deleted.
        const npub =
            'npub180cvv07tjdrrgpa9jzd0cdkej42kwsaxq9rz7gvdpjx6nz004f9uulstw6';
        const content = 'Reply to $npub more';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, equals(content));
        expect(item.commentText, contains(npub));
      });

      test('keeps the mention in the production #6763 comment', () async {
        // Real comment from api.divine.video, event
        // 65e5c466b0c722ce3eccfe11fe65d07dbc7f42d1e3e21f2f1148a238772bbc32.
        // 82 code units, so it now survives whole; it used to render as
        // 'The big guy....' with the mention deleted.
        const npub =
            'npub1m9d23lqwl78y3z2jf9dcqeyer5nlh9hdsef0ztx7m3dyaz'
            '66u4qq4stysk';
        const content = 'The big guy. nostr:$npub';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, equals(content));
      });

      test(
        'keeps a mid-sentence mention straddling the cap, not just the limit',
        () async {
          // Guards the straddle POLICY, not the cap number: 100 chars of
          // lead-in push the npub past the 120-char cap, so the token is only
          // preserved because a straddling reference is now kept whole.
          final npub = validNpub;
          final content = '${'word ' * 20}$npub tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, contains(npub));
          expect(item.commentText, endsWith('...'));
        },
      );

      test('keeps a 64-hex reference straddling the cap', () async {
        // The lead-in pushes the hex past the 120-char cap so the straddle
        // branch is actually exercised — a shorter string would return early
        // from _truncateComment and pass without testing anything.
        const hex =
            'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
        final content = '${'word ' * 20}$hex tail';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, contains(hex));
        expect(item.commentText, endsWith('...'));
      });

      test('never splits a surrogate pair at the cut', () async {
        // The cap counts UTF-16 code units, so a naive cut lands between the
        // halves of an astral emoji and strands a lone high surrogate.
        final content = '${'b' * 119}\u{1F600} and a good deal more text here';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        final units = item.commentText!.codeUnits;
        for (var i = 0; i < units.length; i++) {
          final unit = units[i];
          final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
          final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
          if (isHigh) {
            expect(
              i + 1 < units.length &&
                  units[i + 1] >= 0xDC00 &&
                  units[i + 1] <= 0xDFFF,
              isTrue,
              reason: 'unpaired high surrogate at $i',
            );
          } else if (isLow) {
            expect(
              i > 0 && units[i - 1] >= 0xD800 && units[i - 1] <= 0xDBFF,
              isTrue,
              reason: 'unpaired low surrogate at $i',
            );
          }
        }
      });

      test(
        'uses the plain cap for a leading unbounded token-shaped run',
        () async {
          final content = 'nprofile1${'q' * 180} tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, equals('${content.substring(0, 120)}...'));
        },
      );

      test(
        'keeps a straddling nostr:-prefixed profile reference with relay hints',
        () async {
          final nprofile = NIP19Tlv.encodeNprofile(
            Nprofile(
              pubkey: validPubkey,
              relays: const ['wss://relay.damus.io'],
            ),
          );
          expect(nprofile.length, greaterThan(90));
          final content = '${'word ' * 20}nostr:$nprofile tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, contains(nprofile));
          expect(item.commentText, contains('nostr:'));
          expect(item.commentText, endsWith('...'));
        },
      );

      test(
        'keeps a leading naddr that the quote UI renders as a video label',
        () async {
          final naddr = NIP19Tlv.encodeNaddr(
            Naddr(
              id: 'stable-video-reference',
              author:
                  'abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                  '0123456789',
              kind: 34236,
              relays: const ['wss://relay.divine.video'],
            ),
          );
          expect(naddr.length, greaterThan(120));
          final content = 'nostr:$naddr tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, contains(naddr));
          expect(item.commentText, isNot(equals('...')));
          expect(item.commentText, endsWith('...'));
        },
      );

      test(
        'caps unbounded leading token-shaped content',
        () async {
          final content = 'npub1${'a' * 5000}';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.commentText, equals('${content.substring(0, 120)}...'));
          expect(item.commentText!.length, lessThanOrEqualTo(123));
        },
      );

      test(
        'does not treat embedded alphanumeric bech32-looking text as a token',
        () async {
          final content = 'prefixnpub1${'a' * 130}';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          // No token boundary here, so the plain cap applies.
          expect(item.commentText, equals('${content.substring(0, 120)}...'));
        },
      );

      test('keeps a bounded leading 64-hex reference intact', () async {
        // LinkifiedTextSpanBuilder decodes a bare 64-char hex pubkey / event
        // id the same way it decodes bech32, so the cut must never slice one.
        const hex64 =
            'a1b2c3d4e5f60718293a4b5c6d7e8f90'
            'a1b2c3d4e5f60718293a4b5c6d7e8f90';
        final content = '$hex64 ${'and some trailing words ' * 4}';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, contains(hex64));
        expect(item.commentText, endsWith('...'));
      });

      test(
        'keeps a non-Latin lead-in mention that straddles the cut',
        () async {
          // #6763 asks for Latin and non-Latin lead-in so the fix cannot
          // silently regress to being locale-sensitive. Lead-in is long
          // enough that the npub straddles the 120-char cap (not only
          // fits under it).
          final npub = validNpub;
          const cyrillic = 'Привет всем друзьям сегодня';
          final content = '$cyrillic ${'слово ' * 14}nostr:$npub tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(content.length, greaterThan(120));
          expect(item.commentText, contains(npub));
          expect(item.commentText, startsWith(cyrillic));
          expect(item.commentText, endsWith('...'));
        },
      );

      test(
        'keeps a punctuation-prefixed profile reference that straddles the cut',
        () async {
          final nprofile = NIP19Tlv.encodeNprofile(
            Nprofile(
              pubkey: validPubkey,
              relays: const ['wss://relay.divine.video'],
            ),
          );
          final content = '«— » ${'— ' * 45}nostr:$nprofile tail';
          stubNotifications([
            makeNotification(
              notificationType: 'comment',
              sourceKind: 1,
              content: content,
            ),
          ]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(content.length, greaterThan(120));
          expect(item.commentText, contains(nprofile));
          expect(item.commentText, endsWith('...'));
        },
      );

      test('leaves a hex run inside a URL to the plain cut', () async {
        // The UI's URL alternative starts earlier than the hex one and wins,
        // so https://host/<64-hex> is a single URL token and the hex inside
        // it is never linked. Pulling the cut back to it would shorten the
        // preview for a span the UI never resolves. Blossom and CDN media
        // URLs are exactly this shape, so this is the common case, not an
        // edge case.
        const hex64 =
            'a1b2c3d4e5f60718293a4b5c6d7e8f90'
            'a1b2c3d4e5f60718293a4b5c6d7e8f90';
        const content =
            'Look at this https://blossom.divine.video/$hex64.mp4 great stuff';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, equals('${content.substring(0, 120)}...'));
      });

      test('leaves a bech32 token inside a URL to the plain cut', () async {
        // Same rule as the hex case: a share link is one URL token in the UI,
        // so the npub in its path is not a reference either.
        const npub =
            'npub180cvv07tjdrrgpa9jzd0cdkej42kwsaxq9rz7gvdpjx6nz004f9uulstw6';
        const content =
            'Follow https://divine.video/$npub please '
            'and then keep reading well past the preview cap';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(item.commentText, equals('${content.substring(0, 120)}...'));
        expect(
          item.commentText,
          startsWith('Follow https://divine.video/npub1'),
        );
      });

      test('leaves a hex run behind a hashtag to the plain cut', () async {
        // The hashtag alternative also starts earlier and swallows the run.
        const hex64 =
            'a1b2c3d4e5f60718293a4b5c6d7e8f90'
            'a1b2c3d4e5f60718293a4b5c6d7e8f90';
        const content =
            'nice one #$hex64 keep going with more words here '
            'so the plain cut is actually exercised';
        stubNotifications([
          makeNotification(
            notificationType: 'comment',
            sourceKind: 1,
            content: content,
          ),
        ]);
        stubProfiles({});

        final page = await repository.getNotifications();
        final item = page.items.single as VideoNotification;
        expect(
          item.commentText,
          equals('${content.substring(0, 120).trimRight()}...'),
        );
      });

      test(
        'like / repost on video leaves commentText null (no body text)',
        () async {
          // Default makeNotification is a reaction (kind 7) on a video,
          // which the repository maps to NotificationKind.like.
          stubNotifications([makeNotification()]);
          stubProfiles({});

          final page = await repository.getNotifications();
          final item = page.items.single as VideoNotification;
          expect(item.type, equals(NotificationKind.like));
          expect(item.commentText, isNull);
        },
      );
    });

    group('cache hydration', () {
      test('emits cached rows on construction when DAO has data', () async {
        final cachedRow = NotificationRow(
          id: 'cached_1',
          type: 'like',
          fromPubkey: 'cached_actor',
          timestamp: 1700000000,
          targetEventId: 'cached_event',
          hasCommentTarget: false,
          isRead: false,
          cachedAt: DateTime(2026),
        );
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => [cachedRow]);

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        // Snapshot starts at empty and updates once hydration resolves.
        // Use emitsThrough so the test is robust to the seeded empty
        // emission ordering.
        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>(
              (p) => p.items.length == 1 && p.items.first.id == 'cached_1',
              'snapshot contains the hydrated row',
            ),
          ),
        );
      });

      test('hydrates listAdd rows with list context from cache', () async {
        const listCoordinate = '30005:cached_actor:literature';
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            NotificationRow(
              id: 'cached_list_add',
              type: 'listAdd',
              fromPubkey: 'cached_actor',
              timestamp: 1700000000,
              targetEventId: 'cached_video',
              targetPubkey: listCoordinate,
              content: 'Literature',
              hasCommentTarget: false,
              isRead: false,
              cachedAt: DateTime(2026),
            ),
          ],
        );

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>((p) {
              if (p.items.singleOrNull case final VideoNotification item) {
                return item.type == NotificationKind.listAdd &&
                    item.listTitle == 'Literature' &&
                    item.listCoordinate == listCoordinate;
              }
              return false;
            }, 'snapshot contains hydrated listAdd row'),
          ),
        );
      });

      test('filtered feeds seed from the hydrated unfiltered rows', () async {
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            NotificationRow(
              id: 'cached_like',
              type: 'like',
              fromPubkey: 'cached_actor',
              timestamp: 1700000000,
              targetEventId: 'cached_video',
              hasCommentTarget: false,
              isRead: false,
              cachedAt: DateTime(2026),
            ),
            NotificationRow(
              id: 'cached_follow',
              type: 'follow',
              fromPubkey: 'cached_follower',
              timestamp: 1700000001,
              hasCommentTarget: false,
              isRead: false,
              cachedAt: DateTime(2026),
            ),
          ],
        );

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);
        // Give the unawaited hydration a chance to resolve.
        await Future<void>.delayed(Duration.zero);

        // Only the unfiltered feed reads the DAO, so without the cross-feed
        // seed a category tab starts empty and a failed first fetch renders
        // the full-screen failure body instead of cached rows.
        final follows = await hydrated
            .watchSnapshot(filter: NotificationKind.follow)
            .first;
        expect(follows.items.map((n) => n.id), equals(['cached_follow']));
        final likes = await hydrated
            .watchSnapshot(filter: NotificationKind.like)
            .first;
        expect(likes.items.map((n) => n.id), equals(['cached_like']));
      });

      test('filtered feeds mounted before hydration are seeded too', () async {
        final daoGate = Completer<List<NotificationRow>>();
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) => daoGate.future);

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        // The repository is built when ProfileRepository resolves, which on a
        // cold start can land after the inbox already mounted its tabs.
        final emissions = <NotificationPage>[];
        final sub = hydrated
            .watchSnapshot(filter: NotificationKind.follow)
            .listen(emissions.add);
        addTearDown(sub.cancel);

        daoGate.complete([
          NotificationRow(
            id: 'cached_follow',
            type: 'follow',
            fromPubkey: 'cached_follower',
            timestamp: 1700000001,
            hasCommentTarget: false,
            isRead: false,
            cachedAt: DateTime(2026),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(
          emissions.last.items.map((n) => n.id),
          equals(['cached_follow']),
        );
      });

      test('hydration is a no-op when DAO is empty', () async {
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => <NotificationRow>[]);

        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);
        // Give the unawaited hydration a chance to resolve.
        await Future<void>.delayed(Duration.zero);
        final snapshot = await hydrated.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
      });

      test(
        'cached "like" row becomes $VideoNotification placeholder preserving '
        'videoEventId and actor pubkey',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_like_1',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_1',
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is VideoNotification &&
                    item.id == 'cached_like_1' &&
                    item.type == NotificationKind.like &&
                    item.videoEventId == 'video_evt_1' &&
                    item.actors.length == 1 &&
                    item.actors.first.pubkey == 'actor_pub' &&
                    item.totalCount == 1 &&
                    item.commentText == null;
              }, 'placeholder is VideoNotification(like) keyed to video'),
            ),
          );
        },
      );

      test(
        'cached "actorLike" row remains an anchorless actor like',
        () async {
          const rootAddressableId =
              '34236:user1234567890abcdef:addressable-video';
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_actor_like',
                type: 'actorLike',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'reaction_event',
                videoAddressableId: rootAddressableId,
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is ActorNotification &&
                    item.id == 'cached_actor_like' &&
                    item.type == NotificationKind.like &&
                    item.targetEventId == 'reaction_event' &&
                    item.videoAddressableId == rootAddressableId &&
                    item.actor.pubkey == 'actor_pub';
              }, 'placeholder is ActorNotification(like)'),
            ),
          );
        },
      );

      test(
        'cached video placeholders are enriched with actor and video metadata',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_like_1',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_1',
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          stubProfiles({
            'actor_pub': makeProfile(
              'actor_pub',
              displayName: 'Alice',
              picture: 'https://example.com/alice.jpg',
            ),
          });
          stubVideoStats(
            'video_evt_1',
            makeVideoStats(
              id: 'video_evt_1',
              title: 'Cached clip',
              thumbnail: 'https://example.com/thumb.jpg',
            ),
          );

          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.single;
                return item is VideoNotification &&
                    item.actors.single.displayName == 'Alice' &&
                    item.actors.single.pictureUrl ==
                        'https://example.com/alice.jpg' &&
                    item.videoTitle == 'Cached clip' &&
                    item.videoThumbnailUrl == 'https://example.com/thumb.jpg' &&
                    item.videoAddressableId ==
                        '34236:$userPubkey:d_video_evt_1';
              }, 'cached placeholder is enriched after hydration'),
            ),
          );
        },
      );

      test(
        'cached actor placeholders are enriched with profile metadata',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_follow_1',
                type: 'follow',
                fromPubkey: 'follower_pub',
                timestamp: 1700000000,
                hasCommentTarget: false,
                targetPubkey: 'follower_pub',
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          stubProfiles({
            'follower_pub': makeProfile(
              'follower_pub',
              displayName: 'Bob',
              picture: 'https://example.com/bob.jpg',
            ),
          });

          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.single;
                return item is ActorNotification &&
                    item.actor.displayName == 'Bob' &&
                    item.actor.pictureUrl == 'https://example.com/bob.jpg';
              }, 'cached actor placeholder is enriched after hydration'),
            ),
          );
        },
      );

      test(
        'cached enrichment does not overwrite a completed refresh snapshot',
        () async {
          final pendingProfiles = Completer<Map<String, UserProfile>>();
          var profileFetchCount = 0;
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) {
            profileFetchCount++;
            if (profileFetchCount == 1) {
              return pendingProfiles.future;
            }
            return Future.value({
              'actor_pub': makeProfile('actor_pub', displayName: 'Alice'),
              'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            });
          });
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_like_1',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_1',
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );

          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.single;
                return item is VideoNotification && item.id == 'cached_like_1';
              }, 'snapshot contains cached placeholder'),
            ),
          );

          stubNotifications([
            makeNotification(
              id: 'older_server_notification',
              sourcePubkey: 'actor_pub',
              sourceEventId: 'older_source_event',
              referencedEventId: 'video_evt_1',
              createdAt: DateTime(2025),
              referencedVideoTitle: 'Server title',
              referencedVideoThumbnail: 'https://example.com/server.jpg',
            ),
            makeNotification(
              id: 'cached_like_1',
              sourcePubkey: 'pubkey_bob',
              sourceEventId: 'newer_source_event',
              referencedEventId: 'video_evt_1',
              createdAt: DateTime(2025, 1, 2),
              referencedVideoTitle: 'Server title',
              referencedVideoThumbnail: 'https://example.com/server.jpg',
            ),
          ], unreadCount: 2);

          await hydrated.refresh();
          pendingProfiles.complete({
            'actor_pub': makeProfile('actor_pub', displayName: 'Alice'),
          });
          await Future<void>.delayed(Duration.zero);

          final item =
              (await hydrated.watchSnapshot().first).items.single
                  as VideoNotification;
          expect(item.id, equals('cached_like_1'));
          expect(item.actors.map((a) => a.pubkey), ['pubkey_bob', 'actor_pub']);
          expect(item.totalCount, equals(2));
          expect(item.videoTitle, equals('Server title'));
          expect(
            item.videoThumbnailUrl,
            equals('https://example.com/server.jpg'),
          );
          expect(item.sourceEventIds, [
            'newer_source_event',
            'older_source_event',
          ]);
          expect(item.notificationIds, [
            'cached_like_1',
            'older_server_notification',
          ]);
          expect(item.isRead, isFalse);
        },
      );

      test(
        'cached enrichment preserves an interim markAsRead update',
        () async {
          final pendingProfiles = Completer<Map<String, UserProfile>>();
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => pendingProfiles.future);
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_like_1',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_1',
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );
          when(
            () => notificationsDao.markAsRead(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => true);

          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.single;
                return item is VideoNotification &&
                    item.id == 'cached_like_1' &&
                    !item.isRead;
              }, 'snapshot contains unread cached placeholder'),
            ),
          );

          await hydrated.markAsRead(['cached_like_1']);
          pendingProfiles.complete({
            'actor_pub': makeProfile('actor_pub', displayName: 'Alice'),
          });
          await Future<void>.delayed(Duration.zero);

          final item =
              (await hydrated.watchSnapshot().first).items.single
                  as VideoNotification;
          expect(item.isRead, isTrue);
          expect(item.actors.single.displayName, equals('Alice'));
        },
      );

      test('cached "comment" row becomes $VideoNotification placeholder '
          'with commentText preserved', () async {
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            NotificationRow(
              id: 'cached_comment_1',
              type: 'comment',
              fromPubkey: 'actor_pub',
              timestamp: 1700000000,
              targetEventId: 'video_evt_2',
              hasCommentTarget: false,
              content: 'Nice clip!',
              isRead: false,
              cachedAt: DateTime(2026),
            ),
          ],
        );
        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>((p) {
              if (p.items.length != 1) return false;
              final item = p.items.first;
              return item is VideoNotification &&
                  item.type == NotificationKind.comment &&
                  item.videoEventId == 'video_evt_2' &&
                  item.commentText == 'Nice clip!';
            }, 'placeholder is VideoNotification(comment) with content'),
          ),
        );
      });

      test('cached "videoMention" row remains a video mention placeholder '
          'with stable route', () async {
        const addressableId =
            '${NIP71VideoKinds.addressableShortVideo}:'
            'source_author:video-d-tag';
        when(
          () => notificationsDao.getAllNotifications(
            limit: any(named: 'limit'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => [
            NotificationRow(
              id: 'cached_video_mention_1',
              type: 'videoMention',
              fromPubkey: 'actor_pub',
              timestamp: 1700000000,
              targetEventId: 'source_video_evt',
              videoAddressableId: addressableId,
              hasCommentTarget: false,
              isRead: false,
              cachedAt: DateTime(2026),
            ),
          ],
        );
        final hydrated = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
        );
        addTearDown(hydrated.close);

        await expectLater(
          hydrated.watchSnapshot(),
          emitsThrough(
            predicate<NotificationPage>((p) {
              if (p.items.length != 1) return false;
              final item = p.items.first;
              return item is VideoNotification &&
                  item.type == NotificationKind.mention &&
                  item.videoEventId == 'source_video_evt' &&
                  item.videoAddressableId == addressableId;
            }, 'placeholder is VideoNotification(mention) with addressable id'),
          ),
        );
      });

      test(
        'cached "videoMention" row restores source coordinate from metadata',
        () async {
          const expectedAddressableId =
              '${NIP71VideoKinds.addressableShortVideo}:'
              'source_author:source-video-d-tag';
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_video_mention_1',
                type: 'videoMention',
                fromPubkey: 'source_author',
                timestamp: 1700000000,
                targetEventId: 'source_video_evt',
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          stubVideoStats(
            'source_video_evt',
            makeVideoStats(
              id: 'source_video_evt',
              pubkey: 'source_author',
              dTag: 'source-video-d-tag',
            ),
          );

          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          final page = await hydrated
              .watchSnapshot()
              .firstWhere((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is VideoNotification &&
                    item.type == NotificationKind.mention &&
                    item.videoAddressableId == expectedAddressableId;
              })
              .timeout(const Duration(seconds: 1));

          final item = page.items.single as VideoNotification;
          expect(item.videoEventId, equals('source_video_evt'));
          expect(item.actors.single.pubkey, equals('source_author'));
        },
      );

      test(
        'cached "repost" row becomes $VideoNotification placeholder',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_repost_1',
                type: 'repost',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                targetEventId: 'video_evt_3',
                hasCommentTarget: false,
                isRead: true,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is VideoNotification &&
                    item.type == NotificationKind.repost &&
                    item.videoEventId == 'video_evt_3' &&
                    item.isRead &&
                    item.commentText == null;
              }, 'placeholder is VideoNotification(repost) preserving isRead'),
            ),
          );
        },
      );

      test(
        'cached "like" row with null targetEventId is skipped — degrading '
        'to system would hide the row from the Likes tab and make tap a no-op',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'orphan_like',
                type: 'like',
                fromPubkey: 'actor_pub',
                timestamp: 1700000000,
                hasCommentTarget: false,
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);
          // Give the unawaited hydration a chance to resolve.
          await Future<void>.delayed(Duration.zero);
          final snapshot = await hydrated.watchSnapshot().first;
          expect(snapshot.items, isEmpty);
        },
      );

      test(
        'cached "follow" row remains an $ActorNotification placeholder',
        () async {
          when(
            () => notificationsDao.getAllNotifications(
              limit: any(named: 'limit'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer(
            (_) async => [
              NotificationRow(
                id: 'cached_follow_1',
                type: 'follow',
                fromPubkey: 'follower_pub',
                timestamp: 1700000000,
                hasCommentTarget: false,
                targetPubkey: 'follower_pub',
                isRead: false,
                cachedAt: DateTime(2026),
              ),
            ],
          );
          final hydrated = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
          );
          addTearDown(hydrated.close);

          await expectLater(
            hydrated.watchSnapshot(),
            emitsThrough(
              predicate<NotificationPage>((p) {
                if (p.items.length != 1) return false;
                final item = p.items.first;
                return item is ActorNotification &&
                    item.type == NotificationKind.follow &&
                    item.actor.pubkey == 'follower_pub';
              }, 'placeholder is ActorNotification(follow)'),
            ),
          );
        },
      );
    });

    group('refresh', () {
      test('resets cursor and fetches from beginning', () async {
        stubNotifications([], nextCursor: 'cursor_1');
        stubProfiles({});
        await repository.getNotifications();

        stubNotifications([]);
        await repository.refresh();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(2);
      });

      test(
        'superseded first-page failure does not mark refresh error',
        () async {
          stubProfiles({});

          final staleGate = Completer<NotificationResponse>();
          when(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              cursorId: any(named: 'cursorId'),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => staleGate.future);
          final staleFetch = repository.getNotifications();

          stubNotifications([
            makeNotification(
              id: 'fresh',
              sourceEventId: 'evt_fresh',
              referencedEventId: 'video_fresh',
            ),
          ]);
          await repository.refresh();

          staleGate.completeError(const FunnelcakeException('stale'));

          await expectLater(staleFetch, throwsA(isA<FunnelcakeException>()));
          final snapshot = await repository.watchSnapshot().first;
          expect(snapshot.lastRefreshError, isFalse);
          expect(
            (snapshot.items.single as VideoNotification).videoEventId,
            equals('video_fresh'),
          );
        },
      );

      test('refreshApplied returns false when superseded', () async {
        stubProfiles({});

        final staleGate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => staleGate.future);
        final staleRefresh = repository.refreshApplied();

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();

        staleGate.complete(
          const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          ),
        );

        await expectLater(staleRefresh, completion(isFalse));
      });

      test('refreshApplied leaves a deep-scrolled feed intact', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        final likesSubscription = repository
            .watchSnapshot(filter: NotificationKind.like)
            .listen((_) {});
        addTearDown(likesSubscription.cancel);
        await repository.refreshFeed(NotificationKind.like);
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPageFor(NotificationKind.like);

        stubNotifications([]);
        await repository.refreshApplied();

        // A first-page replace would have collapsed Likes back to one
        // page under the user; it must be skipped, not refreshed.
        final likes = await repository
            .watchSnapshot(filter: NotificationKind.like)
            .first;
        expect(likes.items, hasLength(2));
        // Likes is the only live feed and it is deep-scrolled, so there is
        // genuinely nothing left for a resume refresh to serve.
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);
      });

      test(
        'refreshApplied skips filtered feeds nobody is listening to',
        () async {
          stubProfiles({});
          stubNotifications([makeNotification()]);
          // Open and close the Likes tab: its feed stays in the map, but the
          // bloc's subscription is gone.
          final likes = repository
              .watchSnapshot(filter: NotificationKind.like)
              .listen((_) {});
          await repository.refreshFeed(NotificationKind.like);
          await likes.cancel();
          // The badge keeps the unfiltered feed subscribed app-wide.
          final all = repository.watchSnapshot().listen((_) {});
          addTearDown(all.cancel);
          await repository.refreshFeed(null);

          clearInteractions(funnelcakeApiClient);
          await repository.refreshApplied();

          verify(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              cursorId: any(named: 'cursorId'),
              types: any(named: 'types', that: isNull),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          ).called(1);
          verifyNever(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              cursorId: any(named: 'cursorId'),
              types: const ['reaction', 'zap'],
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      test('refreshApplied keeps refreshing after one feed fails', () async {
        stubProfiles({});
        stubNotifications([makeNotification()]);
        final likes = repository
            .watchSnapshot(filter: NotificationKind.like)
            .listen((_) {});
        addTearDown(likes.cancel);
        await repository.refreshFeed(NotificationKind.like);
        await repository.refreshFeed(null);

        // The unfiltered feed is created first, so without per-feed error
        // isolation its failure would abort the whole fan-out.
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: any(named: 'types', that: isNull),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'boom', statusCode: 500),
        );

        await expectLater(repository.refreshApplied(), completion(isTrue));

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: const ['reaction', 'zap'],
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(greaterThanOrEqualTo(1));
      });
    });

    group('loadNextPage', () {
      test('no-ops without a stored pagination cursor', () async {
        final result = await repository.loadNextPage();

        expect(result, isNull);
        verifyNever(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        );
      });

      test('requests the stored cursor and appends the next page', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        stubNotifications([
          makeNotification(
            id: 'n2',
            sourceEventId: 'evt2',
            referencedEventId: 'video_2',
          ),
        ]);
        final page = await repository.loadNextPage();

        expect(page, isNotNull);
        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(2));
        final cursors = verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: captureAny(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).captured;
        expect(cursors, equals([null, 'c1']));
      });

      test('during an in-flight refresh it no-ops instead of issuing a '
          'duplicate first-page request', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        final gate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => gate.future);
        final refreshFuture = repository.refresh();

        final result = await repository.loadNextPage();

        expect(result, isNull);
        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).called(2);

        gate.complete(
          const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          ),
        );
        await refreshFuture;
      });

      test('stale completion after a refresh neither regresses the cursor '
          'nor appends onto the replaced snapshot', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        final gate = Completer<NotificationResponse>();
        when(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => gate.future);
        final staleLoadMore = repository.loadNextPage();

        stubNotifications(
          [
            makeNotification(
              id: 'n9',
              sourceEventId: 'evt9',
              referencedEventId: 'video_9',
            ),
          ],
          nextCursor: 'r1',
          hasMore: true,
        );
        await repository.refresh();

        gate.complete(
          NotificationResponse(
            notifications: [
              makeNotification(
                id: 'n_stale',
                sourceEventId: 'evt_stale',
                referencedEventId: 'video_stale',
              ),
            ],
            unreadCount: 0,
            hasMore: true,
            nextCursor: 'c2_stale',
          ),
        );
        await staleLoadMore;

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(1));
        expect(
          (snapshot.items.single as VideoNotification).videoEventId,
          equals('video_9'),
        );

        stubNotifications([]);
        await repository.loadNextPage();
        final cursors = verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: captureAny(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).captured;
        expect(cursors, equals([null, 'c1', null, 'r1']));
      });
    });

    group('hasPaginatedBeyondFirstPage', () {
      test('false until a page beyond the first is applied', () async {
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('true after a load-more, false again after a refresh', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        stubNotifications([]);
        await repository.refresh();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('false while any live feed is still on its first page', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refreshFeed(NotificationKind.like);
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPageFor(NotificationKind.like);

        // Likes is two pages deep, but the unfiltered feed is not — a
        // resume refresh can still serve it, so the guard must stay open.
        await repository.refreshFeed(null);

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('resetPaginationDepth releases the resume-refresh guard', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.getNotifications();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();

        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        repository.resetPaginationDepth();

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test(
        'resetPaginationDepth collapses the snapshot to the newest page',
        () async {
          stubProfiles({});
          // A session that scrolled deep leaves more than a page of items in
          // the long-lived snapshot. Build a 25-item first page with distinct,
          // descending timestamps (n0 newest) so the newest-first order is
          // deterministic and the trim back to the page size is observable.
          stubNotifications([
            for (var i = 0; i < 25; i++)
              makeNotification(
                id: 'n$i',
                sourcePubkey: 'pub_$i',
                sourceEventId: 'evt$i',
                referencedEventId: 'video_$i',
                createdAt: DateTime(2025).subtract(Duration(minutes: i)),
              ),
          ], hasMore: true);
          await repository.getNotifications();
          final before = (await repository.watchSnapshot().first).items;
          expect(before, hasLength(25));
          // Contract: trimming keeps the *newest* page — the first 20 rows of
          // the newest-first snapshot, in order — not an arbitrary 20.
          final expectedKeptIds = before.take(20).map((n) => n.id).toList();

          repository.resetPaginationDepth();

          final after = (await repository.watchSnapshot().first).items;
          expect(after.map((n) => n.id).toList(), equals(expectedKeptIds));
        },
      );

      test('resetPaginationDepth collapses a filtered feed snapshot', () async {
        stubProfiles({
          for (var i = 0; i < 25; i++)
            'follower_$i': makeProfile(
              'follower_$i',
              displayName: 'Follower $i',
            ),
        });
        stubNotifications([
          for (var i = 0; i < 25; i++)
            makeNotification(
              id: 'follow_$i',
              sourcePubkey: 'follower_$i',
              sourceEventId: 'follow_evt_$i',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              createdAt: DateTime(2025).subtract(Duration(minutes: i)),
            ),
        ], hasMore: true);
        await repository.getNotifications(filter: NotificationKind.follow);
        final before =
            (await repository
                    .watchSnapshot(filter: NotificationKind.follow)
                    .first)
                .items;
        expect(before, hasLength(25));
        final expectedKeptIds = before.take(20).map((n) => n.id).toList();

        repository.resetPaginationDepth(filter: NotificationKind.follow);

        final after =
            (await repository
                    .watchSnapshot(filter: NotificationKind.follow)
                    .first)
                .items;
        expect(after.map((n) => n.id).toList(), equals(expectedKeptIds));
      });
    });

    group('markAsRead', () {
      test('calls API and DAO for each id', () async {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 2),
        );
        when(
          () => notificationsDao.markAsRead(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);

        await repository.markAsRead(['n1', 'n2']);

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            notificationIds: ['n1', 'n2'],
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead('n1', ownerPubkey: userPubkey),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead('n2', ownerPubkey: userPubkey),
        ).called(1);
      });

      test('does nothing for empty id list', () async {
        await repository.markAsRead([]);

        verifyNever(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        );
      });

      test('updates matching rows in every live filtered snapshot', () async {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 1),
        );
        when(
          () => notificationsDao.markAsRead(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);
        stubProfiles({
          'follower_pub': makeProfile('follower_pub', displayName: 'Follower'),
        });
        stubNotifications([
          makeNotification(
            id: 'follow_notification',
            sourceEventId: 'follow_event',
            sourcePubkey: 'follower_pub',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
          ),
        ], unreadCount: 1);

        await repository.getNotifications();
        await repository.getNotifications(filter: NotificationKind.follow);

        await repository.markAsRead(['follow_notification']);

        final allItem = (await repository.watchSnapshot().first).items.single;
        final followItem =
            (await repository
                    .watchSnapshot(filter: NotificationKind.follow)
                    .first)
                .items
                .single;
        expect(allItem.isRead, isTrue);
        expect(followItem.isRead, isTrue);
      });

      test('expands a grouped row to every raw notification id before '
          'marking read', () async {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 2),
        );
        when(
          () => notificationsDao.markAsRead(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([
          makeNotification(
            id: 'older_server_notification',
            sourceEventId: 'older_source_event',
            createdAt: DateTime(2025),
          ),
          makeNotification(
            id: 'newer_server_notification',
            sourcePubkey: 'pubkey_bob',
            sourceEventId: 'newer_source_event',
            createdAt: DateTime(2025, 1, 2),
          ),
        ], unreadCount: 2);
        await repository.refresh();

        final groupedRow = (await repository.watchSnapshot().first).items.first;

        await repository.markAsRead([groupedRow.id]);

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            notificationIds: [
              'newer_server_notification',
              'older_server_notification',
            ],
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead(
            'newer_server_notification',
            ownerPubkey: userPubkey,
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAsRead(
            'older_server_notification',
            ownerPubkey: userPubkey,
          ),
        ).called(1);
      });

      test(
        'rolls back the optimistic snapshot when authHeadersProvider throws',
        () async {
          // authHeadersProvider returns headers for GET (initial refresh)
          // but throws on POST (the mark-read call). The rollback boundary
          // must cover this failure mode — pre-fix it didn't, so the
          // optimistic isRead=true flip stayed live with no server write.
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              if (method == 'POST') {
                throw Exception('signer unavailable');
              }
              return {'Authorization': 'Nostr test-token'};
            },
          );

          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();

          final loadedId =
              (await repository.watchSnapshot().first).items.first.id;
          expect(await repository.watchUnreadCount().first, equals(1));

          await expectLater(
            repository.markAsRead([loadedId]),
            throwsA(isA<Exception>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'Auth-header failure must roll back the optimistic flip — '
                'the snapshot should return to its pre-call state.',
          );
          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      test(
        'rolls back optimistic snapshot on 200 / success:false soft-failure',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();
          final loadedId =
              (await repository.watchSnapshot().first).items.first.id;
          expect(await repository.watchUnreadCount().first, equals(1));

          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenThrow(
            const FunnelcakeApiException(
              message:
                  'Mark notifications read rejected by server: token rejected',
              statusCode: 200,
            ),
          );

          await expectLater(
            repository.markAsRead([loadedId]),
            throwsA(isA<FunnelcakeApiException>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'A 200 / success:false from the API now throws and must '
                'roll back the optimistic flip so the snapshot matches '
                'server truth.',
          );
          verifyNever(
            () => notificationsDao.markAsRead(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );
    });

    group('markAllAsRead', () {
      test('calls API and DAO when there are unread items', () async {
        // Seed the snapshot with an unread item so markAllAsRead's
        // early-return guard (skip when nothing is unread) does not fire.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 5),
        );
        when(
          () => notificationsDao.markAllAsRead(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => 5);

        await repository.markAllAsRead();

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: userPubkey,
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAllAsRead(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });

      test(
        'rolls back the optimistic snapshot when authHeadersProvider throws',
        () async {
          repository = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              if (method == 'POST') {
                throw Exception('signer unavailable');
              }
              return {'Authorization': 'Nostr test-token'};
            },
          );

          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();

          expect(await repository.watchUnreadCount().first, equals(1));

          await expectLater(
            repository.markAllAsRead(),
            throwsA(isA<Exception>()),
          );

          expect(
            await repository.watchUnreadCount().first,
            equals(1),
            reason:
                'Auth-header failure must roll back the optimistic flip — '
                'the snapshot should return to its pre-call state.',
          );
          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );
    });

    group('authHeadersProvider', () {
      test('passes auth headers to API calls when provided', () async {
        final authRepo = NotificationRepository(
          funnelcakeApiClient: funnelcakeApiClient,
          profileRepository: profileRepository,
          notificationsDao: notificationsDao,
          userPubkey: userPubkey,
          authHeadersProvider: (url, method, {body}) async => {
            'Authorization': 'Nostr abc123',
          },
        );

        stubNotifications([]);
        stubProfiles({});

        await authRepo.getNotifications();

        verify(
          () => funnelcakeApiClient.getNotifications(
            pubkey: userPubkey,
            cursor: any(named: 'cursor'),
            requestUri: any(named: 'requestUri'),
            authHeaders: {'Authorization': 'Nostr abc123'},
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      test(
        'does not call notifications API when auth header creation fails',
        () async {
          final authRepo = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              throw const FunnelcakeException('auth unavailable');
            },
            hydrateOnStart: false,
          );
          addTearDown(authRepo.close);

          await expectLater(
            authRepo.getNotifications(),
            throwsA(isA<FunnelcakeException>()),
          );

          verifyNever(
            () => funnelcakeApiClient.getNotifications(
              pubkey: any(named: 'pubkey'),
              cursor: any(named: 'cursor'),
              requestUri: any(named: 'requestUri'),
              authHeaders: any(named: 'authHeaders'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      test(
        'markAllAsRead signs the full mark-read URL and empty body',
        () async {
          // NIP-98 requires the auth event's `u` tag to match the
          // request URL exactly (scheme + host + path) and the
          // `payload` tag to be sha256 of the actual body. Pinning the
          // exact (url, body) tuple passed to the auth callback catches
          // any future drift to a path-only URL or empty payload —
          // both of which silently 401 the server and bounce the
          // notifications badge back up via the repository rollback.
          String? capturedUrl;
          String? capturedMethod;
          String? capturedBody;
          when(
            () => funnelcakeApiClient.notificationsReadUri(pubkey: userPubkey),
          ).thenReturn(
            Uri.parse(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: userPubkey,
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );
          when(
            () => notificationsDao.markAllAsRead(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => 1);

          final authRepo = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              capturedUrl = url;
              capturedMethod = method;
              capturedBody = body;
              return {'Authorization': 'Nostr signed-token'};
            },
          );
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          stubNotifications([makeNotification()], unreadCount: 1);
          await authRepo.refresh();

          await authRepo.markAllAsRead();

          expect(
            capturedUrl,
            equals(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          expect(capturedMethod, equals('POST'));
          // FunnelcakeApiClient.buildMarkNotificationsReadBody() with
          // no ids should produce `{}` — the exact bytes the request
          // body will carry.
          expect(capturedBody, equals('{}'));
        },
      );

      test(
        'markAsRead signs the body that includes the notification IDs',
        () async {
          String? capturedBody;
          when(
            () => funnelcakeApiClient.notificationsReadUri(pubkey: userPubkey),
          ).thenReturn(
            Uri.parse(
              'https://api.divine.video/api/users/$userPubkey/'
              'notifications/read',
            ),
          );
          when(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: userPubkey,
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );
          when(
            () => notificationsDao.markAsRead(
              any(),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async => true);

          final authRepo = NotificationRepository(
            funnelcakeApiClient: funnelcakeApiClient,
            profileRepository: profileRepository,
            notificationsDao: notificationsDao,
            userPubkey: userPubkey,
            authHeadersProvider: (url, method, {body}) async {
              capturedBody = body;
              return {'Authorization': 'Nostr signed-token'};
            },
          );
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          });
          // Use a single notification whose id is both the row id and
          // the expanded server notification id (the expansion in
          // `_expandServerNotificationIds` falls back to the row id
          // when the row carries no separate `notificationIds`).
          stubNotifications([
            makeNotification(id: 'server-notif-1', sourceEventId: 'evt-1'),
          ], unreadCount: 1);
          await authRepo.refresh();
          final loadedId =
              (await authRepo.watchSnapshot().first).items.first.id;

          await authRepo.markAsRead([loadedId]);

          // The expanded notification IDs end up in both the request
          // body the client posts and the `payload` tag the NIP-98
          // auth event signs — they must match byte-for-byte.
          expect(capturedBody, isNotNull);
          expect(capturedBody, contains('notification_ids'));
          expect(capturedBody, contains('server-notif-1'));
        },
      );
    });

    group('sorting', () {
      test('results are sorted by timestamp descending', () async {
        stubNotifications([
          makeNotification(
            id: 'old',
            sourcePubkey: 'pub_a',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_old',
            createdAt: DateTime(2025),
            content: 'Old',
          ),
          makeNotification(
            id: 'new',
            sourcePubkey: 'pub_b',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_new',
            createdAt: DateTime(2025, 6),
            content: 'New',
          ),
        ]);
        stubProfiles({
          'pub_a': makeProfile('pub_a', displayName: 'Alice'),
          'pub_b': makeProfile('pub_b', displayName: 'Bob'),
        });

        final page = await repository.getNotifications();

        expect(page.items, hasLength(2));
        expect((page.items[0] as VideoNotification).id, equals('new'));
        expect((page.items[1] as VideoNotification).id, equals('old'));
      });
    });

    group('reactive snapshot', () {
      setUp(() {
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 1),
        );
        when(
          () => notificationsDao.markAsRead(
            any(),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => notificationsDao.markAllAsRead(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async => 0);
      });

      test('seeds watchSnapshot with NotificationPage.empty', () async {
        await expectLater(
          repository.watchSnapshot().take(1),
          emitsInOrder([NotificationPage.empty]),
        );
      });

      test('watchUnreadCount starts at 0', () async {
        await expectLater(
          repository.watchUnreadCount().take(1),
          emitsInOrder([0]),
        );
      });

      test('isClosed flips after close()', () async {
        expect(repository.isClosed, isFalse);

        await repository.close();

        expect(repository.isClosed, isTrue);
      });

      test('resetPaginationDepth is a no-op after close()', () async {
        await repository.close();

        expect(
          () =>
              repository.resetPaginationDepth(filter: NotificationKind.follow),
          returnsNormally,
        );
      });

      test('emits snapshot after refresh', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);

        await repository.refresh();

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(1));
        expect(snapshot.items.first.isRead, isFalse);
      });

      test('watchUnreadCount derives from consolidated visible list', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 5);

        await repository.refresh();

        // Server reported 5, but the consolidated visible list has 1
        // unread item — watchUnreadCount returns the post-consolidation
        // count, not the server count.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test('markAsRead optimistically flips matching items', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final loadedId = repository.watchSnapshot().first.then(
          (s) => s.items.first.id,
        );
        final id = await loadedId;

        final counts = <int>[];
        final sub = repository.watchUnreadCount().listen(counts.add);

        await repository.markAsRead([id]);
        await sub.cancel();

        expect(counts.last, equals(0));
      });

      test('markAsRead rolls back snapshot when API throws', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final loadedId =
            (await repository.watchSnapshot().first).items.first.id;

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));

        await expectLater(
          repository.markAsRead([loadedId]),
          throwsA(isA<FunnelcakeException>()),
        );

        // Rollback restores the pre-write snapshot.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test(
        'markAsRead ignores a closed repository without mutating feeds',
        () async {
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();
          await repository.close();

          await repository.markAsRead(['n1']);

          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      test('markAsRead rollback preserves a newer refresh depth', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refresh();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        final loadedId =
            (await repository.watchSnapshot().first).items.first.id;
        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);

        final markFuture = repository.markAsRead([loadedId]);

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(markFuture, throwsA(isA<FunnelcakeException>()));

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('markAllAsRead posts when nothing is unread locally', () async {
        await repository.markAllAsRead();

        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
        verify(
          () => notificationsDao.markAllAsRead(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).called(1);
      });

      test(
        'markAllAsRead ignores a closed repository without mutating feeds',
        () async {
          stubNotifications([makeNotification()], unreadCount: 1);
          await repository.refresh();
          await repository.close();

          await repository.markAllAsRead();

          verifyNever(
            () => funnelcakeApiClient.markNotificationsRead(
              pubkey: any(named: 'pubkey'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      test('markAllAsRead does not emit when nothing flips', () async {
        stubNotifications([
          makeNotification(read: true),
        ]);
        await repository.refresh();

        final emissions = <NotificationPage>[];
        final subscription = repository.watchSnapshot().listen(emissions.add);
        addTearDown(subscription.cancel);
        await Future<void>.delayed(Duration.zero);
        emissions.clear();

        await repository.markAllAsRead();
        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);
        verify(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).called(1);
      });

      test('markAllAsRead optimistically zeros every unread item', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications([
          makeNotification(),
          makeNotification(
            id: 'n2',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_other',
          ),
        ], unreadCount: 2);
        await repository.refresh();
        expect(await repository.watchUnreadCount().first, equals(2));

        await repository.markAllAsRead();

        expect(await repository.watchUnreadCount().first, equals(0));
      });

      test('serializes overlapping read mutations so a failed rollback cannot '
          'undo a later success', () async {
        stubProfiles({});
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        final loadedId =
            (await repository.watchSnapshot().first).items.single.id;

        final firstGate = Completer<MarkReadResponse>();
        var attempt = 0;
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) {
          attempt += 1;
          return attempt == 1
              ? firstGate.future
              : Future.value(
                  const MarkReadResponse(success: true, markedCount: 1),
                );
        });

        final first = repository.markAsRead([loadedId]);
        final second = repository.markAsRead([loadedId]);
        firstGate.completeError(const FunnelcakeException('boom'));

        await expectLater(first, throwsA(isA<FunnelcakeException>()));
        await second;

        expect(attempt, equals(2));
        expect(await repository.watchUnreadCount().first, equals(0));
      });

      test('markAllAsRead rolls back when API throws', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();

        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenThrow(const FunnelcakeException('boom'));

        await expectLater(
          repository.markAllAsRead(),
          throwsA(isA<FunnelcakeException>()),
        );

        // Rollback restores the pre-write snapshot.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test('markAllAsRead rollback preserves a newer refresh depth', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refresh();
        stubNotifications(
          [
            makeNotification(
              id: 'n2',
              sourceEventId: 'evt2',
              referencedEventId: 'video_2',
            ),
          ],
          nextCursor: 'c2',
          hasMore: true,
        );
        await repository.loadNextPage();
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);

        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);

        final markFuture = repository.markAllAsRead();

        stubNotifications([
          makeNotification(
            id: 'fresh',
            sourceEventId: 'evt_fresh',
            referencedEventId: 'video_fresh',
          ),
        ]);
        await repository.refresh();
        expect(repository.hasPaginatedBeyondFirstPage, isFalse);

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(markFuture, throwsA(isA<FunnelcakeException>()));

        expect(repository.hasPaginatedBeyondFirstPage, isFalse);
      });

      test('markAllAsRead rollback keeps a page that landed mid-flight on a '
          'feed it never flipped', () async {
        stubProfiles({});
        stubNotifications([makeNotification()], unreadCount: 1);
        await repository.refresh();
        // The inbox mounts all five tabs, so the Follows feed is already live
        // when the POST starts — it just holds nothing to flip yet.
        stubNotifications([]);
        await repository.refreshFeed(NotificationKind.follow);

        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);
        final markFuture = repository.markAllAsRead();

        // The user swipes to Follows while the mark-read POST is in flight.
        stubNotifications([
          makeNotification(
            id: 'follow_1',
            sourcePubkey: 'pubkey_follower',
            sourceEventId: 'evt_follow_1',
            sourceKind: 3,
            notificationType: 'follow',
            referencedEventId: null,
          ),
        ]);
        await repository.refreshFeed(NotificationKind.follow);

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(markFuture, throwsA(isA<FunnelcakeException>()));

        final follows = await repository
            .watchSnapshot(filter: NotificationKind.follow)
            .first;
        expect(follows.items, hasLength(1));
        // The unfiltered feed was flipped, so it still rolls back.
        expect(await repository.watchUnreadCount().first, equals(1));
      });

      test('markAllAsRead rollback keeps a page that landed mid-flight on the '
          'same flipped feed', () async {
        stubProfiles({});
        stubNotifications(
          [makeNotification()],
          unreadCount: 1,
          nextCursor: 'c1',
          hasMore: true,
        );
        await repository.refresh();

        final markGate = Completer<MarkReadResponse>();
        when(
          () => funnelcakeApiClient.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer((_) => markGate.future);
        final markFuture = repository.markAllAsRead();

        stubNotifications([
          makeNotification(
            id: 'n2',
            sourceEventId: 'evt2',
            referencedEventId: 'video_2',
          ),
        ]);
        await repository.loadNextPage();

        markGate.completeError(const FunnelcakeException('boom'));
        await expectLater(markFuture, throwsA(isA<FunnelcakeException>()));

        final snapshot = await repository.watchSnapshot().first;
        expect(
          snapshot.items.map((item) => item.id),
          containsAll(['n1', 'n2']),
        );
        expect(
          snapshot.items.firstWhere((item) => item.id == 'n1').isRead,
          isFalse,
        );
        expect(repository.hasPaginatedBeyondFirstPage, isTrue);
      });
    });

    group('cross-page dedupe in page-merge (#4264)', () {
      // The server can deliver the same logical Nostr event as distinct
      // notification rows (different server UUIDs) across pagination
      // pages — e.g. Kind 3 republishes, cursor drift. When a later page
      // repeats an event already in the snapshot, dedupe must key on the
      // shared Nostr event id via `NotificationItem.sourceEventIds`, not
      // the rendered `id`, which can differ across deliveries.

      test('standalone $ActorNotification: a later page repeating the '
          'sourceEventId resolves to a single row', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
        });
        // First page seeds the snapshot and advances _lastCursor so the
        // next getNotifications() emits as a non-first page.
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-follow-0',
              sourceEventId: 'nostr-follow-evt-1',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        expect(
          (await repository.watchSnapshot().first).items,
          hasLength(1),
          reason: 'First page seeds the follow row.',
        );

        // Non-first REST page returns the same logical follow event
        // with the server UUID in id and the Nostr event id in
        // sourceEventId.
        stubNotifications([
          makeNotification(
            id: 'server-uuid-follow-1',
            sourceEventId: 'nostr-follow-evt-1',
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
            createdAt: DateTime(2025, 6),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(1),
          reason:
              'REST item with sourceEventId already represented by an '
              'existing row must not be appended as a duplicate.',
        );
        final actor = items.single as ActorNotification;
        expect(actor.sourceEventIds, contains('nostr-follow-evt-1'));
      });

      test(
        'grouped $VideoNotification: single-actor first-page row, then '
        'a later page with a multi-actor group on same '
        '(videoEventId, type) merges into the existing row in place',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
          });
          stubNotifications(
            [
              makeNotification(
                id: 'server-uuid-like-alice-p1',
                sourceEventId: 'nostr-like-alice',
                referencedEventId: 'video_a',
                createdAt: DateTime(2025, 5),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

          stubNotifications([
            makeNotification(
              id: 'server-uuid-like-alice',
              sourceEventId: 'nostr-like-alice',
              referencedEventId: 'video_a',
              createdAt: DateTime(2025, 5),
            ),
            makeNotification(
              id: 'server-uuid-like-bob',
              sourceEventId: 'nostr-like-bob',
              sourcePubkey: 'pubkey_bob',
              referencedEventId: 'video_a',
              createdAt: DateTime(2025, 5, 2),
            ),
            makeNotification(
              id: 'server-uuid-like-carol',
              sourceEventId: 'nostr-like-carol',
              sourcePubkey: 'pubkey_carol',
              referencedEventId: 'video_a',
              createdAt: DateTime(2025, 5, 3),
            ),
          ]);

          await repository.getNotifications();

          final items = (await repository.watchSnapshot().first).items;
          expect(
            items,
            hasLength(1),
            reason:
                'REST group on same (videoEventId, type) must merge into '
                'the existing row instead of producing a second row.',
          );
          final merged = items.single as VideoNotification;
          expect(merged.videoEventId, equals('video_a'));
          expect(merged.type, equals(NotificationKind.like));
          expect(
            merged.sourceEventIds,
            containsAll(<String>[
              'nostr-like-alice',
              'nostr-like-bob',
              'nostr-like-carol',
            ]),
          );
          expect(merged.totalCount, equals(3));
          expect(
            merged.actors,
            hasLength(3),
            reason: 'Actor stack fills up to _maxGroupActors after merge.',
          );
          expect(
            merged.actors.first.pubkey,
            equals('pubkey_alice'),
            reason:
                'Existing-side actors retain their leading position so '
                'the row does not visibly jump.',
          );
        },
      );

      test('unrelated REST event on a different video is appended; no '
          'false-positive dedupe', () async {
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-like-alice-video-a',
              sourceEventId: 'nostr-like-alice-video-a',
              referencedEventId: 'video_a',
              createdAt: DateTime(2025, 5),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        stubNotifications([
          makeNotification(
            id: 'server-uuid-like-bob-video-b',
            sourceEventId: 'nostr-like-bob-video-b',
            sourcePubkey: 'pubkey_bob',
            referencedEventId: 'video_b',
            createdAt: DateTime(2025, 5, 2),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(
          items,
          hasLength(2),
          reason:
              'Disjoint sourceEventIds and disjoint (videoEventId, type) '
              'must not trigger dedupe — both rows visible.',
        );
      });

      test(
        'mixed page: same logical event deduped, new events appended',
        () async {
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
            'pubkey_carol': makeProfile('pubkey_carol', displayName: 'Carol'),
          });
          stubNotifications(
            [
              makeNotification(
                id: 'server-uuid-follow-alice-p1',
                sourceEventId: 'nostr-follow-alice',
                notificationType: 'follow',
                sourceKind: 3,
                referencedEventId: null,
                isReferencedVideo: false,
                createdAt: DateTime(2025, 5),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

          // Non-first REST page includes:
          //  - the same follow event (must be deduped),
          //  - a new follow from Bob (must be appended),
          //  - a new like from Carol on a video (must be appended).
          stubNotifications([
            makeNotification(
              id: 'server-uuid-follow-alice',
              sourceEventId: 'nostr-follow-alice',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 5),
            ),
            makeNotification(
              id: 'server-uuid-follow-bob',
              sourceEventId: 'nostr-follow-bob',
              sourcePubkey: 'pubkey_bob',
              notificationType: 'follow',
              sourceKind: 3,
              referencedEventId: null,
              isReferencedVideo: false,
              createdAt: DateTime(2025, 4),
            ),
            makeNotification(
              id: 'server-uuid-like-carol',
              sourceEventId: 'nostr-like-carol',
              sourcePubkey: 'pubkey_carol',
              referencedEventId: 'video_x',
              createdAt: DateTime(2025, 4, 5),
            ),
          ]);

          await repository.getNotifications();

          final items = (await repository.watchSnapshot().first).items;
          expect(
            items,
            hasLength(3),
            reason:
                'Duplicate Nostr event is dropped; the two new events '
                'are appended.',
          );
          final allSourceIds = items.expand((n) => n.sourceEventIds).toSet();
          expect(
            allSourceIds,
            containsAll(<String>[
              'nostr-follow-alice',
              'nostr-follow-bob',
              'nostr-like-carol',
            ]),
          );
        },
      );

      test("comment-kind merge keeps the newer side's commentText "
          '(existing row newer than incoming page)', () async {
        // Production ordering: REST pagination walks backward in time,
        // so an incoming page on the same (videoEventId, kind) is
        // typically OLDER than the row already in the snapshot. The
        // merged row must therefore keep the existing commentText —
        // mirrors `_groupVideoAnchored`'s sort-desc + group.first
        // newest-wins and the surrounding `timestamp = max(...)`.
        stubProfiles({
          'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
          'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
        });
        // First page carries the NEWER comment.
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-comment-alice',
              sourceEventId: 'nostr-comment-alice',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_a',
              content: 'Newer comment from Alice (first page)',
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        // REST pagination returns an OLDER comment on the same video.
        stubNotifications([
          makeNotification(
            id: 'server-uuid-comment-bob',
            sourceEventId: 'nostr-comment-bob',
            sourcePubkey: 'pubkey_bob',
            notificationType: 'comment',
            sourceKind: 1,
            referencedEventId: 'video_a',
            content: 'Older comment from Bob (REST-paged)',
            createdAt: DateTime(2025, 4),
          ),
        ]);

        await repository.getNotifications();

        final items = (await repository.watchSnapshot().first).items;
        expect(items, hasLength(1));
        final merged = items.single as VideoNotification;
        expect(merged.type, equals(NotificationKind.comment));
        expect(
          merged.commentText,
          equals('Newer comment from Alice (first page)'),
          reason:
              'Newer side wins to mirror _groupVideoAnchored sort-desc '
              'semantics and align with timestamp=max(...). Older REST '
              'commentText must NOT overwrite the displayed newest one.',
        );
        expect(
          merged.timestamp,
          equals(DateTime(2025, 6)),
          reason: 'timestamp must be the max of the two sides.',
        );
      });

      test('pagination merge keeps the named actor in front when the existing '
          'row is unnamed', () async {
        const hashPubkey =
            '2949ede154d1f121402761cbd73f2b8c490b5041'
            'cdd85c9908c5322f1a2fe3f6';
        stubProfiles({
          hashPubkey: makeProfile(hashPubkey, displayName: hashPubkey),
          'pub_named': makeProfile(
            'pub_named',
            displayName: 'Sally Strawberry',
          ),
        });
        stubNotifications(
          [
            makeNotification(
              id: 'server-uuid-unnamed',
              sourceEventId: 'nostr-unnamed',
              sourcePubkey: hashPubkey,
              referencedEventId: 'video_named',
              createdAt: DateTime(2025, 6),
            ),
          ],
          nextCursor: 'cursor_after_first',
          hasMore: true,
        );
        await repository.refresh();

        stubNotifications([
          makeNotification(
            id: 'server-uuid-named',
            sourceEventId: 'nostr-named',
            sourcePubkey: 'pub_named',
            referencedEventId: 'video_named',
            createdAt: DateTime(2025, 4),
          ),
        ]);

        await repository.getNotifications();

        final merged =
            (await repository.watchSnapshot().first).items.single
                as VideoNotification;
        expect(merged.totalCount, equals(2));
        expect(merged.actors.first.pubkey, equals('pub_named'));
        expect(merged.actors.first.displayName, equals('Sally Strawberry'));
      });

      test(
        "comment-kind merge keeps the newer side's commentText "
        '(incoming page newer than existing row) — symmetric direction',
        () async {
          // Symmetric case: rare in production (the first page is the
          // newer boundary), but the rule must be timestamp-driven, not
          // delivery-order-driven. Lock both directions.
          stubProfiles({
            'pubkey_alice': makeProfile('pubkey_alice', displayName: 'Alice'),
            'pubkey_bob': makeProfile('pubkey_bob', displayName: 'Bob'),
          });
          stubNotifications(
            [
              makeNotification(
                id: 'server-uuid-comment-alice',
                sourceEventId: 'nostr-comment-alice',
                notificationType: 'comment',
                sourceKind: 1,
                referencedEventId: 'video_a',
                content: 'Older comment from Alice (first page)',
                createdAt: DateTime(2025, 4),
              ),
            ],
            nextCursor: 'cursor_after_first',
            hasMore: true,
          );
          await repository.refresh();

          stubNotifications([
            makeNotification(
              id: 'server-uuid-comment-bob',
              sourceEventId: 'nostr-comment-bob',
              sourcePubkey: 'pubkey_bob',
              notificationType: 'comment',
              sourceKind: 1,
              referencedEventId: 'video_a',
              content: 'Newer comment from Bob (REST-paged)',
              createdAt: DateTime(2025, 6),
            ),
          ]);

          await repository.getNotifications();

          final items = (await repository.watchSnapshot().first).items;
          expect(items, hasLength(1));
          final merged = items.single as VideoNotification;
          expect(
            merged.commentText,
            equals('Newer comment from Bob (REST-paged)'),
            reason:
                'When the REST side carries the newer createdAt, its '
                'commentText wins — rule is timestamp-driven, not '
                'path-driven.',
          );
          expect(merged.timestamp, equals(DateTime(2025, 6)));
        },
      );
    });
  });
}
