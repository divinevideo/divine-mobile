// ABOUTME: Unit tests for CuratedListRelayGateway, the curated-list relay edge
// ABOUTME: Covers NIP-44 sealing guards, unseal classification, and redaction

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _ownerPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
const _strangerPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _plaintextEventId =
    '2222222222222222222222222222222222222222222222222222222222222222';

CuratedList _list({bool isPublic = false}) => CuratedList(
  id: 'list-1',
  name: 'My Vines',
  videoEventIds: const [_videoEventId],
  isPublic: isPublic,
  pubkey: _ownerPubkey,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Event _event({
  required String content,
  required String pubkey,
  List<List<String>> tags = const [
    ['d', 'list-1'],
  ],
}) => Event.fromJson({
  'id': _plaintextEventId,
  'pubkey': pubkey,
  'created_at': 1786000000,
  'kind': 30005,
  'tags': tags,
  'content': content,
  'sig': 'test_signature',
});

void main() {
  group(CuratedListRelayGateway, () {
    late CuratedListRelayGateway gateway;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late MockNostrSigner mockSigner;

    setUp(() {
      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();
      mockSigner = stubListSigner(mockNostr, _ownerPubkey);
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownerPubkey);
      gateway = CuratedListRelayGateway(
        nostrService: mockNostr,
        authService: mockAuth,
      );
    });

    group('sealItemTags', () {
      test('seals the item tags to the owner', () async {
        final sealed = await gateway.sealItemTags(_list());

        expect(sealed, isNotNull);
        expect(jsonDecode(unsealForTest(sealed!)!), [
          ['e', _videoEventId],
        ]);
      });

      test('refuses when the signer is a different account', () async {
        // Publishing here would encrypt the items to a key the owner cannot
        // read, and the list would be unrecoverable on their own devices.
        when(mockSigner.getPublicKey).thenAnswer((_) async => _strangerPubkey);

        expect(await gateway.sealItemTags(_list()), isNull);
      });

      test('refuses while signed out', () async {
        when(() => mockAuth.isAuthenticated).thenReturn(false);

        expect(await gateway.sealItemTags(_list()), isNull);
      });
    });

    group('publishList ownership', () {
      setUp(() {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => _event(
            content: invocation.namedArguments[#content] as String,
            pubkey: _ownerPubkey,
            tags: invocation.namedArguments[#tags] as List<List<String>>,
          ),
        );
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.single as Event,
          ),
        );
        when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
          (invocation) async => acceptedOutcome(
            invocation.positionalArguments.single as Event,
          ),
        );
      });

      for (final isPublic in [false, true]) {
        test(
          'rejects foreign ${isPublic ? 'public' : 'private'} record before signing or sealing',
          () async {
            final foreign = _list(isPublic: isPublic)
                .copyWith(pubkey: _strangerPubkey);
            expect(await gateway.publishList(foreign), isNull);
            verifyNever(
              () => mockAuth.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
              ),
            );
            verifyNever(mockSigner.getPublicKey);
            verifyNever(() => mockSigner.nip44Encrypt(any(), any()));
            verifyNever(() => mockNostr.publishEvent(any()));
            verifyNever(() => mockNostr.publishEventAwaitOk(any()));
          },
        );
        for (final confirmed in [false, true]) {
          test(
            'rejects wrong signed author for ${isPublic ? 'public' : 'private'} ${confirmed ? 'confirmed' : 'queued'} publication',
            () async {
              when(
                () => mockAuth.createAndSignEvent(
                  kind: any(named: 'kind'),
                  content: any(named: 'content'),
                  tags: any(named: 'tags'),
                ),
              ).thenAnswer(
                (_) async => _event(content: '', pubkey: _strangerPubkey),
              );
              expect(
                await gateway.publishList(
                  _list(isPublic: isPublic),
                  confirmed: confirmed,
                ),
                isNull,
              );
              verifyNever(() => mockNostr.publishEvent(any()));
              verifyNever(() => mockNostr.publishEventAwaitOk(any()));
            },
          );
        }
        test(
          'refuses ${isPublic ? 'public' : 'private'} dispatch if account changes while signing',
          () async {
            final signed = Completer<Event?>();
            when(
              () => mockAuth.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
              ),
            ).thenAnswer((_) => signed.future);
            final pending = gateway.publishList(_list(isPublic: isPublic));
            await pumpEventQueue();
            when(() => mockAuth.currentPublicKeyHex)
                .thenReturn(_strangerPubkey);
            signed.complete(_event(content: '', pubkey: _ownerPubkey));
            expect(await pending, isNull);
            verifyNever(() => mockNostr.publishEvent(any()));
            verifyNever(() => mockNostr.publishEventAwaitOk(any()));
          },
        );
      }
      test('refuses dispatch after lease retirement during signing', () async {
        var active = true;
        gateway = CuratedListRelayGateway(
          nostrService: mockNostr,
          authService: mockAuth,
          isCurrentSession: () => active,
        );
        final signed = Completer<Event?>();
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) => signed.future);
        final pending = gateway.publishList(_list(isPublic: true));
        await pumpEventQueue();
        active = false;
        signed.complete(_event(content: '', pubkey: _ownerPubkey));
        expect(await pending, isNull);
        verifyNever(() => mockNostr.publishEvent(any()));
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
      });
      test(
        'private sealing refuses a foreign owner before signer access',
        () async {
          expect(
            await gateway.sealItemTags(
              _list().copyWith(pubkey: _strangerPubkey),
            ),
            isNull,
          );
          verifyNever(mockSigner.getPublicKey);
          verifyNever(() => mockSigner.nip44Encrypt(any(), any()));
        },
      );
    });

    group('unsealItemTags', () {
      test('recovers the tags it sealed', () async {
        final sealed = await gateway.sealItemTags(_list());

        final unsealed = await gateway.unsealItemTags(
          _event(content: sealed!, pubkey: _ownerPubkey),
        );

        expect(unsealed.status, UnsealItemTagsStatus.unsealed);
        expect(unsealed.tags, [
          ['e', _videoEventId],
        ]);
      });

      test('reports a public list as not sealed', () async {
        final unsealed = await gateway.unsealItemTags(
          _event(
            content: 'A public description',
            pubkey: _ownerPubkey,
            tags: const [
              ['d', 'list-1'],
              ['e', _videoEventId],
            ],
          ),
        );

        expect(unsealed.status, UnsealItemTagsStatus.notSealed);
      });

      test(
        'reports public item tags as not sealed even with sealed content',
        () async {
          final sealed = await gateway.sealItemTags(_list());

          final unsealed = await gateway.unsealItemTags(
            _event(
              content: sealed!,
              pubkey: _ownerPubkey,
              tags: const [
                ['d', 'list-1'],
                ['e', _videoEventId],
              ],
            ),
          );

          expect(unsealed.status, UnsealItemTagsStatus.notSealed);
          verifyNever(() => mockSigner.nip44Decrypt(any(), any()));
        },
      );

      test('fails rather than exposing another account sealed list', () async {
        final sealed = await gateway.sealItemTags(_list());

        // Only our own lists are encrypted to us. Reporting notSealed would
        // let the caller merge the ciphertext as if it were a description.
        final unsealed = await gateway.unsealItemTags(
          _event(content: sealed!, pubkey: _strangerPubkey),
        );

        expect(unsealed.status, UnsealItemTagsStatus.failed);
      });
    });

    group('redactPlaintextListEvent', () {
      setUp(() {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (i) async => Event(
            _ownerPubkey,
            i.namedArguments[#kind] as int,
            i.namedArguments[#tags] as List<List<String>>,
            i.namedArguments[#content] as String,
          ),
        );
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (i) async => PublishSuccess(event: i.positionalArguments[0] as Event),
        );
      });

      test('targets the event id and not the coordinate', () async {
        await gateway.redactPlaintextListEvent(_plaintextEventId);

        final redaction =
            verify(() => mockNostr.publishEvent(captureAny())).captured.single
                as Event;
        expect(redaction.kind, EventKind.eventDeletion);
        expect(redaction.tags, contains(equals(['e', _plaintextEventId])));
        expect(redaction.tags, contains(equals(['k', '30005'])));
        // An `a` tag would take every version of the coordinate with it,
        // including the sealed replacement the flip just published.
        expect(
          redaction.tags.any(
            (dynamic tag) =>
                (tag as List<dynamic>).isNotEmpty && tag.first == 'a',
          ),
          isFalse,
        );
      });

      test('does not throw when the signer refuses', () async {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          gateway.redactPlaintextListEvent(_plaintextEventId),
          completes,
        );
        verifyNever(() => mockNostr.publishEvent(any()));
      });
    });

    group('publishListDeletion', () {
      Event deletion({String pubkey = _ownerPubkey}) => Event(
        pubkey,
        EventKind.eventDeletion,
        [
          ['a', '30005:$pubkey:list-1'],
          ['k', '30005'],
        ],
        'Deleted curated list list-1',
      );

      void stubSigning(Future<Event?> Function() sign) {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) => sign());
      }

      test('publishes the deletion once a relay accepts it', () async {
        final signed = deletion();
        stubSigning(() async => signed);
        when(
          () => mockNostr.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => acceptedOutcome(signed));

        expect(
          await gateway.publishListDeletion(
            'list-1',
            ownerPubkey: _ownerPubkey,
          ),
          isTrue,
        );
        verify(() => mockNostr.publishEventAwaitOk(signed)).called(1);
      });

      test('reports failure when no relay accepts the deletion', () async {
        final signed = deletion();
        stubSigning(() async => signed);
        when(
          () => mockNostr.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => rejectedOutcome(signed));

        expect(
          await gateway.publishListDeletion(
            'list-1',
            ownerPubkey: _ownerPubkey,
          ),
          isFalse,
        );
      });

      test('refuses another account without signing', () async {
        stubSigning(() async => deletion());

        expect(
          await gateway.publishListDeletion(
            'list-1',
            ownerPubkey: _strangerPubkey,
          ),
          isFalse,
        );
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('drops a deletion when the account changed while signing', () async {
        var active = _ownerPubkey;
        when(() => mockAuth.currentPublicKeyHex).thenAnswer((_) => active);
        stubSigning(() async {
          active = _strangerPubkey;
          return deletion();
        });

        expect(
          await gateway.publishListDeletion(
            'list-1',
            ownerPubkey: _ownerPubkey,
          ),
          isFalse,
        );
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
      });

      test('drops a deletion signed by another account', () async {
        stubSigning(() async => deletion(pubkey: _strangerPubkey));

        expect(
          await gateway.publishListDeletion(
            'list-1',
            ownerPubkey: _ownerPubkey,
          ),
          isFalse,
        );
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
      });
    });
  });
}
