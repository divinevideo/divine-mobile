import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/room_catalog_provider.dart';

class _Signer extends Fake implements NostrSigner {
  _Signer(this.failure);
  final String failure;
  @override
  Future<Event?> signEvent(Event event) async => throw StateError(failure);
}

class _Membership extends Fake implements ConcordCommunitySession {
  @override
  ConcordInviteBundle? bundle;
}

class _ObservedMembership extends Fake implements ConcordCommunitySession {
  @override
  bool ready = true;
  @override
  Object? failure;
  @override
  final control = ConcordControlState(communityId: '11' * 32, owner: '22' * 32)
    ..name = 'Observed community';
  final events = StreamController<void>();
  @override
  Stream<void> get changes => events.stream;
}

void main() {
  group('ConcordRoomCatalog', () {
    test(
      'catalog observation survives transient authority incompleteness',
      () async {
        final session = _ObservedMembership();
        final values = watchConcordCatalog(session)
            .take(3)
            .map((catalog) => catalog.ready)
            .toList();
        final result = expectLater(values, completion([true, false, true]));
        await Future<void>.delayed(Duration.zero);
        session.ready = false;
        session.events.add(null);
        await Future<void>.delayed(Duration.zero);
        session.ready = true;
        session.events.add(null);
        await result;
        await session.events.close();
      },
    );
    test('real channel persistence scope stays stable across root epochs', () {
      final owner = '11' * 32;
      final salt = '22' * 32;
      ConcordInviteBundle bundle(int epoch, String root) =>
          ConcordInviteBundle.fromJson({
            'community_id': deriveCommunityId(owner, salt),
            'owner': owner,
            'owner_salt': salt,
            'community_root': root,
            'root_epoch': epoch,
            'channels': <dynamic>[],
            'relays': <String>[],
          }, nowMs: 0);
      final membership = _Membership()..bundle = bundle(0, '33' * 32);
      final catalog = ConcordRoomCatalog.real(membership);
      final oldScope = catalog.scope;
      membership.bundle = bundle(1, '44' * 32);
      expect(catalog.scope, oldScope);
      expect(catalog.epoch, 1);
    });
  });
  group('buildConcordRepository', () {
    test(
      'shared room uses the current signer after same-account recovery',
      () async {
        final restored = _Signer('restored signer cannot sign');
        NostrSigner? active = restored;
        final repository = buildConcordRepository(
          pubkey: '01' * 32,
          signer: restored,
          signerForSend: () => active,
          store: InMemoryConcordStore('01' * 32),
        );
        addTearDown(repository.close);
        active = _Signer('replacement signer reached');
        final template = <String, dynamic>{
          'kind': 20013,
          'tags': <List<String>>[],
          'content': '',
          'created_at': 1,
        };
        await expectLater(
          repository.sealedTransport!.signer(template),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'replacement signer reached',
            ),
          ),
        );
        active = null;
        await expectLater(
          repository.sealedTransport!.signer(template),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'chat session is no longer active',
            ),
          ),
        );
      },
    );
  });
}
