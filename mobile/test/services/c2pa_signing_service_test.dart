// ABOUTME: Tests C2PA signing failure handling and derived-file re-signing
// ABOUTME: Covers typed failures, manifest gates, and parent ingredients

import 'dart:async';
import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockC2pa extends Mock implements C2pa {}

class _MockManifestBuilder extends Mock implements ManifestBuilder {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const IngredientConfig());
    registerFallbackValue(const ActionConfig(action: 'c2pa.edited'));
    registerFallbackValue(RemoteSigner(configurationUrl: ''));
  });

  group(C2paSigningService, () {
    late _MockC2pa mockC2pa;
    late C2paSigningService service;
    late Directory tempDir;

    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Divine',
        packageName: 'app.divine',
        version: '1.2.3',
        buildNumber: '10',
        buildSignature: '',
      );
      mockC2pa = _MockC2pa();
      service = C2paSigningService(c2pa: mockC2pa);
      tempDir = Directory.systemTemp.createTempSync('c2pa_resign_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeFile(String name, List<int> bytes) {
      final file = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
      return file;
    }

    List<String> signedLeftovers() => tempDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.startsWith('c2pa_signed_'))
        .toList();

    group('failure classification', () {
      test('classifies iOS secure connection failures as TLS errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'A TLS error caused the secure connection to fail.',
          ),
        );

        expect(reason, C2paSigningFailureReason.tls);
      });

      test('classifies connection failures as network errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'Connection reset by peer',
          ),
        );

        expect(reason, C2paSigningFailureReason.network);
      });

      test('classifies cannot-connect failures as network errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'Could not connect to the server.',
          ),
        );

        expect(reason, C2paSigningFailureReason.network);
      });

      test('classifies signing timeouts as network errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          TimeoutException('signing timed out'),
        );

        expect(reason, C2paSigningFailureReason.network);
      });

      test('classifies COSE signature failures as signing credentials', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'ERROR',
            message: 'Signature: internal error (COSE signature invalid)',
          ),
        );

        expect(reason, C2paSigningFailureReason.signingCredential);
      });

      test('returns typed failure reason when remote signing throws', () async {
        final video = writeFile('video.mp4', const [0, 1, 2, 3]);
        final failingService = C2paSigningService(
          c2pa: _FailingC2pa(
            PlatformException(
              code: 'C2PA_ERROR',
              message: 'A TLS error caused the secure connection to fail.',
            ),
          ),
        );

        final result = await failingService.signVideoInPlace(
          videoPath: video.path,
        );

        expect(result.success, isFalse);
        expect(result.signedFilePath, video.path);
        expect(result.failureReason, C2paSigningFailureReason.tls);
        expect(result.error, contains('A TLS error caused'));
      });

      test(
        'times out a hung remote-signing call and fails best-effort (#6058)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final hangingService = C2paSigningService(
            c2pa: _HangingC2pa(),
            signingTimeout: const Duration(milliseconds: 10),
          );

          final result = await hangingService.signVideoInPlace(
            videoPath: video.path,
          );

          expect(result.success, isFalse);
          expect(
            result.signedFilePath,
            video.path,
            reason: 'the original file is returned untouched on failure',
          );
          expect(result.failureReason, C2paSigningFailureReason.network);
        },
      );

      test(
        'deletes the orphaned signed file when the native call finishes after '
        'the timeout (#6058)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final slowService = C2paSigningService(
            c2pa: _SlowWritingC2pa(const Duration(milliseconds: 60)),
            signingTimeout: const Duration(milliseconds: 10),
          );

          final result = await slowService.signVideoInPlace(
            videoPath: video.path,
          );
          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.network);

          // The abandoned native call is still running: wait for it to finish
          // writing the signed file and for the cleanup to remove the orphan.
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(
            signedLeftovers(),
            isEmpty,
            reason:
                'a signing call that finishes past the timeout must not leave '
                'a stray c2pa_signed_*.mp4 behind',
          );
        },
      );
    });

    group('signVideoInPlace', () {
      test(
        'deletes the partial output when the native call throws (#7739)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final failingService = C2paSigningService(
            c2pa: _WriteThenThrowC2pa(
              const [7, 7, 7],
              PlatformException(
                code: 'ERROR',
                message: 'Signature: internal error (COSE signature invalid)',
              ),
            ),
          );

          final result = await failingService.signVideoInPlace(
            videoPath: video.path,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            C2paSigningFailureReason.signingCredential,
          );
          expect(result.signedFilePath, video.path);
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          expect(
            signedLeftovers(),
            isEmpty,
            reason:
                'a signing call that throws after writing its output must not '
                'leave a stray c2pa_signed_*.mp4 behind',
          );
        },
      );

      test(
        'does not replace the recording with a zero-byte output (#7739)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final emptyOutputService = C2paSigningService(
            c2pa: _WritingC2pa(const []),
          );

          final result = await emptyOutputService.signVideoInPlace(
            videoPath: video.path,
          );

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(result.signedFilePath, video.path);
          expect(
            video.readAsBytesSync(),
            equals([0, 1, 2, 3]),
            reason:
                'an empty signing output must never overwrite the recording',
          );
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'replaces the original in place and leaves nothing else behind',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final c2pa = _WritingC2pa(const [7, 8, 9, 10, 11]);
          final service = C2paSigningService(c2pa: c2pa);

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isTrue);
          expect(result.error, isNull);
          expect(result.failureReason, isNull);
          expect(result.signedFilePath, video.path);
          expect(video.readAsBytesSync(), equals([7, 8, 9, 10, 11]));
          // No `.old` original, no orphaned `c2pa_signed_*` temp file.
          expect(
            tempDir.listSync().whereType<File>().map(
              (file) => file.uri.pathSegments.last,
            ),
            equals(['video.mp4']),
          );
          // Handed to the caller so ProofMode does not read the same manifest
          // off the same file a second time (#8799).
          expect(result.manifest?.activeManifest, 'urn:c2pa:signed');
          expect(c2pa.readManifestCallCount, 1);
        },
      );

      test(
        'keeps the recording when the output carries no manifest (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            c2pa: _WritingC2pa(const [7, 8, 9], manifest: null),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(result.signedFilePath, video.path);
          expect(result.manifest, isNull);
          expect(
            video.readAsBytesSync(),
            equals([0, 1, 2, 3]),
            reason:
                'a non-empty output that was never stamped must not replace '
                'the only copy of the recording',
          );
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'keeps the recording when the manifest has no active claim (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            c2pa: _WritingC2pa(
              const [7, 8, 9],
              manifest: const ManifestStoreInfo(),
            ),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'keeps the recording when the manifest fails validation (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            c2pa: _WritingC2pa(
              const [7, 8, 9],
              manifest: const ManifestStoreInfo(
                activeManifest: 'urn:c2pa:broken',
                validationErrors: [
                  ValidationError(
                    code: 'signingCredential.untrusted',
                    message: 'untrusted signer',
                  ),
                ],
                validationStatus: ValidationStatus.invalid,
              ),
            ),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'keeps the recording when the output cannot be read at all (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            c2pa: _UnreadableManifestC2pa(const [7, 8, 9]),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'accepts an unknown validation status, which is a clean read (#8799)',
        () async {
          // `unknown` is what the library reports when the native read
          // returned no `validation_status` key — the ordinary success shape.
          // Only `invalid` is positive evidence the output is broken, so
          // rejecting `unknown` would discard correctly signed recordings.
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            c2pa: _WritingC2pa(
              const [7, 8, 9],
              manifest: const ManifestStoreInfo(
                activeManifest: 'urn:c2pa:signed',
              ),
            ),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isTrue);
          expect(video.readAsBytesSync(), equals([7, 8, 9]));
        },
      );
    });

    group('resignDerived', () {
      test('skips re-signing and leaves the file untouched when the source '
          'carries no manifest', () async {
        when(
          () => mockC2pa.readManifestFromFile(any()),
        ).thenAnswer((_) async => const ManifestStoreInfo());

        final output = writeFile('out.mp4', const [1, 2, 3]);
        final source = writeFile('src.mp4', const [4, 5, 6]);

        final result = await service.resignDerived(
          outputPath: output.path,
          sourcePath: source.path,
          action: C2paEditActions.edited,
        );

        expect(result.success, isFalse);
        verifyNever(() => mockC2pa.createBuilder(any()));
        expect(output.readAsBytesSync(), equals([1, 2, 3]));
      });

      test('carries the source manifest forward: parentOf ingredient, edit '
          'action, and writes the signed bytes back in place', () async {
        when(() => mockC2pa.readManifestFromFile(any())).thenAnswer(
          (_) async => const ManifestStoreInfo(activeManifest: 'urn:c2pa:x'),
        );

        final builder = _MockManifestBuilder();
        when(
          () => mockC2pa.createBuilder(any()),
        ).thenAnswer((_) async => builder);
        when(
          () => builder.addIngredient(
            data: any(named: 'data'),
            mimeType: any(named: 'mimeType'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async {});
        final signedBytes = Uint8List.fromList(const [9, 9, 9, 9, 9]);
        when(
          () => builder.sign(
            sourceData: any(named: 'sourceData'),
            mimeType: any(named: 'mimeType'),
            signer: any(named: 'signer'),
          ),
        ).thenAnswer(
          (_) async =>
              BuilderSignResult(signedData: signedBytes, manifestSize: 5),
        );

        final output = writeFile('out.mp4', const [1, 2, 3]);
        final source = writeFile('src.mp4', const [4, 5, 6]);

        final result = await service.resignDerived(
          outputPath: output.path,
          sourcePath: source.path,
          action: C2paEditActions.edited,
        );

        expect(result.success, isTrue);

        final ingredientConfig =
            verify(
                  () => builder.addIngredient(
                    data: any(named: 'data'),
                    mimeType: any(named: 'mimeType'),
                    config: captureAny(named: 'config'),
                  ),
                ).captured.single
                as IngredientConfig;
        expect(ingredientConfig.relationship, Relationship.parentOf);

        final recordedAction =
            verify(() => builder.addAction(captureAny())).captured.single
                as ActionConfig;
        // Literal token: pins the protocol surface, not just the constant.
        expect(recordedAction.action, 'c2pa.edited');

        verify(() => builder.setIntent(ManifestIntent.edit)).called(1);
        verify(builder.dispose).called(1);
        expect(output.readAsBytesSync(), equals(signedBytes));
      });

      test(
        'leaves the derived file untouched when signing returns empty bytes',
        () async {
          when(() => mockC2pa.readManifestFromFile(any())).thenAnswer(
            (_) async => const ManifestStoreInfo(activeManifest: 'urn:c2pa:x'),
          );

          final builder = _MockManifestBuilder();
          when(
            () => mockC2pa.createBuilder(any()),
          ).thenAnswer((_) async => builder);
          when(
            () => builder.addIngredient(
              data: any(named: 'data'),
              mimeType: any(named: 'mimeType'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => builder.sign(
              sourceData: any(named: 'sourceData'),
              mimeType: any(named: 'mimeType'),
              signer: any(named: 'signer'),
            ),
          ).thenAnswer(
            (_) async =>
                BuilderSignResult(signedData: Uint8List(0), manifestSize: 0),
          );

          final output = writeFile('out.mp4', const [1, 2, 3]);
          final source = writeFile('src.mp4', const [4, 5, 6]);

          final result = await service.resignDerived(
            outputPath: output.path,
            sourcePath: source.path,
            action: C2paEditActions.edited,
          );

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(output.readAsBytesSync(), equals([1, 2, 3]));
          verify(builder.dispose).called(1);
        },
      );

      test(
        'returns failure without signing when the output does not exist',
        () async {
          final result = await service.resignDerived(
            outputPath: '${tempDir.path}/missing.mp4',
            sourcePath: '${tempDir.path}/also-missing.mp4',
            action: C2paEditActions.edited,
          );

          expect(result.success, isFalse);
          verifyNever(() => mockC2pa.readManifestFromFile(any()));
          verifyNever(() => mockC2pa.createBuilder(any()));
        },
      );
    });
  });
}

class _FailingC2pa extends C2pa {
  _FailingC2pa(this.error);

  final Object error;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    throw error;
  }
}

