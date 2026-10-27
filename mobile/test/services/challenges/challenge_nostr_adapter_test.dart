import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:challenge_protocol/challenge_protocol.dart' as protocol;
import 'package:challenges_repository/challenges_repository.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/challenges/challenge_nostr_adapter.dart';

import 'package:openvine/services/challenges/challenge_video_policy.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';

class _Media extends Mock implements MediaAvailabilityChecker {}

class _Moderation extends Mock implements VideoModerationStatusService {}

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  group('actual challenge relay wire', () {
    test(
      'reopened SQLite body is sent exactly and ACK maps to original target',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final directory = await Directory.systemTemp.createTemp(
          'challenge-wire-',
        );
        final file = File('${directory.path}/app.sqlite');
        var db = AppDatabase.test(NativeDatabase(file));
        final servers = [
          for (var i = 0; i < 3; i++)
            await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        ];
        final server = servers.first;
        final sockets = <WebSocket>[];
        final frames = <String>[];
        final requests = <Map<String, dynamic>>[];
        var replies = <Event>[];
        for (final listener in servers) {
          listener.listen((request) async {
            if (!WebSocketTransformer.isUpgradeRequest(request)) {
              request.response.statusCode = HttpStatus.notFound;
              await request.response.close();
              return;
            }
            final socket = await WebSocketTransformer.upgrade(request);
            sockets.add(socket);
            socket.listen((raw) {
              final message = jsonDecode(raw as String) as List<dynamic>;
              if (message.first == 'EVENT') {
                frames.add(raw);
                socket.add(
                  jsonEncode([
                    'OK',
                    (message[1] as Map<String, dynamic>)['id'],
                    true,
                    '',
                  ]),
                );
              } else if (message.first == 'REQ') {
                requests.add(message[2] as Map<String, dynamic>);
                for (final event in replies) {
                  if ((requests.last['kinds'] as List<dynamic>).contains(
                    event.kind,
                  )) {
                    socket.add(
                      jsonEncode(['EVENT', message[1], event.toJson()]),
                    );
                  }
                }
                socket.add(jsonEncode(['EOSE', message[1]]));
              }
            });
          });
        }
        final random = Random.secure();
        final key = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        final signer = LocalNostrSigner(key);
        final owner = (await signer.getPublicKey())!;
        final relay = 'ws://127.0.0.1:${server.port}';
        final organizer = SyntheticSigner();
        final definition =
            protocol
                    .parseChallengeEvent(organizer.definition(relay: '$relay/'))
                    .value!
                as protocol.ChallengeDefinition;
        final video = (await signer.signEvent(
          Event(
            owner,
            34236,
            [
              ['d', 'synthetic-video'],
              [
                'imeta',
                'url https://media.example.test/video.mp4',
                'm video/mp4',
                'x ${'a' * 64}',
              ],
            ],
            'Synthetic video',
            createdAt: 140,
          ),
        ))!;
        final fields = protocol.buildEntry(
          definition,
          protocol.NostrEvent.fromJson(video.toJson()),
          150,
        );
        final event = (await signer.signEvent(
          Event(
            owner,
            fields.kind,
            [
              ...fields.tags,
              ['client', 'Synthetic Divine client'],
            ],
            fields.content,
            createdAt: fields.createdAt,
          ),
        ))!;
        expect(
          protocol.parseChallengeEvent(event.toJson()).value,
          isA<protocol.ChallengeEntry>(),
        );
        final body = jsonEncode(event.toJson());
        final generation = await db.challengeRecordsDao.openOwner(owner);
        await db.challengeRecordsDao.put(
          owner,
          generation,
          'action',
          event.id,
          body,
          signedBody: body,
        );
        await db.close();
        db = AppDatabase.test(NativeDatabase(file));
        final saved = (await db.challengeRecordsDao.read(
          owner,
          generation,
          'action',
        )).single.signedBody!;
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: RelayManager(
            config: RelayManagerConfig(
              defaultRelayUrl: relay,
              allowedRelayHost: '127.0.0.1',
            ),
            relayPool: nostr.relayPool,
          ),
        );
        addTearDown(() async {
          await client.dispose();
          for (final socket in sockets) {
            await socket.close();
          }
          for (final listener in servers) {
            await listener.close(force: true);
          }
          await db.close();
          await directory.delete(recursive: true);
        });
        await client.initialize();
        final adapter = ChallengeNostrAdapter(
          client: client,
          knownRelays: () => client.configuredRelays,
          checkOwner: () =>
              db.challengeRecordsDao.checkOwner(owner, generation),
          timeout: const Duration(seconds: 2),
        );
        final targets = ['$relay/', 'wss://blocked.example.test'];
        final result = await adapter.publish(saved, targets);
        expect(result['$relay/'], RelayOutcome.accepted);
        expect(result['wss://blocked.example.test'], RelayOutcome.unreachable);
        expect(frames, ['["EVENT",$body]']);
        expect(client.writableRelays, contains(relay));
        nostr.getRelay(relay)!.relayStatus.writeAccess = false;
        expect(client.writableRelays, isEmpty);
        nostr.getRelay(relay)!.relayStatus.writeAccess = true;
        await adapter.publish(saved, targets);
        expect(frames, ['["EVENT",$body]', '["EVENT",$body]']);
        final before = frames.length;
        await adapter.publish(saved, ['wss://blocked.example.test']);
        expect(
          frames.length,
          before,
          reason: 'All-filtered explicit targets must not fall back to the connected pool',
        );
        replies = [
          for (var i = 0; i < 3; i++)
            (await signer.signEvent(Event(owner, 1, [], 'bounded $i')))!,
        ];
        for (final byteBudget in [false, true]) {
          final bounded = await client.readEvents(
            [
              Filter(kinds: [1], limit: 10),
            ],
            tempRelays: [relay],
            relayTypes: const [RelayType.temp],
            useCache: false,
            requireAllRelaysSettled: true,
            maxCollectedEvents: byteBudget ? 10 : 1,
            maxCollectedBytes: byteBudget
                ? utf8.encode(jsonEncode(replies.first.toJson())).length
                : 4096,
          );
          expect(bounded.events, hasLength(1));
          expect(bounded.possiblyCapped, isTrue);
          expect(bounded.confirmedExhaustive, isFalse);
        }
        for (final replica in servers.skip(1)) {
          expect(
            await client.addRelay('ws://127.0.0.1:${replica.port}'),
            isTrue,
          );
        }
        replies = [video];
        final media = _Media();
        final moderation = _Moderation();
        when(() => media.isConfirmedAvailable(any()))
            .thenAnswer((_) async => true);
        when(() => moderation.fetchStatus(any())).thenAnswer(
          (_) async => const VideoModerationStatus(
            moderated: true,
            blocked: false,
            quarantined: false,
            ageRestricted: false,
            needsReview: false,
            aiGenerated: false,
          ),
        );
        final policy = ChallengeVideoPolicy(
          client: client,
          moderation: moderation,
          media: media,
          checkOwner: () async {},
          sourceAllowed: (_) => true,
        );
        final verifiedVideo = protocol.NostrEvent.fromJson(video.toJson());
        await policy.refresh(verifiedVideo);
        expect(policy.currentVideoId(verifiedVideo), video.id);
        expect(policy.isVisible(verifiedVideo), isTrue);
        replies = [
          (await signer.signEvent(
            Event(owner, 31923, [
              ['d', 'synthetic:challenge'],
            ], 'Unmarked latest rules'),
          ))!,
        ];
        final read = await adapter.read('31923:$owner:synthetic:challenge');
        expect(read.completeness, ReadCompleteness.partial);
        expect(read.revisionsComplete, isTrue);
        expect(read.records, hasLength(1));
        final definitionFilter = requests.lastWhere(
          (filter) => (filter['kinds'] as List<dynamic>).contains(31923),
        );
        expect(definitionFilter['authors'], [owner]);
        expect(definitionFilter['#d'], ['synthetic:challenge']);
        expect(definitionFilter.containsKey('#t'), isFalse);
        expect(requests.last['#A'], ['31923:$owner:synthetic:challenge']);
        expect(requests.last.containsKey('#a'), isFalse);
        replies = [
          for (var i = 0; i < 22; i++)
            (await signer.signEvent(
              Event(owner, 31923, [
                ['d', 'synthetic:challenge'],
              ], 'Replicated revision $i'),
            ))!,
        ];
        final replicated = await adapter.read(
          '31923:$owner:synthetic:challenge',
        );
        expect(replicated.records, hasLength(22));
        expect(replicated.revisionsComplete, isTrue);
        expect(replicated.retentionLimited, isFalse);
        replies = [
          for (var i = 0; i < 65; i++)
            (await signer.signEvent(
              Event(owner, 31923, [
                ['d', 'synthetic:challenge'],
              ], 'Overproducing revision $i'),
            ))!,
        ];
        final capped = await adapter.read('31923:$owner:synthetic:challenge');
        expect(capped.records.length, lessThanOrEqualTo(64));
        expect(capped.revisionsComplete, isFalse);
        expect(capped.completeness, ReadCompleteness.partial);
      }, _LoopbackHttpOverrides()),
    );
  });
}
