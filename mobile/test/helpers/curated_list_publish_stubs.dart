// ABOUTME: Shared mocktail stubs for the publish paths CuratedListService uses.
// ABOUTME: Covers relay publishing plus the NIP-44 sealing of private lists.

import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';

class MockNostrSigner extends Mock implements NostrSigner {}

/// Registered here rather than in each caller's `setUpAll`, so stubbing a
/// publish path is one call regardless of which matchers it needs.
void _registerEventFallback() {
  registerFallbackValue(
    Event(
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      1,
      <List<String>>[],
      '',
    ),
  );
}

/// Stand-in for NIP-44 that a test can reverse.
///
/// The bytes have a valid NIP-44 v2 envelope and padding, but intentionally do
/// not perform encryption or MAC authentication. That keeps tests reversible
/// while exercising the same payload classification as production.
String sealForTest(String plaintext) => base64Encode([
  2,
  ...List<int>.filled(32, 0),
  ...NIP44V2.pad(plaintext),
  ...List<int>.filled(32, 0),
]);

/// The inverse of [sealForTest]; `null` when [ciphertext] was never sealed,
/// which is how a public list's plain description reads.
String? unsealForTest(String ciphertext) {
  try {
    return NIP44V2.unpad(NIP44V2.decodePayload(ciphertext)['ciphertext']!);
  } on Object {
    return null;
  }
}

/// An outcome one relay accepted — what [PublishOutcome.acceptedByAny] gates on.
PublishOutcome acceptedOutcome(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const ['wss://relay.test'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

/// An outcome no relay accepted, so the caller may roll local state back.
PublishOutcome rejectedOutcome(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const [],
  rejectedBy: const {'wss://relay.test': 'blocked'},
  noResponseFrom: const [],
);

/// Stubs [client]'s signer so private lists can be sealed and unsealed.
///
/// Every owned list publishes now, so a service test that creates any list at
/// all reaches the signer; without this the mock returns null for
/// `NostrClient.signer` and the publish dies on a type error rather than
/// whatever the test is about.
MockNostrSigner stubListSigner(NostrClient client, String pubkey) {
  _registerEventFallback();
  stubAuthoritativeListRead(client);
  final signer = MockNostrSigner();
  when(() => client.signer).thenReturn(signer);
  when(signer.getPublicKey).thenAnswer((_) async => pubkey);
  when(
    () => signer.nip44Encrypt(any(), any()),
  ).thenAnswer((i) async => sealForTest(i.positionalArguments[1] as String));
  when(
    () => signer.nip44Decrypt(any(), any()),
  ).thenAnswer((i) async => unsealForTest(i.positionalArguments[1] as String));
  return signer;
}

/// Stubs signing and relay acceptance so `createList` reaches a list object.
///
/// For a test that is about something else — ownership, persistence, queries —
/// and only needs list creation to get that far.
void stubListPublishing({
  required NostrClient client,
  required AuthService auth,
  required String pubkey,
}) {
  stubListSigner(client, pubkey);
  when(
    () => auth.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
      createdAt: any(named: 'createdAt'),
    ),
  ).thenAnswer(
    (i) async => Event(
      pubkey,
      i.namedArguments[#kind] as int,
      i.namedArguments[#tags] as List<List<String>>,
      i.namedArguments[#content] as String,
      createdAt: i.namedArguments[#createdAt] as int?,
    ),
  );
  when(
    () => client.publishEventAwaitOk(any()),
  ).thenAnswer((i) async => acceptedOutcome(i.positionalArguments[0] as Event));
  when(() => client.publishEvent(any())).thenAnswer(
    (i) async => PublishSuccess(event: i.positionalArguments[0] as Event),
  );
}

/// A completed network read for fixtures that are about publication/storage.
/// Use [events] to expose the same remote state as the fixture's subscriptions.
void stubAuthoritativeListRead(
  NostrClient client, {
  Iterable<Event> Function() events = _noListEvents,
}) {
  registerFallbackValue(<Filter>[]);
  registerFallbackValue(Duration.zero);
  when(
    () => client.readCurrentVersion(
      kind: any(named: 'kind'),
      pubkey: any(named: 'pubkey'),
      dTag: any(named: 'dTag'),
      timeout: any(named: 'timeout'),
    ),
  ).thenAnswer((i) async => currentVersionOf(events(), i));
}

Iterable<Event> _noListEvents() => const [];

/// What `NostrClient.readCurrentVersion` answers, for the address [read]
/// asked about, when every relay answered with [events]: the newest version
/// by `created_at`, then the lowest id. Signatures are not checked.
CurrentVersionRead currentVersionOf(Iterable<Event> events, Invocation read) {
  final kind = read.namedArguments[#kind] as int;
  final pubkey = read.namedArguments[#pubkey] as String;
  final dTag = read.namedArguments[#dTag] as String?;
  Event? newest;
  for (final event in events) {
    if (event.kind != kind ||
        event.pubkey != pubkey ||
        (dTag != null && event.dTagValue != dTag)) {
      continue;
    }
    if (newest == null ||
        event.createdAt > newest.createdAt ||
        (event.createdAt == newest.createdAt &&
            event.id.compareTo(newest.id) < 0)) {
      newest = event;
    }
  }
  return newest == null
      ? const CurrentVersionAbsent()
      : CurrentVersionFound(newest);
}

/// What `NostrClient.readCurrentVersion` answers for [read] when the relays
/// gave [relays]: a read that timed out or reached no relay fails, whatever
/// it collected.
CurrentVersionRead currentVersionFromRelays(
  ({List<Event> events, bool timedOut, bool noRelays}) relays,
  Invocation read,
) => relays.timedOut || relays.noRelays
    ? CurrentVersionFailed(noRelay: relays.noRelays)
    : currentVersionOf(relays.events, read);
