import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/features/chat/concord_session.dart';

class _Signer extends Fake implements NostrSigner {
  _Signer(this.failure);
  final String failure;
  @override
  Future<Event?> signEvent(Event event) async => throw StateError(failure);
}

void main() {
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
