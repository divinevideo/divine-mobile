import 'dart:async';
import 'dart:convert';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Manager extends Mock implements RelayManager {}

/// Exercises the real SDK pager/relay pool and real NostrClient adapter.
/// It advertises a two-event cap and serves inclusive until boundaries.
class _CappedRelay extends Relay {
  _CappedRelay(this.events) : super(address, RelayStatus(address)) {
    info = RelayInfo('', '', '', '', const [], '', '', maxLimit: 2);
  }
  static const address = 'wss://pager.example';
  final List<Event> events;
  final requests = <Map<String, dynamic>>[];
  int publications = 0;
  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.firstOrNull == 'REQ') {
      final filter = Map<String, dynamic>.from(message[2] as Map);
      requests.add(filter);
      Timer.run(() async {
        final until = filter['until'] as int?;
        final matches =
            events
                .where((event) => until == null || event.createdAt <= until)
                .toList()
              ..sort((a, b) {
                final age = b.createdAt.compareTo(a.createdAt);
                return age == 0 ? a.id.compareTo(b.id) : age;
              });
        for (final event in matches.take(2)) {
          final dynamic delivered = onMessage!(this, [
            'EVENT',
            message[1],
            event.toJson(),
          ]);
          if (delivered is Future) await delivered;
        }
        final dynamic ended = onMessage!(this, ['EOSE', message[1]]);
        if (ended is Future) await ended;
      });
    }
    if (message.firstOrNull == 'EVENT') publications++;
    return true;
  }
}

void main() {
  for (final sameSecond in [false, true]) {
    test(
      'real capped pager preserves discovery contract (same second: $sameSecond)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        final pubkey = (await signer.getPublicKey())!;
        final stored = <Event>[];
        const namespace = 'divine/dm-dismissals/v1';
        for (var i = 1; i <= 3; i++) {
          final content = (await signer.nip44Encrypt(
            pubkey,
            jsonEncode({
              'version': 1,
              'entries': {
                'field$i': {'value': true, 'updated_at': i},
              },
            }),
          ))!;
          stored.add(
            (await signer.signEvent(
              Event(
                pubkey,
                EventKind.appSpecificData,
                [
                  ['d', '$namespace/field/${i.toString().padLeft(64, '0')}'],
                ],
                content,
                createdAt: sameSecond ? 100 : 100 - i,
              ),
            ))!,
          );
        }
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        addTearDown(nostr.close);
        final relay = _CappedRelay(stored);
        expect(await nostr.relayPool.add(relay), true);
        final manager = _Manager();
        when(() => manager.connectedRelays).thenReturn([_CappedRelay.address]);
        when(() => manager.diagnosticsSink).thenReturn(null);
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: manager,
        );
        final repository = AccountStateRepository(
          nostrClient: client,
          sharedPreferences: prefs,
          pubkey: pubkey,
          signer: () => signer,
          namespace: namespace,
          perFieldSnapshots: true,
        );
        addTearDown(repository.close);
        if (sameSecond) {
          await repository.setValue('local', true);
          await expectLater(
            repository.synchronize(),
            throwsA(
              isA<AccountStateException>().having(
                (e) => e.retryable,
                'retryable',
                true,
              ),
            ),
          );
          expect(repository.hasPendingChanges, true);
          expect(
            repository.values.keys.where((key) => key.startsWith('field')),
            hasLength(2),
          );
          final journal =
              jsonDecode(
                    prefs.getString(
                      'account_state_${namespace}_${pubkey}_state',
                    )!,
                  )
                  as Map;
          expect(journal['events'], hasLength(2));
        } else {
          await repository.synchronize();
          expect(repository.values, {
            'field1': true,
            'field2': true,
            'field3': true,
          });
          expect(repository.hasPendingChanges, false);
        }
        expect(relay.requests.length, greaterThan(1));
        expect(relay.requests.every((filter) => filter['limit'] == 500), true);
        expect(relay.publications, 0);
      },
    );
  }
}
