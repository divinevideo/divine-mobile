import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(NativeProofData, () {
    group('unattestedSources', () {
      test('round-trips through JSON', () {
        const proof = NativeProofData(
          videoHash: 'hash',
          unattestedSources: true,
        );

        final restored = NativeProofData.fromJson(proof.toJson());

        expect(restored.unattestedSources, isTrue);
      });

      test('is absent from the JSON of an ordinary proof', () {
        const proof = NativeProofData(videoHash: 'hash');

        expect(proof.toJson().containsKey('unattestedSources'), isFalse);
        expect(
          NativeProofData.fromJson(proof.toJson()).unattestedSources,
          isFalse,
        );
      });

      test('is set from native metadata when the caller says so', () {
        final proof = NativeProofData.fromMetadata(
          {NativeProofData.metadataHashKey: 'hash'},
          unattestedSources: true,
        );

        expect(proof.unattestedSources, isTrue);
      });

      test('survives replacing the device attestation', () {
        const proof = NativeProofData(
          videoHash: 'hash',
          unattestedSources: true,
        );

        expect(proof.withDeviceAttestation('token').unattestedSources, isTrue);
      });

      test('is cleared on a copy that keeps everything else', () {
        const proof = NativeProofData(
          videoHash: 'hash',
          deviceAttestation: 'token',
          unattestedSources: true,
        );

        final copy = proof.withUnattestedSources(unattested: false);

        expect(copy.unattestedSources, isFalse);
        expect(
          copy.toJson(),
          equals(proof.toJson()..remove('unattestedSources')),
        );
      });
    });
  });
}
