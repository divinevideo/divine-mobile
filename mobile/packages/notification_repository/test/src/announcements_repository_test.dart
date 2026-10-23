import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notification_repository/announcements_repository.dart';
import 'package:test/test.dart';

const firstId = '12345678-1234-4123-8123-123456789012';
const secondId = '22345678-1234-4123-8123-123456789012';

Map<String, Object?> announcement({
  String id = firstId,
  String publishedAt = '2026-10-22T00:00:00.000Z',
  String expiresAt = '2026-11-22T00:00:00.000Z',
  List<String> platforms = const [],
  String? minimumAppVersion,
  String? learnMoreUrl,
}) => {
  'id': id,
  'title': ' A little news ',
  'body': ' Hello from Divine ',
  'publishedAt': publishedAt,
  'expiresAt': expiresAt,
  'platforms': platforms,
  'minimumAppVersion': minimumAppVersion,
  'learnMoreUrl': learnMoreUrl,
};

String catalog([List<Map<String, Object?>>? items]) => jsonEncode({
  'schemaVersion': 1,
  'announcements': items ?? [announcement()],
});

http.Response jsonResponse(String body, {Map<String, String>? headers}) =>
    http.Response(
      body,
      200,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

void main() {
  late MemoryStore store;
  late DateTime now;
  late AnnouncementsRepository repository;

  AnnouncementsRepository create(
    http.Client client, {
    String platform = 'ios',
    String appVersion = '1.2.3',
    Clock? clock,
    Duration requestTimeout = const Duration(seconds: 10),
  }) => repository = AnnouncementsRepository(
    httpClient: client,
    store: store,
    platform: platform,
    appVersion: appVersion,
    clock: clock ?? Clock(() => now),
    requestTimeout: requestTimeout,
  );

  setUp(() {
    store = MemoryStore();
    now = DateTime.utc(2026, 10, 23);
  });
  tearDown(() async => repository.close());

  group('initialize, refresh, markSeen, and close', () {
    test('accepts the shared Worker catalog fixture', () async {
      final fixture = File.fromUri(
        Directory.current.uri.resolve(
          Directory.current.path.endsWith('notification_repository')
              ? 'test/fixtures/announcements-v1.json'
              : 'packages/notification_repository/test/fixtures/announcements-v1.json',
        ),
      ).readAsStringSync();
      create(MockClient((_) async => jsonResponse(fixture)));
      await repository.refresh();
      expect(repository.items.single.title, 'A little news from Divine');
      expect(
        repository.items.single.learnMoreUrl,
        Uri.parse('https://divine.video/'),
      );
    });

    test('starts empty and initialize does not fetch', () async {
      var requests = 0;
      create(
        MockClient((_) async {
          requests++;
          return jsonResponse(catalog());
        }),
      );
      expect(await repository.watchSnapshot().first, isEmpty);
      await repository.initialize();
      expect(repository.items, isEmpty);
      expect(requests, 0);
    });

    test('fetches only the fixed public source without credentials', () async {
      create(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://announcements.divine.video/v1/announcements',
          );
          expect(request.followRedirects, isFalse);
          expect(request.headers.keys, isNot(contains('authorization')));
          expect(request.headers.keys, isNot(contains('cookie')));
          return jsonResponse(catalog());
        }),
      );
      await repository.refresh();
      expect(repository.items.single.title, 'A little news');
      expect(repository.items.single.body, 'Hello from Divine');
      expect(repository.items.single.id, 'announcement:$firstId');
      expect(() => repository.items.clear(), throwsUnsupportedError);
    });

    test(
      'hydrates a persisted catalog and account seen state without a fetch',
      () async {
        create(MockClient((_) async => jsonResponse(catalog())));
        await repository.refresh();
        await repository.markSeen(['announcement:$firstId']);
        await repository.close();
        create(MockClient((_) async => throw Exception('offline')));
        await repository.initialize();
        expect(repository.items.single.isRead, isTrue);
      },
    );

    test('uses ETag and keeps valid cache for 304', () async {
      var requests = 0;
      create(
        MockClient((request) async {
          requests++;
          if (requests == 1) {
            return jsonResponse(catalog(), headers: {'etag': '"one"'});
          }
          expect(request.headers['if-none-match'], '"one"');
          return http.Response('', 304);
        }),
      );
      await repository.refresh();
      await repository.refresh();
      expect(repository.items, hasLength(1));
      expect(requests, 2);
    });

    test('304 without valid cache never manufactures a catalog', () async {
      store.catalogValue = '{bad cache';
      create(
        MockClient((request) async {
          expect(request.headers['if-none-match'], isNull);
          return http.Response('', 304);
        }),
      );
      await repository.refresh();
      expect(repository.items, isEmpty);
      expect(store.catalogWrites, 0);
    });

    test(
      'filters platform, semantic version, future dates and expiry',
      () async {
        create(
          MockClient(
            (_) async => jsonResponse(
              catalog([
                announcement(),
                announcement(id: secondId, platforms: ['android']),
                announcement(
                  id: '32345678-1234-4123-8123-123456789012',
                  minimumAppVersion: '1.10.0',
                ),
                announcement(
                  id: '42345678-1234-4123-8123-123456789012',
                  publishedAt: '2026-10-24T00:00:00.000Z',
                ),
                announcement(
                  id: '52345678-1234-4123-8123-123456789012',
                  expiresAt: '2026-10-23T00:00:00.000Z',
                ),
              ]),
            ),
          ),
        );
        await repository.refresh();
        expect(repository.items.map((item) => item.announcementId), [firstId]);
        now = DateTime.utc(2026, 10, 24);
        expect(repository.items, hasLength(2));
        now = DateTime.utc(2026, 11, 23);
        expect(repository.items, isEmpty);
      },
    );

    test(
      'invalid current version fails closed only for version-targeted items',
      () async {
        create(
          MockClient(
            (_) async => jsonResponse(
              catalog([
                announcement(),
                announcement(id: secondId, minimumAppVersion: '1.0.0'),
              ]),
            ),
          ),
          appVersion: 'unknown',
        );
        await repository.refresh();
        expect(repository.items.map((item) => item.announcementId), [firstId]);
      },
    );

    final invalidItems = <String, Map<String, Object?>>{
      'non UUID': {...announcement(), 'id': 'social-id'},
      'blank title': {...announcement(), 'title': '  '},
      'long title': {...announcement(), 'title': 'x' * 121},
      'blank body': {...announcement(), 'body': ''},
      'long body': {...announcement(), 'body': 'x' * 8001},
      'bad date': {...announcement(), 'publishedAt': '2026-02-30T00:00:00Z'},
      'non UTC date': {...announcement(), 'publishedAt': '2026-10-22T00:00:00'},
      'unbounded date': {
        ...announcement(),
        'publishedAt': '0001-01-01T00:00:00Z',
      },
      'backwards expiry': {
        ...announcement(),
        'expiresAt': '2026-10-21T00:00:00Z',
      },
      'unknown platform': {
        ...announcement(),
        'platforms': ['plan9'],
      },
      'duplicate platform': {
        ...announcement(),
        'platforms': ['ios', 'ios'],
      },
      'missing platforms': {...announcement()}..remove('platforms'),
      'bad version': {...announcement(), 'minimumAppVersion': '1.0'},
      'prerelease version': {
        ...announcement(),
        'minimumAppVersion': '1.0.0-beta',
      },
      'external URL': {
        ...announcement(),
        'learnMoreUrl': 'https://example.com',
      },
      'lookalike URL': {
        ...announcement(),
        'learnMoreUrl': 'https://divine.video.evil.test',
      },
      'userinfo URL': {
        ...announcement(),
        'learnMoreUrl': 'https://x@divine.video',
      },
      'HTTP URL': {...announcement(), 'learnMoreUrl': 'http://divine.video'},
      'port URL': {
        ...announcement(),
        'learnMoreUrl': 'https://divine.video:8443',
      },
      'admin URL': {
        ...announcement(),
        'learnMoreUrl': 'https://engagement.admin.divine.video',
      },
    };
    for (final entry in invalidItems.entries) {
      test('rejects ${entry.key} as a complete failed snapshot', () async {
        var first = true;
        create(
          MockClient((_) async {
            if (first) {
              first = false;
              return jsonResponse(catalog());
            }
            return jsonResponse(catalog([entry.value]));
          }),
        );
        await repository.refresh();
        final cached = store.catalogValue;
        await repository.refresh();
        expect(repository.items.single.announcementId, firstId);
        expect(store.catalogValue, cached);
      });
    }

    test(
      'rejects unknown schema, duplicate IDs and catalogs over 50 items',
      () async {
        final responses = [
          catalog(),
          jsonEncode({'schemaVersion': 2, 'announcements': <Object?>[]}),
          catalog([announcement(), announcement()]),
          catalog(List.generate(51, (_) => announcement())),
          '<html>Log in</html>',
        ];
        create(MockClient((_) async => jsonResponse(responses.removeAt(0))));
        await repository.refresh();
        for (var i = 0; i < 4; i++) {
          await repository.refresh();
          expect(repository.items.single.announcementId, firstId);
        }
        expect(store.catalogWrites, 1);
      },
    );

    test('permits only exact first-party learn-more hosts', () async {
      create(
        MockClient(
          (_) async => jsonResponse(
            catalog([
              announcement(learnMoreUrl: 'https://divine.video:443/news'),
              announcement(
                id: secondId,
                learnMoreUrl: 'https://about.divine.video/a',
              ),
            ]),
          ),
        ),
      );
      await repository.refresh();
      expect(repository.items, hasLength(2));
    });

    test(
      'retains cache for HTML content type, redirect and server failure',
      () async {
        final responses = [
          jsonResponse(catalog()),
          http.Response(
            catalog([]),
            200,
            headers: {'content-type': 'text/html'},
          ),
          http.Response('', 302, headers: {'location': 'https://example.com'}),
          http.Response('', 500),
        ];
        create(MockClient((_) async => responses.removeAt(0)));
        await repository.refresh();
        for (var i = 0; i < 3; i++) {
          await repository.refresh();
          expect(repository.items, hasLength(1));
        }
      },
    );

    test(
      'successful empty catalog withdraws old rows and prunes seen IDs',
      () async {
        var first = true;
        create(
          MockClient((_) async {
            final result = catalog(first ? [announcement()] : []);
            first = false;
            return jsonResponse(result);
          }),
        );
        await repository.refresh();
        await repository.markSeen(['announcement:$firstId', 'social-id']);
        await repository.refresh();
        expect(repository.items, isEmpty);
        expect(store.seen, isEmpty);
      },
    );

    test(
      'markSeen marks only captured IDs, preserving a newer arrival',
      () async {
        var first = true;
        create(
          MockClient((_) async {
            final result = catalog([
              announcement(),
              if (!first) announcement(id: secondId),
            ]);
            first = false;
            return jsonResponse(result);
          }),
        );
        await repository.refresh();
        final capturedIds = repository.items.map((item) => item.id).toList();
        await repository.refresh();
        await repository.markSeen(capturedIds);
        expect(
          repository.items
              .singleWhere((item) => item.announcementId == firstId)
              .isRead,
          isTrue,
        );
        expect(
          repository.items
              .singleWhere((item) => item.announcementId == secondId)
              .isRead,
          isFalse,
        );
        await repository.refresh();
        expect(
          repository.items
              .singleWhere((item) => item.announcementId == firstId)
              .isRead,
          isTrue,
        );
      },
    );

    test('cache and seen read failures still allow network refresh', () async {
      store.failReads = true;
      create(MockClient((_) async => jsonResponse(catalog())));
      await repository.refresh();
      expect(repository.items, hasLength(1));
    });

    test('storage failures do not drop fetched or locally seen rows', () async {
      store.failWrites = true;
      create(MockClient((_) async => jsonResponse(catalog())));
      await repository.refresh();
      await repository.markSeen(['announcement:$firstId']);
      expect(repository.items.single.isRead, isTrue);
    });

    test('preserves seen IDs when the catalog cache is unreadable', () async {
      store
        ..catalogValue = '{bad cache'
        ..seen = ['announcement:$firstId'];
      create(MockClient((_) async => jsonResponse(catalog())));
      await repository.initialize();
      await repository.refresh();
      expect(repository.items.single.isRead, isTrue);
      expect(store.seen, ['announcement:$firstId']);
    });

    test(
      'replayed snapshots update at publication and expiry without a fetch',
      () {
        fakeAsync((async) {
          final snapshots = <List<String>>[];
          var requests = 0;
          create(
            MockClient((_) async {
              requests++;
              return jsonResponse(
                catalog([
                  announcement(expiresAt: '2026-10-23T12:00:00Z'),
                  announcement(
                    id: secondId,
                    publishedAt: '2026-10-23T12:00:00Z',
                    expiresAt: '2026-10-24T00:00:00Z',
                  ),
                ]),
              );
            }),
            clock: async.getClock(now),
          );
          final subscription = repository.watchSnapshot().listen((items) {
            snapshots.add(items.map((item) => item.announcementId).toList());
          });
          try {
            unawaited(repository.refresh());
            async.flushMicrotasks();
            expect(snapshots.last, [firstId]);
            async.elapse(const Duration(hours: 12));
            expect(snapshots.last, [secondId]);
            final replayed = <List<String>>[];
            final replay = repository.watchSnapshot().listen((items) {
              replayed.add(items.map((item) => item.announcementId).toList());
            });
            async.flushMicrotasks();
            expect(replayed.single, [secondId]);
            unawaited(replay.cancel());
            async.elapse(const Duration(hours: 12));
            expect(snapshots.last, isEmpty);
            expect(requests, 1);
          } finally {
            unawaited(subscription.cancel());
            unawaited(repository.close());
            async.flushMicrotasks();
          }
          expect(async.nonPeriodicTimerCount, 0);
        });
      },
    );

    test('close cancels eligibility timers', () {
      fakeAsync((async) {
        create(
          MockClient((_) async => jsonResponse(catalog())),
          clock: async.getClock(now),
        );
        try {
          unawaited(repository.refresh());
          async.flushMicrotasks();
          expect(async.nonPeriodicTimerCount, 1);
        } finally {
          final firstClose = repository.close();
          expect(identical(firstClose, repository.close()), isTrue);
          async.flushMicrotasks();
        }
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    for (final lifetime in [30, 90]) {
      test('bounds timer waits for a $lifetime-day announcement', () {
        fakeAsync((async) {
          final expires = now.add(Duration(days: lifetime));
          final snapshots = <List<String>>[];
          var requests = 0;
          create(
            MockClient((_) async {
              requests++;
              return jsonResponse(
                catalog([
                  announcement(
                    publishedAt: now.toIso8601String(),
                    expiresAt: expires.toIso8601String(),
                  ),
                ]),
              );
            }),
            clock: async.getClock(now),
          );
          final subscription = repository.watchSnapshot().listen((items) {
            snapshots.add(items.map((item) => item.announcementId).toList());
          });
          try {
            unawaited(repository.refresh());
            async.flushMicrotasks();
            expect(snapshots.last, [firstId]);
            for (var day = 0; day < lifetime - 1; day++) {
              expect(
                async.pendingTimers.single.duration,
                lessThanOrEqualTo(const Duration(days: 1)),
              );
              async.elapse(const Duration(days: 1));
              expect(snapshots.last, [firstId]);
            }
            async.elapse(const Duration(days: 1) - const Duration(seconds: 1));
            expect(snapshots.last, [firstId]);
            async.elapse(const Duration(seconds: 1));
            expect(snapshots.last, isEmpty);
            expect(async.pendingTimers, isEmpty);
            expect(requests, 1);
          } finally {
            unawaited(subscription.cancel());
            unawaited(repository.close());
            async.flushMicrotasks();
          }
        });
      });
    }

    test('coalesces concurrent refreshes', () async {
      final response = Completer<http.Response>();
      var requests = 0;
      create(
        MockClient((_) {
          requests++;
          return response.future;
        }),
      );
      final first = repository.refresh();
      final second = repository.refresh();
      await Future<void>.delayed(Duration.zero);
      response.complete(jsonResponse(catalog()));
      await Future.wait([first, second]);
      expect(requests, 1);
    });

    test('close discards a late fetch and never persists it', () async {
      final response = Completer<http.Response>();
      create(MockClient((_) => response.future));
      final refresh = repository.refresh();
      await Future<void>.delayed(Duration.zero);
      await repository.close();
      response.complete(jsonResponse(catalog()));
      await refresh;
      expect(repository.items, isEmpty);
      expect(store.catalogWrites, 0);
      await repository.markSeen(['announcement:$firstId']);
      await repository.close();
      expect(store.seenWrites, 0);
    });

    test(
      'close drains serialized persistence before account cleanup',
      () async {
        create(MockClient((_) async => jsonResponse(catalog())));
        await repository.refresh();
        final firstWrite = Completer<void>();
        store.writeBlock = firstWrite;
        final mark = repository.markSeen(['announcement:$firstId']);
        await Future<void>.delayed(Duration.zero);
        var closed = false;
        final close = repository.close().then((_) => closed = true);
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        firstWrite.complete();
        await Future.wait([mark, close]);
        expect(store.seen, ['announcement:$firstId']);
        expect(closed, isTrue);
      },
    );

    test('rejects streamed bodies above the byte limit', () async {
      create(
        StreamClient(
          (_) async => http.StreamedResponse(
            Stream.value(List.filled(512 * 1024 + 1, 32)),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await repository.refresh();
      expect(repository.items, isEmpty);
      expect(store.catalogWrites, 0);
    });

    test('bounds total time including a stalled response body', () async {
      final body = StreamController<List<int>>();
      create(
        StreamClient(
          (_) async => http.StreamedResponse(
            body.stream,
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        requestTimeout: const Duration(milliseconds: 20),
      );
      await repository.refresh().timeout(const Duration(seconds: 2));
      expect(repository.items, isEmpty);
      expect(store.catalogWrites, 0);
      await body.close();
    });
  });
}

class MemoryStore implements AnnouncementStore {
  String? catalogValue;
  List<String> seen = [];
  int catalogWrites = 0;
  int seenWrites = 0;
  bool failReads = false;
  bool failWrites = false;
  Completer<void>? writeBlock;

  @override
  Future<String?> readCatalog() async {
    if (failReads) throw Exception('read failed');
    return catalogValue;
  }

  @override
  Future<List<String>> readSeen() async {
    if (failReads) throw Exception('read failed');
    return List.of(seen);
  }

  @override
  Future<void> writeCatalog(String value) async {
    await writeBlock?.future;
    if (failWrites) throw Exception('write failed');
    catalogWrites++;
    catalogValue = value;
  }

  @override
  Future<void> writeSeen(List<String> ids) async {
    await writeBlock?.future;
    if (failWrites) throw Exception('write failed');
    seenWrites++;
    seen = List.of(ids);
  }
}

class StreamClient extends http.BaseClient {
  StreamClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
