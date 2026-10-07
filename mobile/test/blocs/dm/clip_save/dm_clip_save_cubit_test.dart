// ABOUTME: Unit tests for DmClipSaveCubit.
// ABOUTME: A received clip reaches the library only when its C2PA check
// ABOUTME: passes, and the decrypted temp file never outlives the save.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/clip_save/dm_clip_save_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/dm_clip_tag.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDmVideoDecryptor extends Mock implements DmVideoDecryptor {}

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

const _decryptedPath = '/tmp/dm_video_playback/dm_video_clip_0.mp4';
const _manifestId = 'urn:c2pa:3fa85f64-5717-4562-b3fc-2c963f66afa6';
final String _senderPubkey = 'b' * 64;

DmMessage _clipMessage({String? id, String fileType = 'video/mp4'}) =>
    DmMessage(
      id: id ?? 'a' * 64,
      conversationId: 'conversation',
      senderPubkey: _senderPubkey,
      content: 'https://media.divine.video/cipher',
      createdAt: 1757385263,
      giftWrapId: 'c' * 64,
      messageKind: 15,
      tags: [DmClipTag.build(AspectRatio.square)],
      fileMetadata: DmFileMetadata(
        fileType: fileType,
        encryptionAlgorithm: 'aes-gcm',
        decryptionKey: '00',
        decryptionNonce: '00',
        fileHash: 'ab',
      ),
    );

