// ABOUTME: Tests C2PA signing failure handling and derived-file re-signing
// ABOUTME: Covers typed failures, manifest gates, and parent ingredients

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

/// Any non-empty token: without one the service never reaches [C2pa].
const _testSigningToken = 'test-signing-token';

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
      service = C2paSigningService(
        signingToken: _testSigningToken,
        c2pa: mockC2pa,
      );
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

    void stubSourcesAttested({Set<String> unattested = const {}}) {
      when(() => mockC2pa.readManifestFromFile(any())).thenAnswer(
        (invocation) async =>
            unattested.contains(invocation.positionalArguments.single)
            ? const ManifestStoreInfo()
            : const ManifestStoreInfo(activeManifest: 'urn:c2pa:x'),
      );
    }

    _MockManifestBuilder stubBuilder({required List<int> signedBytes}) {
      final builder = _MockManifestBuilder();
      when(() => mockC2pa.createBuilder(any()))
          .thenAnswer((_) async => builder);
      when(
        () => builder.addIngredientFromFile(
          path: any(named: 'path'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => builder.signFile(
          sourcePath: any(named: 'sourcePath'),
          destPath: any(named: 'destPath'),
          signer: any(named: 'signer'),
        ),
      ).thenAnswer((invocation) async {
        File(
          invocation.namedArguments[#destPath] as String,
        ).writeAsBytesSync(signedBytes);
      });
      return builder;
    }

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
          signingToken: _testSigningToken,
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
            signingToken: _testSigningToken,
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
          final native = _HeldWritingC2pa();
          final slowService = C2paSigningService(
            signingToken: _testSigningToken,
            c2pa: native,
            signingTimeout: const Duration(milliseconds: 10),
          );

          final result = await slowService.signVideoInPlace(
            videoPath: video.path,
          );
          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.network);

          expect(native.outputPath, isNotNull);
          final removed = video.parent
              .watch(events: FileSystemEvent.delete)
              .firstWhere((event) => event.path == native.outputPath);
          native.release.complete();
          await removed;

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
            signingToken: _testSigningToken,
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
            signingToken: _testSigningToken,
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
          final service = C2paSigningService(
            signingToken: _testSigningToken,
            c2pa: c2pa,
          );

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

      test('signs with the token the service was built with', () async {
        final video = writeFile('video.mp4', const [0, 1, 2, 3]);
        final c2pa = _WritingC2pa(const [7, 8, 9]);
        final service = C2paSigningService(
          signingToken: _testSigningToken,
          c2pa: c2pa,
        );

        await service.signVideoInPlace(videoPath: video.path);

        expect(
          c2pa.lastSigner,
          isA<RemoteSigner>().having(
            (signer) => signer.bearerToken,
            'bearerToken',
            _testSigningToken,
          ),
        );
      });

      test(
        'does not contact the signer in a build without a token',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final tokenless = C2paSigningService(
            c2pa: mockC2pa,
            signingToken: '',
          );

          final result = await tokenless.signVideoInPlace(
            videoPath: video.path,
          );

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.missingToken);
          expect(result.signedFilePath, video.path);
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          verifyZeroInteractions(mockC2pa);
        },
      );

      test('treats a whitespace-only token as no token', () async {
        final video = writeFile('video.mp4', const [0, 1, 2, 3]);
        final blank = C2paSigningService(c2pa: mockC2pa, signingToken: ' \n');

        final result = await blank.signVideoInPlace(videoPath: video.path);

        expect(result.failureReason, C2paSigningFailureReason.missingToken);
        verifyZeroInteractions(mockC2pa);
      });

      test(
        'keeps the recording when the output carries no manifest (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            signingToken: _testSigningToken,
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
            signingToken: _testSigningToken,
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
          // How a signed file reads back once its media bytes change: the
          // untrusted-credential finding every ProofSign file carries, plus a
          // hash mismatch, which is the actual evidence of breakage.
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            signingToken: _testSigningToken,
            c2pa: _WritingC2pa(
              const [7, 8, 9],
              manifest: const ManifestStoreInfo(
                activeManifest: 'urn:c2pa:broken',
                validationErrors: [
                  ValidationError(
                    code: 'signingCredential.untrusted',
                    message: 'signing certificate untrusted',
                  ),
                  ValidationError(
                    code: 'assertion.bmffHash.mismatch',
                    message: 'asset hash error',
                  ),
                ],
                validationStatus: ValidationStatus.invalid,
              ),
            ),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.outputMissing);
          expect(result.error, contains('assertion.bmffHash.mismatch'));
          expect(video.readAsBytesSync(), equals([0, 1, 2, 3]));
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'accepts a genuine ProofSign signature, whose only finding is an '
        'untrusted signing credential (#8799)',
        () async {
          // What the native reader returns for a real Divine-signed capture.
          // The app loads no C2PA trust anchors, so this is the normal
          // success shape, and the plugin still flags it `invalid`.
          final genuine = ManifestStoreInfo.fromMap(const <String, dynamic>{
            'active_manifest': 'urn:c2pa:signed',
            'validation_status': <dynamic>[
              <String, dynamic>{
                'code': 'signingCredential.untrusted',
                'url': 'self#jumbf=/c2pa/urn:c2pa:signed/c2pa.signature',
                'explanation': 'signing certificate untrusted',
              },
            ],
          });
          expect(genuine.validationStatus, ValidationStatus.invalid);
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            signingToken: _testSigningToken,
            c2pa: _WritingC2pa(const [7, 8, 9], manifest: genuine),
          );

          final result = await service.signVideoInPlace(videoPath: video.path);

          expect(result.success, isTrue);
          expect(result.manifest?.activeManifest, 'urn:c2pa:signed');
          expect(video.readAsBytesSync(), equals([7, 8, 9]));
          expect(signedLeftovers(), isEmpty);
        },
      );

      test(
        'keeps the recording when the output cannot be read at all (#8799)',
        () async {
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            signingToken: _testSigningToken,
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
          // `unknown` is what the plugin reports when the native read returned
          // no `validation_status` key at all, e.g. with trust checks off.
          final video = writeFile('video.mp4', const [0, 1, 2, 3]);
          final service = C2paSigningService(
            signingToken: _testSigningToken,
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
      test(
        'does not contact the signer or change either file without a token',
        () async {
          final output = writeFile('out.mp4', const [1, 2, 3]);
          final source = writeFile('src.mp4', const [4, 5, 6]);
          final tokenless = C2paSigningService(
            c2pa: mockC2pa,
            signingToken: '',
          );

          final result = await tokenless.resignDerived(
            outputPath: output.path,
            sourcePath: source.path,
            action: C2paEditActions.edited,
          );

          expect(result.success, isFalse);
          expect(result.failureReason, C2paSigningFailureReason.missingToken);
          expect(result.signedFilePath, output.path);
          expect(output.readAsBytesSync(), equals([1, 2, 3]));
          expect(source.readAsBytesSync(), equals([4, 5, 6]));
          verifyZeroInteractions(mockC2pa);
        },
      );

      test(
        'records why a derived re-sign was skipped without a token',
        () async {
          await LogCaptureService().clearAllLogs();
          addTearDown(LogCaptureService().clearAllLogs);
          final output = writeFile('out.mp4', const [1, 2, 3]);
          final source = writeFile('src.mp4', const [4, 5, 6]);
          final tokenless = C2paSigningService(
            c2pa: mockC2pa,
            signingToken: '',
          );

          await tokenless.resignDerived(
            outputPath: output.path,
            sourcePath: source.path,
            action: C2paEditActions.edited,
          );

          expect(
            LogCaptureService().getRecentLogs().map((entry) => entry.message),
            contains(contains('no signing token')),
          );
        },
      );

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

      test('carries the source manifest forward: the source file as a '
          'parentOf ingredient, an edit action, and the signed copy in '
          'place of the output', () async {
        stubSourcesAttested();
        final builder = stubBuilder(signedBytes: const [9, 9, 9, 9, 9]);
        final output = writeFile('out.mp4', const [1, 2, 3]);
        final source = writeFile('src.mp4', const [4, 5, 6]);

        final result = await service.resignDerived(
          outputPath: output.path,
          sourcePath: source.path,
          action: C2paEditActions.edited,
        );

        expect(result.success, isTrue);
        final ingredient =
            verify(
                  () => builder.addIngredientFromFile(
                    path: source.path,
                    config: captureAny(named: 'config'),
                  ),
                ).captured.single
                as IngredientConfig;
        expect(ingredient.relationship, Relationship.parentOf);
        final recordedAction =
            verify(() => builder.addAction(captureAny())).captured.single
                as ActionConfig;
        // Literal token: pins the protocol surface, not just the constant.
        expect(recordedAction.action, 'c2pa.edited');
        verify(() => builder.setIntent(ManifestIntent.edit)).called(1);
        verifyNever(
          () => builder.addIngredient(
            data: any(named: 'data'),
            mimeType: any(named: 'mimeType'),
            config: any(named: 'config'),
          ),
        );
        verify(builder.dispose).called(1);
        expect(output.readAsBytesSync(), equals([9, 9, 9, 9, 9]));
        expect(signedLeftovers(), isEmpty);
      });

      test(
        'leaves the derived file untouched when signing writes nothing',
        () async {
          stubSourcesAttested();
          final builder = stubBuilder(signedBytes: const []);
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
          expect(signedLeftovers(), isEmpty);
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

    group('signEditInPlace', () {
      test('signs several videos as a composite of their captures', () async {
        stubSourcesAttested();
        final builder = stubBuilder(signedBytes: const [7, 7, 7]);
        final output = writeFile('merged.mp4', const [1]);
        final first = writeFile('a.mp4', const [2]);
        final second = writeFile('b.mp4', const [3]);

        final result = await service.signEditInPlace(
          outputPath: output.path,
          sources: [
            C2paEditSource(path: first.path),
            C2paEditSource(path: second.path),
          ],
        );

        expect(result.success, isTrue);
        verify(
          () => builder.setIntent(
            ManifestIntent.create,
            DigitalSourceType.compositeCapture,
          ),
        ).called(1);
        final configs = verify(
          () => builder.addIngredientFromFile(
            path: any(named: 'path'),
            config: captureAny(named: 'config'),
          ),
        ).captured.cast<IngredientConfig>();
        expect(
          configs.map((config) => config.relationship),
          everyElement(Relationship.componentOf),
        );
        expect(configs, hasLength(2));
      });

      test('signs nothing when a source video carries no manifest', () async {
        final output = writeFile('edited.mp4', const [1, 2]);
        final source = writeFile('unsigned.mp4', const [3]);
        stubSourcesAttested(unattested: {source.path});

        final result = await service.signEditInPlace(
          outputPath: output.path,
          sources: [C2paEditSource(path: source.path)],
        );

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          C2paSigningFailureReason.sourceUnattested,
        );
        verifyNever(() => mockC2pa.createBuilder(any()));
        expect(output.readAsBytesSync(), equals([1, 2]));
      });

      test('declares an image without a manifest instead of embedding it, and '
          'records who made the edit', () async {
        final output = writeFile('keyed.mp4', const [1]);
        final video = writeFile('take.mp4', const [2]);
        final backdrop = writeFile('backdrop.png', const [3]);
        stubSourcesAttested(unattested: {backdrop.path});
        final builder = stubBuilder(signedBytes: const [8]);

        final result = await service.signEditInPlace(
          outputPath: output.path,
          sources: [
            C2paEditSource(path: video.path),
            C2paEditSource(path: backdrop.path, kind: C2paSourceKind.image),
          ],
          creatorBindingAssertion: const NostrCreatorBindingAssertion(
            assertionLabel: 'video.divine.nostr.creator_binding',
            payloadJson: '{"pubkey":"abc","signature":"sig"}',
            signature: 'sig',
            pubkey: 'abc',
          ),
        );

        expect(result.success, isTrue);
        verify(
          () => builder.addIngredientFromFile(
            path: video.path,
            config: any(named: 'config'),
          ),
        ).called(1);
        verifyNever(
          () => builder.addIngredientFromFile(
            path: backdrop.path,
            config: any(named: 'config'),
          ),
        );
        final manifest = jsonDecode(
          verify(
                () => mockC2pa.createBuilder(captureAny()),
              ).captured.single
              as String,
        ) as Map<String, dynamic>;
        final ingredients = manifest['ingredients'] as List<dynamic>;
        expect(
          ingredients.single,
          allOf(
            containsPair('title', 'backdrop.png'),
            containsPair('relationship', 'componentOf'),
          ),
        );
        expect(
          (manifest['assertions'] as List<dynamic>).map(
            (assertion) => (assertion as Map<String, dynamic>)['label'],
          ),
          contains('video.divine.nostr.creator_binding'),
        );
      });
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
/// writes [destPath] after its gate opens, leaving an orphan the service must clean
/// up because it already bailed with a [TimeoutException] (#6058).
class _HeldWritingC2pa extends C2pa {
  final release = Completer<void>();
  String? outputPath;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    outputPath = destPath;
    await release.future;
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
  C2paSigner? lastSigner;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    lastSigner = signer;
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
