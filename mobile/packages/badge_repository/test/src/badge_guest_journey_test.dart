@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('public badge reads with no account relays', () {
    test(
      'discovers a badge and opens its accepted holders on the primary relay',
      () async {
        final issuerKey = '1'.padLeft(64, '0');
        final memberKey = '2'.padLeft(64, '0');
        final issuer = getPublicKey(issuerKey);
        final member = getPublicKey(memberKey);
        final coordinate = BadgeCoordinate(
          pubkey: issuer,
          identifier: 'shared',
        );
        final badge = Event(issuer, EventKind.badgeDefinition, [
          ['d', coordinate.identifier],
          ['name', 'Loop makers'],
        ], '')..sign(issuerKey);
        final award = Event(issuer, EventKind.badgeAward, [
          ['a', coordinate.value],
          ['p', member],
        ], '')..sign(issuerKey);
        final profile = Event(member, EventKind.badgeSet, [
          ['d', 'profile_badges'],
          ['a', coordinate.value],
          ['e', award.id],
        ], '')..sign(memberKey);

        final revokedAward = Event(issuer, EventKind.badgeAward, [
          ['a', coordinate.value],
          ['p', issuer],
        ], '')..sign(issuerKey);
        final revokedProfile = Event(issuer, EventKind.profileBadges, [
          ['a', coordinate.value],
          ['e', revokedAward.id],
        ], '')..sign(issuerKey);
        final revocation = Event(issuer, EventKind.eventDeletion, [
          ['e', revokedAward.id],
        ], '')..sign(issuerKey);

        // This socket is the only source of events. The client has no database,
        // no account keys and never initializes its normal relay pool.
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <WebSocket>[];
        final publicEvents = [
          badge,
          award,
          profile,
          revokedAward,
          revokedProfile,
          revocation,
        ];
        server.listen((request) async {
          if (!WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.write('{}');
            await request.response.close();
            return;
          }
          final socket = await WebSocketTransformer.upgrade(request);
          sockets.add(socket);
          socket.listen((data) {
            final frame = jsonDecode(data as String) as List<dynamic>;
            if (frame.first != 'REQ') return;
            final subscription = frame[1];
            final filters = frame
                .skip(2)
                .cast<Map<String, dynamic>>()
                .map(Filter.fromJson);
            for (final event in publicEvents) {
              if (filters.any((filter) => filter.checkEvent(event))) {
                socket.add(jsonEncode(['EVENT', subscription, event.toJson()]));
              }
            }
            socket.add(jsonEncode(['EOSE', subscription]));
          });
        });
        addTearDown(() async {
          await Future.wait(sockets.map((socket) => socket.close()));
          await server.close(force: true);
        });
        final relay = 'ws://127.0.0.1:${server.port}';
        const signer = UnauthenticatedSigner();
        final client = NostrClient(
          config: const NostrClientConfig(signer: signer),
          relayManagerConfig: RelayManagerConfig(
            defaultRelayUrl: relay,
            allowedRelayHost: '127.0.0.1',
          ),
        );
        addTearDown(client.dispose);
        SharedPreferences.setMockInitialValues({});
        final repository = BadgeRepository(
          nostrClient: client,
          sharedPreferences: await SharedPreferences.getInstance(),
          currentPubkey: () => null,
          definitionRelayUrl: relay,
          signer: () => signer,
          signEvent:
              ({
                required kind,
                required content,
                required tags,
                createdAt,
              }) async => throw StateError('guest cannot sign'),
        );
        addTearDown(repository.dispose);
        expect(client.hasKeys, isFalse);
        expect(client.isInitialized, isFalse);
        final discovered = await repository.loadPublicDefinitions();
        expect(discovered.single.coordinate, coordinate.value);
        final detail = await repository.loadBadgeDetail(coordinate);
        expect(detail.definition?.event.id, badge.id);
        expect(detail.viewerAward, isNull);
        final recipient = detail.recipients.singleWhere(
          (person) => person.pubkey == member,
        );
        expect(recipient.isAccepted, isTrue);
        expect(await repository.loadAcceptedHolders(coordinate), {member});
        expect(client.isInitialized, isFalse);
      },
    );
  });
}
