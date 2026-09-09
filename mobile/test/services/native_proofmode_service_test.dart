import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const proofModeChannel = MethodChannel('org.openvine/proofmode');
  const attestationChannel = MethodChannel('app_attestation');
  const proofHash =
      'bfe97053586981c5d2373625c3ee921d8af88c79fca442e189a82230d99bdc78';

  setUp(() async {
    await LogCaptureService().clearAllLogs();
  });

  tearDown(() async {
    NativeProofModeService.c2paSigningServiceFactoryOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proofModeChannel, null);
    await LogCaptureService().clearAllLogs();
  });

  group('readProofMetadata logging', () {
    test(
      'logs missing proof directory as debug for expected pre-generation read',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return null;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
          warnIfMissing: false,
        );

        expect(metadata, isNull);
        expect(
          _logsContaining(
            'No proof directory found for hash',
          ).where((log) => log.level == LogLevel.warning),
          isEmpty,
        );
        expect(
          _latestLogContaining('No proof directory found for hash')?.level,
          LogLevel.debug,
        );
      },
    );

    test(
      'logs missing proof directory as warning for unexpected post-generation read',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return null;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
        );

        expect(metadata, isNull);
        expect(
          _latestLogContaining('No proof directory found for hash')?.level,
          LogLevel.warning,
        );
      },
    );

    test(
      'logs nonexistent proof directory as debug when missing proof is expected',
      () async {
        final missingProofDir =
            '${Directory.systemTemp.path}/missing-proofmode-$proofHash';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return missingProofDir;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
          warnIfMissing: false,
        );

        expect(metadata, isNull);
        expect(
          _logsContaining(
            'Proof directory does not exist',
          ).where((log) => log.level == LogLevel.warning),
          isEmpty,
        );
        expect(
          _latestLogContaining('Proof directory does not exist')?.level,
          LogLevel.debug,
        );
      },
    );
  });

  group('proofFile C2PA failure handling', () {
    test('skips manifest read after failed signing', () async {
      final directory = await Directory.systemTemp.createTemp(
        'native-proofmode-test-',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final video = File('${directory.path}/video.mp4');
      await video.writeAsBytes(const [1, 2, 3, 4]);

      const generatedProofHash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final proofDir = Directory('${directory.path}/$generatedProofHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$generatedProofHash.asc',
      ).writeAsString('signature');

      final c2paService = _FailingC2paSigningService(video.path);
      NativeProofModeService.c2paSigningServiceFactoryOverride = () =>
          c2paService;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proofModeChannel, (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'getProofDir':
                final args = call.arguments as Map<Object?, Object?>;
                return args['proofHash'] == generatedProofHash
                    ? proofDir.path
                    : null;
              case 'generateProof':
                return generatedProofHash;
              default:
                fail('Unexpected proof mode method call: ${call.method}');
            }
          });

      final proofData = await NativeProofModeService.proofFile(video);

      expect(proofData, isNotNull);
      expect(proofData!.videoHash, generatedProofHash);
      expect(c2paService.readManifestCallCount, 0);
      expect(
        _latestLogContaining(
          'Skipping C2PA manifest read after failed signing (tls)',
        ),
        isNotNull,
      );
    });
  });

  group('proofFile C2PA manifest handling', () {
    test('preserves the active manifest ID from an existing proof', () async {
      final directory = await Directory.systemTemp.createTemp(
        'native-proofmode-existing-test-',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final video = File('${directory.path}/video.mp4');
      await video.writeAsBytes(const [1, 2, 3, 4]);
      final videoHash = await NativeProofModeService.generateSha256FileHash(
        video.path,
      );
      final proofDir = Directory('${directory.path}/$videoHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$videoHash.asc',
      ).writeAsString('signature');

      final c2paService = _ExistingProofC2paSigningService();
      NativeProofModeService.c2paSigningServiceFactoryOverride = () =>
          c2paService;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proofModeChannel, (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'getProofDir':
                return proofDir.path;
              default:
                fail('Unexpected proof mode method call: ${call.method}');
            }
          });

      final proofData = await NativeProofModeService.proofFile(video);

      expect(proofData, isNotNull);
      expect(proofData!.c2paManifestId, 'urn:c2pa:existing');
      expect(c2paService.readManifestCallCount, 1);
      expect(c2paService.signVideoCallCount, 0);
    });

    test('preserves the active manifest ID after generating a proof', () async {
      final directory = await Directory.systemTemp.createTemp(
        'native-proofmode-generated-test-',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final video = File('${directory.path}/video.mp4');
      await video.writeAsBytes(const [1, 2, 3, 4]);
      const generatedProofHash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final proofDir = Directory('${directory.path}/$generatedProofHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$generatedProofHash.asc',
      ).writeAsString('signature');

      final c2paService = _SuccessfulC2paSigningService(video.path);
      NativeProofModeService.c2paSigningServiceFactoryOverride = () =>
          c2paService;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proofModeChannel, (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'getProofDir':
                final args = call.arguments as Map<Object?, Object?>;
                return args['proofHash'] == generatedProofHash
                    ? proofDir.path
                    : null;
              case 'generateProof':
                return generatedProofHash;
              default:
                fail('Unexpected proof mode method call: ${call.method}');
            }
          });

      final proofData = await NativeProofModeService.proofFile(video);

      expect(proofData, isNotNull);
      expect(proofData!.c2paManifestId, 'urn:c2pa:generated');
      expect(c2paService.signVideoCallCount, 1);
      expect(c2paService.readManifestCallCount, 1);
    });
  });

  group('proofFile iOS device attestation', () {
    // Pins the split introduced with per-account App Attest keys: generation
    // runs before the publishing account is fixed, so it cannot mint a payload
    // that binds one. [IosDeviceAttestationService] does that at publish time.
    late Directory directory;
    late File video;
    late Directory proofDir;

    const generatedProofHash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      directory = await Directory.systemTemp.createTemp(
        'native-proofmode-attest-test-',
      );
      video = File('${directory.path}/video.mp4');
      await video.writeAsBytes(const [1, 2, 3, 4]);

      proofDir = Directory('${directory.path}/$generatedProofHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$generatedProofHash.asc',
      ).writeAsString('signature');

      NativeProofModeService.c2paSigningServiceFactoryOverride = () =>
          _SuccessfulC2paSigningService(video.path);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(proofModeChannel, (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'getProofDir':
                final args = call.arguments as Map<Object?, Object?>;
                return args['proofHash'] == generatedProofHash
                    ? proofDir.path
                    : null;
              case 'generateProof':
                return generatedProofHash;
              default:
                fail('Unexpected proof mode method call: ${call.method}');
            }
          });
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(attestationChannel, null);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    test('defers App Attest to publish time', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            attestationChannel,
            (call) async => fail(
              'App Attest must wait for the publishing account to be known',
            ),
          );

      final proofData = await NativeProofModeService.proofFile(video);

      expect(proofData, isNotNull);
      expect(proofData!.videoHash, generatedProofHash);
      expect(proofData.deviceAttestation, isNull);
      expect(
        File('${proofDir.path}/$generatedProofHash.attest').existsSync(),
        isFalse,
      );
    });
  });
}