void main() {
  late _MockDmVideoDecryptor decryptor;
  late _MockClipProvenanceVerifier verifier;
  late _MockVideoClipImportService importService;

  setUpAll(() {
    registerFallbackValue(_clipMessage());
    registerFallbackValue(File(''));
  });

  setUp(() {
    decryptor = _MockDmVideoDecryptor();
    verifier = _MockClipProvenanceVerifier();
    importService = _MockVideoClipImportService();
    when(
      () => decryptor.decryptToFile(any()),
    ).thenAnswer((_) async => _decryptedPath);
  });

  DmClipSaveCubit buildCubit() => DmClipSaveCubit(
    decryptor: decryptor,
    verifier: verifier,
    resolveImporter: () => importService.importReceivedClip,
  );

  void stubVerification(ClipProvenanceStatus status) {
    when(() => verifier.verify(_decryptedPath)).thenAnswer(
      (_) async => ClipProvenanceResult(
        status,
        activeManifestId: status == ClipProvenanceStatus.verified
            ? _manifestId
            : null,
      ),
    );
  }

  void stubImportSuccess() {
    when(
      () => importService.importReceivedClip(
        source: any(named: 'source'),
        messageId: any(named: 'messageId'),
        senderPubkey: any(named: 'senderPubkey'),
        c2paManifestId: any(named: 'c2paManifestId'),
        targetAspectRatio: any(named: 'targetAspectRatio'),
      ),
    ).thenAnswer(
      (_) async => VideoClipImportSuccess(
        DivineVideoClip(
          id: 'dm_clip_1',
          video: EditorVideo.file('/documents/dm_clip_1.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime.utc(2026, 9, 28),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      ),
    );
  }

  group(DmClipSaveCubit, () {
    group('save', () {
      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'adds a verified clip with its sender, credential and crop',
        setUp: () {
          stubVerification(ClipProvenanceStatus.verified);
          stubImportSuccess();
        },
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage()),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.saved),
        ],
        verify: (_) {
          final source =
              verify(
                    () => importService.importReceivedClip(
                      source: captureAny(named: 'source'),
                      messageId: any(named: 'messageId'),
                      senderPubkey: _senderPubkey,
                      c2paManifestId: _manifestId,
                      targetAspectRatio: AspectRatio.square,
                    ),
                  ).captured.single
                  as File;
          expect(source.path, equals(_decryptedPath));
          verify(() => decryptor.deleteClip(_decryptedPath)).called(1);
        },
      );

      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'keeps a clip that fails the check out of the library',
        setUp: () => stubVerification(ClipProvenanceStatus.untrustedSigner),
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage()),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.notVerified),
        ],
        verify: (_) {
          verifyNever(
            () => importService.importReceivedClip(
              source: any(named: 'source'),
              messageId: any(named: 'messageId'),
              senderPubkey: any(named: 'senderPubkey'),
              c2paManifestId: any(named: 'c2paManifestId'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
            ),
          );
          verify(() => decryptor.deleteClip(_decryptedPath)).called(1);
        },
      );

      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'reports a check that could not run without adding the clip',
        setUp: () => stubVerification(ClipProvenanceStatus.unavailable),
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage()),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.checkUnavailable),
        ],
        verify: (_) => verifyNever(
          () => importService.importReceivedClip(
            source: any(named: 'source'),
            messageId: any(named: 'messageId'),
            senderPubkey: any(named: 'senderPubkey'),
            c2paManifestId: any(named: 'c2paManifestId'),
            targetAspectRatio: any(named: 'targetAspectRatio'),
          ),
        ),
      );

      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'fails when the clip cannot be decrypted',
        setUp: () => when(() => decryptor.decryptToFile(any())).thenThrow(
          const DmVideoUnavailableException(
            'ciphertext hash does not match the x tag',
          ),
        ),
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage()),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.failed),
        ],
        errors: () => [isA<DmVideoUnavailableException>()],
        verify: (_) => verifyNever(() => verifier.verify(any())),
      );

      test('adds the clip to the library of the account that asked, even '
          'when the account switches during the check', () async {
        final verification = Completer<ClipProvenanceResult>();
        when(
          () => verifier.verify(_decryptedPath),
        ).thenAnswer((_) => verification.future);
        stubImportSuccess();
        final otherAccountImport = _MockVideoClipImportService();
        var signedIn = importService;
        final cubit = DmClipSaveCubit(
          decryptor: decryptor,
          verifier: verifier,
          resolveImporter: () => signedIn.importReceivedClip,
        );
        addTearDown(cubit.close);

        final outcome = cubit.save(_clipMessage());
        await pumpEventQueue();
        signedIn = otherAccountImport;
        verification.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );

        expect(await outcome, equals(DmClipSaveStatus.saved));
        verify(
          () => importService.importReceivedClip(
            source: any(named: 'source'),
            messageId: any(named: 'messageId'),
            senderPubkey: _senderPubkey,
            c2paManifestId: _manifestId,
            targetAspectRatio: AspectRatio.square,
          ),
        ).called(1);
        verifyZeroInteractions(otherAccountImport);
      });

      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'reports the check as unavailable when the credit cannot be resolved',
        setUp: () {
          stubVerification(ClipProvenanceStatus.verified);
          when(
            () => importService.importReceivedClip(
              source: any(named: 'source'),
              messageId: any(named: 'messageId'),
              senderPubkey: any(named: 'senderPubkey'),
              c2paManifestId: any(named: 'c2paManifestId'),
              targetAspectRatio: any(named: 'targetAspectRatio'),
            ),
          ).thenAnswer(
            (_) async => const VideoClipImportFailure(
              VideoClipImportFailureReason.sourceLookupFailed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage()),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.checkUnavailable),
        ],
      );

      blocTest<DmClipSaveCubit, DmClipSaveState>(
        'refuses a file type the C2PA reader is not given',
        build: buildCubit,
        act: (cubit) => cubit.save(_clipMessage(fileType: 'video/webm')),
        expect: () => const [
          DmClipSaveState(status: DmClipSaveStatus.checking),
          DmClipSaveState(status: DmClipSaveStatus.notVerified),
        ],
        verify: (_) => verifyNever(() => decryptor.decryptToFile(any())),
      );

      test('checks a second video while the first is still checking', () async {
        const secondPath = '/tmp/dm_video_playback/dm_video_clip_1.mp4';
        final second = _clipMessage(id: 'e' * 64);
        final firstCheck = Completer<ClipProvenanceResult>();
        when(() => decryptor.decryptToFile(any())).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.single as DmMessage).id ==
                  second.id
              ? secondPath
              : _decryptedPath,
        );
        when(
          () => verifier.verify(_decryptedPath),
        ).thenAnswer((_) => firstCheck.future);
        when(() => verifier.verify(secondPath)).thenAnswer(
          (_) async =>
              const ClipProvenanceResult(ClipProvenanceStatus.untrustedSigner),
        );
        stubImportSuccess();
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final firstOutcome = cubit.save(_clipMessage());
        await pumpEventQueue();
        final secondOutcome = await cubit.save(second);
        firstCheck.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );

        expect(secondOutcome, equals(DmClipSaveStatus.notVerified));
        expect(await firstOutcome, equals(DmClipSaveStatus.saved));
      });

      test('finishes the save and returns its outcome after close', () async {
        final verification = Completer<ClipProvenanceResult>();
        when(
          () => verifier.verify(_decryptedPath),
        ).thenAnswer((_) => verification.future);
        stubImportSuccess();
        final cubit = buildCubit();

        final outcome = cubit.save(_clipMessage());
        await pumpEventQueue();
        await cubit.close();
        verification.complete(
          const ClipProvenanceResult(
            ClipProvenanceStatus.verified,
            activeManifestId: _manifestId,
          ),
        );

        expect(await outcome, equals(DmClipSaveStatus.saved));
        verify(
          () => importService.importReceivedClip(
            source: any(named: 'source'),
            messageId: any(named: 'messageId'),
            senderPubkey: _senderPubkey,
            c2paManifestId: _manifestId,
            targetAspectRatio: AspectRatio.square,
          ),
        ).called(1);
      });
    });
  });
}
