import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
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
    NativeProofModeService.recordingHashLookup = null;
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

  group('generateSha256FileHash', () {
    test('returns the hex SHA-256 of the file contents', () async {
      final directory = await Directory.systemTemp.createTemp(
        'native-proofmode-hash-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/clip.mp4');
      await file.writeAsString('abc');

      expect(
        await NativeProofModeService.generateSha256FileHash(file.path),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('throws when the file does not exist', () async {
      await expectLater(
        NativeProofModeService.generateSha256FileHash('/no/such/clip.mp4'),
        throwsA(isA<FileSystemException>()),
      );
    });
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
        _latestLogContaining('C2PA signing failed (tls; continuing without)'),
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
      expect(c2paService.signVideoInPlaceCallCount, 0);
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
      expect(c2paService.signVideoInPlaceCallCount, 1);
      // Signing already read the manifest back to decide it was safe to
      // replace the recording, so proofFile reuses that read rather than
      // performing a second one over the same file (#8799).
      expect(c2paService.readManifestCallCount, 0);
    });
  });

  group('proofFile and proofEdit as edits', () {
    const generatedProofHash =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

    late Directory directory;
    late File output;
    late _EditC2paSigningService c2paService;

    DivineVideoClip clipAt(String path, {String? recordingSha256}) =>
        DivineVideoClip(
          id: path,
          video: EditorVideo.file(path),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          recordingSha256: recordingSha256,
        );

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'native-proofmode-edit-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      output = File('${directory.path}/render.mp4');
      await output.writeAsBytes(const [9, 9, 9]);
      final proofDir = Directory('${directory.path}/$generatedProofHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$generatedProofHash.asc',
      ).writeAsString('signature');

      c2paService = _EditC2paSigningService();
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
    });

    test('signs a derived file as an edit, never as a capture', () async {
      const sources = [C2paEditSource(path: '/clips/a.mp4')];

      final proofData = await NativeProofModeService.proofFile(
        output,
        derivedFrom: sources,
      );

      expect(c2paService.signVideoInPlaceCallCount, 0);
      expect(c2paService.editSources, equals([sources]));
      expect(proofData?.c2paManifestId, equals('urn:c2pa:edit'));
      expect(proofData?.unattestedSources, isFalse);
    });

    test('marks a proof whose sources carry no camera proof', () async {
      c2paService.editFailure = C2paSigningFailureReason.sourceUnattested;

      final proofData = await NativeProofModeService.proofFile(
        output,
        derivedFrom: const [C2paEditSource(path: '/clips/gallery.mp4')],
      );

      expect(proofData, isNotNull);
      expect(proofData!.c2paManifestId, isNull);
      expect(proofData.unattestedSources, isTrue);
    });

    test('names every clip, layer clip and other source once', () async {
      const backdrop = C2paEditSource(
        path: '/clips/beach.jpg',
        kind: C2paSourceKind.image,
      );

      await NativeProofModeService.proofEdit(
        output,
        clips: [clipAt('/clips/a.mp4'), clipAt('/clips/a.mp4')],
        layerClips: [clipAt('/clips/b.mp4')],
        otherSources: const [backdrop],
      );

      expect(
        c2paService.editSources.single,
        equals(const [
          C2paEditSource(path: '/clips/a.mp4'),
          C2paEditSource(path: '/clips/b.mp4'),
          backdrop,
        ]),
      );
    });

    test('names no sources when a clip has no media to name', () async {
      final stills = DivineVideoClip(
        id: 'stills',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/stills/a.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        duration: const Duration(milliseconds: 83),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      await NativeProofModeService.proofEdit(
        output,
        clips: [clipAt('/clips/a.mp4'), stills],
      );

      // Signing the attested clip alone would claim the stills came from it.
      expect(c2paService.editSources.single, isEmpty);
    });

    group('signOwnRecordings', () {
      late File recording;
      late String recordingHash;

      setUp(() async {
        recording = File('${directory.path}/recording.mp4');
        await recording.writeAsBytes(const [1, 2, 3]);
        recordingHash = await NativeProofModeService.generateSha256FileHash(
          recording.path,
        );
      });

      test('signs an unsigned recording as a capture', () async {
        await NativeProofModeService.signOwnRecordings([
          clipAt(recording.path, recordingSha256: recordingHash),
        ]);

        expect(c2paService.signVideoInPlaceCallCount, 1);
      });

      test('signs a recording that a merged clip was made from', () async {
        final merged = clipAt('${directory.path}/merged.mp4').copyWith(
          derivedFrom: [
            C2paEditSource(
              path: recording.path,
              recordingSha256: recordingHash,
            ),
          ],
        );

        await NativeProofModeService.signOwnRecordings([merged]);

        expect(c2paService.signVideoInPlaceCallCount, 1);
      });

      test('keeps an edit retryable while its recording is unsigned', () async {
        c2paService.editFailure = C2paSigningFailureReason.sourceUnattested;

        final proofData = await NativeProofModeService.proofEdit(
          output,
          clips: [clipAt(recording.path, recordingSha256: recordingHash)],
        );

        // Signing the recording failed, as it does offline, so the edit is
        // unsigned for now but not footage without a camera proof.
        expect(c2paService.signVideoInPlaceCallCount, 1);
        expect(proofData?.c2paManifestId, isNull);
        expect(proofData?.unattestedSources, isFalse);
      });

      test('leaves a recording that changed since alone', () async {
        await NativeProofModeService.signOwnRecordings([
          clipAt(recording.path, recordingSha256: 'f' * 64),
        ]);

        expect(c2paService.signVideoInPlaceCallCount, 0);
      });

      test('never signs a clip that is not a recording', () async {
        await NativeProofModeService.signOwnRecordings([
          clipAt(recording.path),
        ]);

        expect(c2paService.signVideoInPlaceCallCount, 0);
      });

      test('leaves a recording that is already signed alone', () async {
        c2paService.sourcesWithManifest.add(recording.path);

        await NativeProofModeService.signOwnRecordings([
          clipAt(recording.path, recordingSha256: recordingHash),
        ]);

        expect(c2paService.signVideoInPlaceCallCount, 0);
      });

      group('with hashes from the clip library', () {
        void libraryKnows(String hash) =>
            NativeProofModeService.recordingHashLookup = () async => {
              'recording.mp4': {hash},
            };

        test('signs a recording whose clip lost its hash', () async {
          libraryKnows(recordingHash);

          await NativeProofModeService.signOwnRecordings([
            clipAt(recording.path),
          ]);

          expect(c2paService.signVideoInPlaceCallCount, 1);
        });

        test('leaves a file that no longer matches the hash alone', () async {
          libraryKnows('f' * 64);

          await NativeProofModeService.signOwnRecordings([
            clipAt(recording.path),
          ]);

          expect(c2paService.signVideoInPlaceCallCount, 0);
        });

        test('signs a recording an edit uses as a backdrop', () async {
          libraryKnows(recordingHash);

          await NativeProofModeService.proofEdit(
            output,
            clips: [clipAt('${directory.path}/missing.mp4')],
            otherSources: [C2paEditSource(path: recording.path)],
          );

          expect(c2paService.signVideoInPlaceCallCount, 1);
        });
      });
    });
  });

  group('proofFile creator binding', () {
    const accountBinding = NostrCreatorBindingAssertion(
      assertionLabel: NostrCreatorBindingService.assertionLabel,
      payloadJson: '{"pubkey":"account"}',
      signature: 'account-signature',
      pubkey: 'account',
    );
    const publishBinding = NostrCreatorBindingAssertion(
      assertionLabel: NostrCreatorBindingService.assertionLabel,
      payloadJson: '{"pubkey":"publish"}',
      signature: 'publish-signature',
      pubkey: 'publish',
    );
    const generatedProofHash =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    late File video;
    late _SuccessfulC2paSigningService c2paService;
    late List<String> boundPaths;

    setUp(() async {
      final directory = await Directory.systemTemp.createTemp(
        'native-proofmode-binding-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      video = File('${directory.path}/video.mp4');
      await video.writeAsBytes(const [1, 2, 3, 4]);
      final proofDir = Directory('${directory.path}/$generatedProofHash');
      await proofDir.create();
      await File(
        '${proofDir.path}/$generatedProofHash.asc',
      ).writeAsString('signature');

      c2paService = _SuccessfulC2paSigningService(video.path);
      NativeProofModeService.c2paSigningServiceFactoryOverride = () =>
          c2paService;
      boundPaths = [];
      NativeProofModeService.creatorBindingFactory = (path) async {
        boundPaths.add(path);
        return accountBinding;
      };
      addTearDown(() => NativeProofModeService.creatorBindingFactory = null);

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

    test('embeds the signed-in account in the manifest it signs', () async {
      final proofData = await NativeProofModeService.proofFile(video);

      expect(boundPaths, equals([video.path]));
      expect(c2paService.signedCreatorBinding, same(accountBinding));
      // Only the publish flow reports a binding in the proof metadata, so a
      // recording's proof reads exactly as it did before bindings existed.
      expect(proofData, isNotNull);
      expect(proofData!.hasCreatorIdentityMetadata, isFalse);
    });

    test('signs with the binding the caller passes instead', () async {
      final proofData = await NativeProofModeService.proofFile(
        video,
        creatorBindingAssertion: publishBinding,
      );

      expect(boundPaths, isEmpty);
      expect(c2paService.signedCreatorBinding, same(publishBinding));
      expect(
        proofData?.creatorBindingPayloadJson,
        equals(publishBinding.payloadJson),
      );
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
  Future<C2paSigningResult> signVideoInPlace({
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
  int signVideoInPlaceCallCount = 0;

  @override
  Future<C2paSigningResult> signVideoInPlace({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    signVideoInPlaceCallCount += 1;
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
  int signVideoInPlaceCallCount = 0;
  NostrCreatorBindingAssertion? signedCreatorBinding;

  @override
  Future<C2paSigningResult> signVideoInPlace({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    signVideoInPlaceCallCount += 1;
    signedCreatorBinding = creatorBindingAssertion;
    return C2paSigningResult(
      signedFilePath: this.videoPath,
      success: true,
      manifest: const ManifestStoreInfo(activeManifest: 'urn:c2pa:generated'),
    );
  }

  @override
  Future<ManifestStoreInfo?> readManifest(String filePath) async {
    readManifestCallCount += 1;
    return const ManifestStoreInfo(activeManifest: 'urn:c2pa:generated');
  }
}

class _EditC2paSigningService extends C2paSigningService {
  final editSources = <List<C2paEditSource>>[];
  final sourcesWithManifest = <String>{};
  C2paSigningFailureReason? editFailure;
  int signVideoInPlaceCallCount = 0;

  @override
  Future<C2paSigningResult> signEditInPlace({
    required String outputPath,
    required List<C2paEditSource> sources,
    List<String> actions = const [C2paEditActions.edited],
    NostrCreatorBindingAssertion? creatorBindingAssertion,
  }) async {
    editSources.add(sources);
    final failure = editFailure;
    return failure == null
        ? C2paSigningResult(
            signedFilePath: outputPath,
            success: true,
            manifest: const ManifestStoreInfo(activeManifest: 'urn:c2pa:edit'),
          )
        : C2paSigningResult(
            signedFilePath: outputPath,
            success: false,
            failureReason: failure,
          );
  }

  @override
  Future<C2paSigningResult> signVideoInPlace({
    required String videoPath,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
    signVideoInPlaceCallCount += 1;
    return C2paSigningResult(signedFilePath: videoPath, success: false);
  }

  @override
  Future<ManifestStoreInfo?> readManifest(String filePath) async =>
      sourcesWithManifest.contains(filePath)
      ? const ManifestStoreInfo(activeManifest: 'urn:c2pa:existing')
      : null;
}