/// Simulates a remote-signing call that never returns — the network-hang
/// failure mode that [C2paSigningService]'s timeout guards against (#6058).
class _HangingC2pa extends C2pa {
  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) => Completer<void>().future;
}

/// Simulates a remote-signing call that outlives the timeout: it eventually
/// writes [destPath] after [delay], leaving an orphan the service must clean
/// up because it already bailed with a [TimeoutException] (#6058).
class _SlowWritingC2pa extends C2pa {
  _SlowWritingC2pa(this.delay);

  final Duration delay;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    await Future<void>.delayed(delay);
    File(destPath).writeAsBytesSync(const [7, 7, 7]);
  }
}

/// Simulates a remote-signing call that fails *after* the native side has
/// already created its output — the leak observed in #7739.
class _WriteThenThrowC2pa extends C2pa {
  _WriteThenThrowC2pa(this.bytes, this.error);

  final List<int> bytes;
  final Object error;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    File(destPath).writeAsBytesSync(bytes);
    throw error;
  }
}

/// Simulates a signing call that writes [bytes] and, on read-back, reports
/// [manifest].
///
/// The manifest matters as much as the bytes: signing reads its own output
/// back before it is allowed to replace the recording, so a fake that reports
/// nothing is a fake whose output must be rejected (#8799).
class _WritingC2pa extends C2pa {
  _WritingC2pa(
    this.bytes, {
    this.manifest = const ManifestStoreInfo(
      activeManifest: 'urn:c2pa:signed',
      validationStatus: ValidationStatus.valid,
    ),
  });

  final List<int> bytes;
  final ManifestStoreInfo? manifest;
  int readManifestCallCount = 0;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    File(destPath).writeAsBytesSync(bytes);
  }

  @override
  Future<ManifestStoreInfo?> readManifestFromFile(
    String path, {
    ReaderOptions options = const ReaderOptions(),
  }) async {
    readManifestCallCount += 1;
    return manifest;
  }
}

/// Simulates an output the native reader cannot parse at all.
class _UnreadableManifestC2pa extends C2pa {
  _UnreadableManifestC2pa(this.bytes);

  final List<int> bytes;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    File(destPath).writeAsBytesSync(bytes);
  }

  @override
  Future<ManifestStoreInfo?> readManifestFromFile(
    String path, {
    ReaderOptions options = const ReaderOptions(),
  }) async {
    throw const FormatException('not a C2PA container');
  }
}
