import 'dart:async';
import 'dart:convert';

import 'package:badge_repository/src/badge_dismissal_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClient extends Mock implements NostrClient {}

class _MockPreferences extends Mock implements SharedPreferences {}

class _ControlledSigner extends LocalNostrSigner {
  _ControlledSigner() : super('1'.padLeft(64, '0'));
  bool refuseDecrypt = false;
  bool refuseEncrypt = false;
  bool refuseSign = false;
  bool changeSignedContent = false;
  bool returnUnsigned = false;
  int decryptCalls = 0;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    decryptCalls++;
    return refuseDecrypt ? null : super.nip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async =>
      refuseEncrypt ? null : super.nip44Encrypt(pubkey, plaintext);

  @override
  Future<Event?> signEvent(Event event) async {
    if (refuseSign) return null;
    if (returnUnsigned) return event;
    final toSign = changeSignedContent
        ? Event(
            event.pubkey,
            event.kind,
            event.tags,
            '${event.content}changed',
            createdAt: event.createdAt,
          )
        : event;
    return super.signEvent(toSign);
  }
}

void main() {
  late _MockClient client;
  late _ControlledSigner signer;
  late String pubkey;
  late SharedPreferences phonePreferences;
  late BadgeDismissalSync phone;
  late BadgeDismissalSync desktop;
  late List<Event> relayEvents;
  late bool timedOut;
  late bool rejectPublish;
  void Function(Event)? onPublished;
  const coordinate =
      '30009:2222222222222222222222222222222222222222222222222222222222222222:first';
  const otherCoordinate =
      '30009:2222222222222222222222222222222222222222222222222222222222222222:second';

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Event('1'.padLeft(64, '0'), 1, [], ''));
  });

  setUp(() async {
    client = _MockClient();
    signer = _ControlledSigner();
    pubkey = (await signer.getPublicKey())!;
    relayEvents = [];
    timedOut = false;
    rejectPublish = false;
    onPublished = null;
    when(
      () => client.queryEventsDetailed(
        any(),
        useCache: false,
        requireAllRelaysSettled: true,
      ),
    ).thenAnswer((call) async {
      final filter = (call.positionalArguments.single as List<Filter>).single;
      final events = relayEvents.toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return (
        events: filter.limit == null
            ? events
            : events.take(filter.limit!).toList(),
        timedOut: timedOut,
        noRelays: false,
      );
    });
    when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
      final event = call.positionalArguments.single as Event;
      if (!rejectPublish) {
        relayEvents.add(event);
        onPublished?.call(event);
      }
      return PublishOutcome(
        eventId: event.id,
        acceptedBy: rejectPublish ? const [] : const ['wss://relay.example'],
        rejectedBy: const {},
        noResponseFrom: const [],
      );
    });
    SharedPreferences.setMockInitialValues({});
    phonePreferences = await SharedPreferences.getInstance();
    phone = BadgeDismissalSync(
      client: client,
      preferences: phonePreferences,
      signer: () => signer,
    );
    SharedPreferences.setMockInitialValues({});
    desktop = BadgeDismissalSync(
      client: client,
      preferences: await SharedPreferences.getInstance(),
      signer: () => signer,
    );
  });

  Future<Event> snapshot(Object payload, {int? createdAt, String? raw}) async {
    final content = (await signer.nip44Encrypt(
      pubkey,
      raw ?? jsonEncode(payload),
    ))!;
    return (await signer.signEvent(
      Event(
        pubkey,
        EventKind.appSpecificData,
        [
          ['d', 'divine:badge-dismissals'],
        ],
        content,
        createdAt: createdAt,
      ),
    ))!;
  }

  group('load / setHidden', () {
    test('display does not wait for consolidation acknowledgment', () async {
      final acknowledgment = Completer<PublishOutcome>();
      Event? pending;
      when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
        pending = call.positionalArguments.single as Event;
        return acknowledgment.future;
      });
      var displayed = false;
      final loading = phone.load(pubkey, {coordinate}).then((choices) {
        displayed = true;
        return choices;
      });
      await pumpEventQueue();
      final displayedBeforeAcknowledgment = displayed;
      acknowledgment.complete(
        PublishOutcome(
          eventId: pending!.id,
          acceptedBy: const ['wss://relay.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );
      expect(await loading, {coordinate});
      expect(displayedBeforeAcknowledgment, isTrue);
    });

    test('read decisions survive a refused consolidation write', () async {
      relayEvents = [
        await snapshot({
          'version': 1,
          'decisions': {
            coordinate: {'hidden': true, 'updated_at': 1},
          },
        }),
      ];
      rejectPublish = true;
      expect(await phone.load(pubkey, {otherCoordinate}), {
        coordinate,
        otherCoordinate,
      });
    });

    test(
      'resends the signed cache when a complete relay read has lost it',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        final original = relayEvents.single;
        relayEvents.clear();
        expect(await phone.load(pubkey, {coordinate}), {coordinate});
        await pumpEventQueue();
        expect(relayEvents.map((event) => event.id), [original.id]);
        expect(await desktop.load(pubkey, {}), {coordinate});
      },
    );

    test(
      'a corrupt cache can recover through a complete read and mutation',
      () async {
        await phonePreferences.setString(
          'badge_dismissal_event_$pubkey',
          'invalid',
        );
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        expect(await desktop.load(pubkey, {}), {coordinate});
      },
    );

    test(
      'a queued local-read error reaches its caller without leaking',
      () async {
        final read =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer((_) => read.future);
        final first = phone.load(pubkey, {});
        final local = Completer<Set<String>>();
        final queued = phone.load(pubkey, local.future);
        final failure = expectLater(queued, throwsStateError);
        local.completeError(StateError('local preferences unavailable'));
        await pumpEventQueue();
        read.complete((events: <Event>[], timedOut: false, noRelays: false));
        expect(await first, isEmpty);
        await failure;
      },
    );

    test(
      'rejection and undo reach another device without sharing storage',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        expect(await desktop.load(pubkey, {}), {coordinate});
        await desktop.setHidden(
          pubkey,
          {coordinate},
          coordinate,
          hidden: false,
        );
        expect(await phone.load(pubkey, {coordinate}), isEmpty);
      },
    );

    test('published decisions are encrypted to the account', () async {
      await phone.setHidden(pubkey, {}, coordinate, hidden: true);
      final event = relayEvents.single;
      expect(event.kind, EventKind.appSpecificData);
      expect(event.isSigned, isTrue);
      expect(event.tags, [
        ['d', 'divine:badge-dismissals'],
      ]);
      expect(event.content, isNot(contains(coordinate)));
      final plaintext = await signer.nip44Decrypt(pubkey, event.content);
      expect(jsonDecode(plaintext!), {
        'version': 1,
        'decisions': {
          coordinate: {'hidden': true, 'updated_at': isPositive},
        },
      });
    });

    test('migrates old dismissals without reversing a synced undo', () async {
      final migration = Completer<void>();
      onPublished = (_) {
        if (!migration.isCompleted) migration.complete();
      };
      expect(await phone.load(pubkey, {coordinate}), {coordinate});
      await migration.future;
      expect(await desktop.load(pubkey, {}), {coordinate});
      await desktop.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
      final nextMigration = Completer<void>();
      onPublished = (_) {
        if (!nextMigration.isCompleted) nextMigration.complete();
      };
      expect(await phone.load(pubkey, {coordinate, otherCoordinate}), {
        otherCoordinate,
      });
      await nextMigration.future;
      expect(await desktop.load(pubkey, {}), {otherCoordinate});
    });

    test('reads remote decisions before editing another badge', () async {
      await phone.setHidden(pubkey, {}, coordinate, hidden: true);
      await desktop.setHidden(pubkey, {}, otherCoordinate, hidden: true);
      expect(await phone.load(pubkey, {coordinate}), {
        coordinate,
        otherCoordinate,
      });
    });

    test(
      'keeps an acknowledged write through stale reads and a restart',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        relayEvents.clear();
        phone = BadgeDismissalSync(
          client: client,
          preferences: phonePreferences,
          signer: () => signer,
        );
        await phone.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
        expect(await phone.load(pubkey, {coordinate}), isEmpty);
      },
    );

    test('does not publish over an incomplete relay read', () async {
      timedOut = true;
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(relayEvents, isEmpty);
      expect(await phone.load(pubkey, {coordinate}), {coordinate});
    });

    test('rejected publish does not record a successful dismissal', () async {
      rejectPublish = true;
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(await phone.load(pubkey, {}), isEmpty);
    });

    test(
      'another account cannot decrypt or reuse the local decisions',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        final otherSigner = LocalNostrSigner('2'.padLeft(64, '0'));
        final otherPubkey = (await otherSigner.getPublicKey())!;
        final otherAccount = BadgeDismissalSync(
          client: client,
          preferences: phonePreferences,
          signer: () => otherSigner,
        );
        expect(await otherAccount.load(otherPubkey, {}), isEmpty);
      },
    );

    test('edits advance beyond the latest known timestamp', () async {
      await phone.setHidden(pubkey, {}, coordinate, hidden: true);
      final first = relayEvents.single;
      // A known future timestamp makes the +1 requirement deterministic,
      // independent of how long encryption takes on a shared runner.
      final ahead = Event(
        pubkey,
        first.kind,
        first.tags,
        first.content,
        createdAt: 4102444800,
      );
      relayEvents = [(await signer.signEvent(ahead))!];
      await phone.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
      expect(relayEvents.last.createdAt, 4102444801);
      expect(await desktop.load(pubkey, {}), isEmpty);
    });
    test(
      'unavailable decryption preserves local choices without publishing',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        signer.refuseDecrypt = true;
        expect(await desktop.load(pubkey, {otherCoordinate}), {
          otherCoordinate,
        });
        expect(relayEvents, hasLength(1));
      },
    );

    test(
      'merges a cached undo with a newer stale snapshot from another device',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        await desktop.load(pubkey, {});
        final oldSnapshot = relayEvents.single;
        await phone.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
        final undo = relayEvents.last;
        relayEvents = [oldSnapshot];
        await desktop.setHidden(
          pubkey,
          {coordinate},
          otherCoordinate,
          hidden: true,
        );
        final stale = relayEvents.last;
        final newerStale = Event(
          pubkey,
          stale.kind,
          stale.tags,
          stale.content,
          createdAt: undo.createdAt + 10,
        );
        relayEvents = [(await signer.signEvent(newerStale))!];
        final consolidation = Completer<void>();
        onPublished = (_) {
          if (!consolidation.isCompleted) consolidation.complete();
        };
        expect(await phone.load(pubkey, {}), {otherCoordinate});
        await consolidation.future;
        expect(await desktop.load(pubkey, {coordinate, otherCoordinate}), {
          otherCoordinate,
        });
      },
    );
    for (final payload in <Object>[
      [],
      {'version': 2, 'decisions': <String, Object?>{}},
      {'version': 1, 'decisions': <Object?>[]},
      {
        'version': 1,
        'decisions': {coordinate: true},
      },
      {
        'version': 1,
        'decisions': {
          coordinate: {'hidden': 'yes', 'updated_at': 1},
        },
      },
      {
        'version': 1,
        'decisions': {
          coordinate: {'hidden': true, 'updated_at': -1},
        },
      },
    ]) {
      test(
        'unreadable settings preserve local choices and cannot be overwritten: $payload',
        () async {
          relayEvents = [await snapshot(payload)];
          expect(await phone.load(pubkey, {otherCoordinate}), {
            otherCoordinate,
          });
          await expectLater(
            phone.setHidden(pubkey, {}, coordinate, hidden: true),
            throwsFormatException,
          );
          expect(relayEvents, hasLength(1));
        },
      );
    }

    test('malformed JSON is never exposed or overwritten', () async {
      relayEvents = [await snapshot({}, raw: 'private invalid JSON')];
      expect(await phone.load(pubkey, {coordinate}), {coordinate});
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(
          isA<FormatException>().having(
            (error) => error.source,
            'source',
            isNull,
          ),
        ),
      );
      expect(relayEvents, hasLength(1));
    });

    test('read failures preserve local choices', () async {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
        ),
      ).thenThrow(Exception('network unavailable'));
      expect(await phone.load(pubkey, {coordinate}), {coordinate});
      expect(relayEvents, isEmpty);
    });

    test('an unavailable signer does not prevent viewing badges', () async {
      final unavailable = BadgeDismissalSync(
        client: client,
        preferences: phonePreferences,
        signer: () => throw StateError('no active signer'),
      );
      expect(await unavailable.load(pubkey, {coordinate}), {coordinate});
    });

    test('a signer for another identity cannot publish a decision', () async {
      final mismatch = BadgeDismissalSync(
        client: client,
        preferences: phonePreferences,
        signer: () => LocalNostrSigner('2'.padLeft(64, '0')),
      );
      await expectLater(
        mismatch.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(relayEvents, isEmpty);
    });

    test('encryption refusal does not change a decision', () async {
      signer.refuseEncrypt = true;
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(relayEvents, isEmpty);
    });

    test('signing refusal does not change a decision', () async {
      signer.refuseSign = true;
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(relayEvents, isEmpty);
    });

    test(
      'a signer cannot change the encrypted snapshot it was asked to sign',
      () async {
        signer.changeSignedContent = true;
        await expectLater(
          phone.setHidden(pubkey, {}, coordinate, hidden: true),
          throwsA(isA<BadgeDismissalSyncException>()),
        );
        expect(relayEvents, isEmpty);
      },
    );

    test('an unsigned event is not published', () async {
      signer.returnUnsigned = true;
      await expectLater(
        phone.setHidden(pubkey, {}, coordinate, hidden: true),
        throwsA(isA<BadgeDismissalSyncException>()),
      );
      expect(relayEvents, isEmpty);
    });

    test(
      'failed local persistence is reported as a synchronization failure',
      () async {
        final preferences = _MockPreferences();
        when(() => preferences.getString(any())).thenReturn(null);
        when(
          () => preferences.setString(any(), any()),
        ).thenAnswer((_) async => false);
        final brokenCache = BadgeDismissalSync(
          client: client,
          preferences: preferences,
          signer: () => signer,
        );
        await expectLater(
          brokenCache.setHidden(pubkey, {}, coordinate, hidden: true),
          throwsA(
            isA<BadgeDismissalSyncException>().having(
              (error) => error.toString(),
              'description',
              contains('Could not save decisions'),
            ),
          ),
        );
      },
    );

    test('corrupt local cache does not prevent viewing badges', () async {
      await phonePreferences.setString(
        'badge_dismissal_event_$pubkey',
        'invalid',
      );
      expect(await phone.load(pubkey, {coordinate}), {coordinate});
    });

    test(
      'concurrent decisions with equal timestamps converge on undo',
      () async {
        final hidden = await snapshot({
          'version': 1,
          'decisions': {
            coordinate: {'hidden': true, 'updated_at': 123},
          },
        }, createdAt: 1000);
        final restored = await snapshot({
          'version': 1,
          'decisions': {
            coordinate: {'hidden': false, 'updated_at': 123},
          },
        }, createdAt: 1000);
        relayEvents = [hidden, restored];
        expect(await phone.load(pubkey, {}), isEmpty);
        relayEvents = [restored, hidden];
        expect(await desktop.load(pubkey, {}), isEmpty);
      },
    );

    test(
      'successive snapshots stay current and unchanged reads do not decrypt again',
      () async {
        for (var i = 1; i <= 10; i++) {
          relayEvents = [
            await snapshot({
              'version': 1,
              'decisions': {
                coordinate: {'hidden': i.isOdd, 'updated_at': i},
              },
            }, createdAt: 1000 + i),
          ];
          expect(
            await phone.load(pubkey, {}),
            i.isOdd ? {coordinate} : isEmpty,
          );
        }
        final decryptions = signer.decryptCalls;
        final count = relayEvents.length;
        expect(await phone.load(pubkey, {}), isEmpty);
        expect(signer.decryptCalls, decryptions);
        expect(relayEvents, hasLength(count));
      },
    );
    test(
      'an incomplete read retains every signed snapshot across restart',
      () async {
        await phone.setHidden(pubkey, {}, coordinate, hidden: true);
        await desktop.load(pubkey, {});
        final old = relayEvents.single;
        await phone.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
        final undo = relayEvents.last;
        relayEvents = [old];
        await desktop.setHidden(
          pubkey,
          {coordinate},
          otherCoordinate,
          hidden: true,
        );
        final stale = relayEvents.last;
        relayEvents = [
          (await signer.signEvent(
            Event(
              pubkey,
              stale.kind,
              stale.tags,
              stale.content,
              createdAt: undo.createdAt + 10,
            ),
          ))!,
        ];
        timedOut = true;
        expect(await phone.load(pubkey, {}), {otherCoordinate});
        final restarted = BadgeDismissalSync(
          client: client,
          preferences: phonePreferences,
          signer: () => signer,
        );
        expect(await restarted.load(pubkey, {otherCoordinate}), {
          otherCoordinate,
        });
      },
    );

    test(
      'a fresh device merges current snapshots held on different relays',
      () async {
        relayEvents = [
          await snapshot({
            'version': 1,
            'decisions': {
              coordinate: {'hidden': true, 'updated_at': 1000},
            },
          }, createdAt: 1000),
          await snapshot({
            'version': 1,
            'decisions': {
              otherCoordinate: {'hidden': true, 'updated_at': 1001},
            },
          }, createdAt: 1001),
        ];
        expect(await phone.load(pubkey, {}), {coordinate, otherCoordinate});
      },
    );
  });
}
