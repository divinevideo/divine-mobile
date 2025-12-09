// ABOUTME: Performance tests for NativeProofModeService and NativeProofData
// ABOUTME: Benchmarks native ProofMode proof generation and data serialization

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/native_proof_data.dart';

void main() {
  group('NativeProofData Performance Benchmarks', () {
    test('NativeProofData serialization should be fast', () {
      final stopwatch = Stopwatch()..start();

      // Create many NativeProofData instances and serialize them
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        final proofData = NativeProofData(
          videoHash: 'hash_$i' * 8, // 64 char hash
          sensorDataCsv:
              'timestamp,lat,lng,accuracy\n2025-01-01T00:00:00Z,37.7749,-122.4194,10.0',
          pgpSignature:
              '-----BEGIN PGP SIGNATURE-----\nVersion: GnuPG v1\n...\n-----END PGP SIGNATURE-----',
          publicKey:
              '-----BEGIN PGP PUBLIC KEY BLOCK-----\nVersion: GnuPG v1\n...\n-----END PGP PUBLIC KEY BLOCK-----',
          deviceAttestation: 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...',
          timestamp: '2025-01-01T00:00:00Z',
        );

        final json = proofData.toJson();
        final jsonString = jsonEncode(json);
        expect(jsonString.isNotEmpty, true);
      }

      stopwatch.stop();
      final avgMicroseconds = stopwatch.elapsedMicroseconds / iterations;

      // Serialization should be under 100 microseconds per instance
      expect(
        avgMicroseconds,
        lessThan(100),
        reason:
            'NativeProofData serialization took $avgMicroseconds µs/op (target: <100 µs)',
      );
    });

    test('NativeProofData deserialization should be fast', () {
      // Pre-create JSON strings
      final jsonStrings = List.generate(1000, (i) {
        return jsonEncode({
          'videoHash': 'hash_$i' * 8,
          'sensorDataCsv': 'timestamp,lat,lng\n2025-01-01,37.7749,-122.4194',
          'pgpSignature': 'sig_$i',
          'publicKey': 'key_$i',
          'deviceAttestation': 'attestation_$i',
          'timestamp': '2025-01-01T00:00:00Z',
        });
      });

      final stopwatch = Stopwatch()..start();

      for (final jsonString in jsonStrings) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final proofData = NativeProofData.fromJson(json);
        expect(proofData.videoHash.isNotEmpty, true);
      }

      stopwatch.stop();
      final avgMicroseconds =
          stopwatch.elapsedMicroseconds / jsonStrings.length;

      // Deserialization should be under 100 microseconds per instance
      expect(
        avgMicroseconds,
        lessThan(100),
        reason:
            'NativeProofData deserialization took $avgMicroseconds µs/op (target: <100 µs)',
      );
    });

    test('NativeProofData verification level computation should be fast', () {
      final proofDataList = [
        // Full verification
        const NativeProofData(
          videoHash: 'hash1',
          pgpSignature: 'sig',
          publicKey: 'key',
          deviceAttestation: 'attestation',
          sensorDataCsv: 'csv',
        ),
        // Web verification
        const NativeProofData(
          videoHash: 'hash2',
          pgpSignature: 'sig',
          publicKey: 'key',
          sensorDataCsv: 'csv',
        ),
        // Basic proof
        const NativeProofData(videoHash: 'hash3', sensorDataCsv: 'csv'),
        // Unverified
        const NativeProofData(videoHash: 'hash4'),
      ];

      final stopwatch = Stopwatch()..start();

      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        for (final proofData in proofDataList) {
          final level = proofData.verificationLevel;
          expect(level.isNotEmpty, true);
        }
      }

      stopwatch.stop();
      final totalOps = iterations * proofDataList.length;
      final avgNanoseconds = (stopwatch.elapsedMicroseconds * 1000) / totalOps;

      // Verification level should be under 1000 nanoseconds per check
      expect(
        avgNanoseconds,
        lessThan(1000),
        reason:
            'Verification level check took $avgNanoseconds ns/op (target: <1000 ns)',
      );
    });

    test('NativeProofData isComplete check should be fast', () {
      final proofDataList = [
        const NativeProofData(
          videoHash: 'hash1',
          pgpSignature: 'sig',
          publicKey: 'key',
          sensorDataCsv: 'csv',
        ),
        const NativeProofData(videoHash: 'hash2'),
      ];

      final stopwatch = Stopwatch()..start();

      const iterations = 100000;
      var completeCount = 0;
      for (var i = 0; i < iterations; i++) {
        for (final proofData in proofDataList) {
          if (proofData.isComplete) completeCount++;
        }
      }

      stopwatch.stop();
      final totalOps = iterations * proofDataList.length;
      final avgNanoseconds = (stopwatch.elapsedMicroseconds * 1000) / totalOps;

      // Verify we actually ran the checks
      expect(completeCount, equals(iterations)); // Only first item is complete

      // isComplete should be under 100 nanoseconds per check
      expect(
        avgNanoseconds,
        lessThan(100),
        reason: 'isComplete check took $avgNanoseconds ns/op (target: <100 ns)',
      );
    });

    test('NativeProofData.fromMetadata conversion should be fast', () {
      final metadataList = List.generate(1000, (i) {
        return {
          'hash': 'hash_$i' * 8,
          'csv': 'timestamp,lat,lng\n2025-01-01,0,0',
          'signature': 'sig_$i',
          'publicKey': 'key_$i',
        };
      });

      final stopwatch = Stopwatch()..start();

      for (final metadata in metadataList) {
        final proofData = NativeProofData.fromMetadata(metadata);
        expect(proofData.videoHash.isNotEmpty, true);
      }

      stopwatch.stop();
      final avgMicroseconds =
          stopwatch.elapsedMicroseconds / metadataList.length;

      // fromMetadata should be under 50 microseconds per instance
      expect(
        avgMicroseconds,
        lessThan(50),
        reason:
            'fromMetadata conversion took $avgMicroseconds µs/op (target: <50 µs)',
      );
    });
  });
}
