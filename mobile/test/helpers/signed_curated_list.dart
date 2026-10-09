// ABOUTME: Builds authentic relay revisions for canonical-list fixtures.
// ABOUTME: Uses actual Schnorr signatures and NIP-44, without creation grants.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

/// Public identity of the well-known synthetic private test key 1.
const signedListFixtureOwner =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

Future<Event> signedCuratedListFixture(
  CuratedList list,
  LocalNostrSigner signer,
) async {
  final owner = await signer.getPublicKey();
  if (owner == null || owner != list.pubkey) {
    throw StateError('The fixture signer must own its relay revision');
  }
  final content = list.isPublic
      ? list.description ?? 'Curated video list: ${list.name}'
      : await signer.nip44Encrypt(
          owner,
          jsonEncode(CuratedListConverter.toItemTags(list)),
        );
  if (content == null) throw StateError('Fixture sealing failed');
  final event = Event(
    owner,
    30005,
    list.isPublic
        ? CuratedListConverter.toEventTags(list)
        : CuratedListConverter.toPrivateMetadataTags(list),
    content,
    createdAt: list.updatedAt.millisecondsSinceEpoch ~/ 1000,
  );
  await signer.signEvent(event);
  return event;
}
