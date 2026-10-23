import 'dart:convert';

import 'package:badge_repository/src/badge_dismissal_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClient extends Mock implements NostrClient {}

void main() {
  late _MockClient client;
  late LocalNostrSigner signer;
  late String pubkey;
  late SharedPreferences phonePreferences;
  late BadgeDismissalSync phone;
  late BadgeDismissalSync desktop;
  late List<Event> relayEvents;
  late bool timedOut;
  late bool rejectPublish;
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
    signer = LocalNostrSigner('1'.padLeft(64, '0'));
    pubkey = (await signer.getPublicKey())!;
    relayEvents = [];
    timedOut = false;
    rejectPublish = false;
    when(
      () => client.queryEventsDetailed(
        any(),
        useCache: false,
        requireAllRelaysSettled: true,
      ),
    ).thenAnswer(
      (_) async => (
        events: relayEvents.toList(),
        timedOut: timedOut,
        noRelays: false,
      ),
    );
    when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
      final event = call.positionalArguments.single as Event;
      if (!rejectPublish) relayEvents.add(event);
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

  test(
    'rejection and undo reach another device without sharing storage',
    () async {
      await phone.setHidden(pubkey, {}, coordinate, hidden: true);
      expect(await desktop.load(pubkey, {}), {coordinate});
      await desktop.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
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
      'decisions': {coordinate: true},
    });
  });

  test('migrates old dismissals without reversing a synced undo', () async {
    expect(await phone.load(pubkey, {coordinate}), {coordinate});
    expect(await desktop.load(pubkey, {}), {coordinate});
    await desktop.setHidden(pubkey, {coordinate}, coordinate, hidden: false);
    expect(await phone.load(pubkey, {coordinate, otherCoordinate}), {
      otherCoordinate,
    });
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
      throwsStateError,
    );
    expect(relayEvents, isEmpty);
    expect(await phone.load(pubkey, {coordinate}), {coordinate});
  });

  test('rejected publish does not record a successful dismissal', () async {
    rejectPublish = true;
    await expectLater(
      phone.setHidden(pubkey, {}, coordinate, hidden: true),
      throwsStateError,
    );
    expect(await phone.load(pubkey, {}), isEmpty);
  });

  test('another account cannot decrypt or reuse the local decisions', () async {
    await phone.setHidden(pubkey, {}, coordinate, hidden: true);
    final otherSigner = LocalNostrSigner('2'.padLeft(64, '0'));
    final otherPubkey = (await otherSigner.getPublicKey())!;
    final otherAccount = BadgeDismissalSync(
      client: client,
      preferences: phonePreferences,
      signer: () => otherSigner,
    );
    expect(await otherAccount.load(otherPubkey, {}), isEmpty);
  });

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
}