Iterable<LogEntry> _logsContaining(String message) {
  return LogCaptureService().getRecentLogs().where(
    (log) => log.message.contains(message),
  );
}

LogEntry? _latestLogContaining(String message) {
  final matches = _logsContaining(message);
  return matches.isEmpty ? null : matches.last;
}

class _FailingC2paSigningService extends C2paSigningService {
  _FailingC2paSigningService(this.videoPath);

  final String videoPath;
  int readManifestCallCount = 0;

  @override
  Future<C2paSigningResult> signVideo({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    return C2paSigningResult(
      signedFilePath: this.videoPath,
      success: false,
      error: 'PlatformException(C2PA_ERROR, A TLS error caused the secure connection to fail., null, null)',
      failureReason: C2paSigningFailureReason.tls,
    );
  }

  @override
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    readManifestCallCount += 1;
    return null;
  }
}

class _ExistingProofC2paSigningService extends C2paSigningService {
  int readManifestCallCount = 0;
  int signVideoCallCount = 0;

  @override
  Future<C2paSigningResult> signVideo({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    signVideoCallCount += 1;
    throw StateError('Existing proof must not be signed again');
  }

  @override
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    readManifestCallCount += 1;
    return const ManifestStoreInfo(activeManifest: 'urn:c2pa:existing');
  }
}

class _SuccessfulC2paSigningService extends C2paSigningService {
  _SuccessfulC2paSigningService(this.videoPath);

  final String videoPath;
  int readManifestCallCount = 0;
  int signVideoCallCount = 0;

  @override
  Future<C2paSigningResult> signVideo({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    signVideoCallCount += 1;
    return C2paSigningResult(signedFilePath: this.videoPath, success: true);
  }

  @override
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    readManifestCallCount += 1;
    return const ManifestStoreInfo(activeManifest: 'urn:c2pa:generated');
  }
}
