import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:db_client/db_client.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show AspectRatio, AudioEvent, DmFileMetadata, DmMessage;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/draft_transfer_service.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockDio extends Mock implements Dio {}

const _sender =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _recipient =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _url = 'https://media.example.test/ciphertext';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory outbox;
  late AppDatabase database;
  late DraftStorageService senderStorage;
  late DraftStorageService recipientStorage;
  late DraftTransferService transfer;

  Map<String, dynamic> history(String text, AudioEvent sound) => {
    'version': '6.5.0',
    'position': 0,
    'references': {'caption': TextLayer(id: 'caption', text: text).toMap()},
    'history': [
      {
        'layers': [
          {'id': 'caption'},
        ],
        'meta': {
          'audio': [sound.toJson()],
        },
      },
    ],
  };

  String displayedText(DivineVideoDraft draft) {
    final restored = ImportStateHistory.fromMap(
      draft.editorStateHistory,
      configs: ImportEditorConfigs(
        widgetLoader: (id, {meta}) => const SizedBox(),
      ),
    );
    return restored.stateHistory[restored.editorPosition].layers
        .whereType<TextLayer>()
        .single
        .text;
  }

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
    registerFallbackValue((int received, int total) {});
  });

  setUp(() async {
    final root = Directory.systemTemp.createTempSync('draft-transfer-');
    directory = Directory(p.join(root.path, 'documents'))..createSync();
    outbox = Directory(p.join(root.path, 'outbox'))..createSync();
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProviderPlatform()
      ..setApplicationDocumentsPath(directory.path)
      ..setTemporaryPath(outbox.path);
    database = AppDatabase.test(NativeDatabase.memory());
    DraftStorageService storage(String owner) => DraftStorageService(
      draftsDao: database.draftsDao,
      clipsDao: database.clipsDao,
      ownerPubkey: owner,
    );
    senderStorage = storage(_sender);
    recipientStorage = storage(_recipient);
    transfer = DraftTransferService(documentsPath: directory.path);
    addTearDown(() async {
      await database.close();
      PathProviderPlatform.instance = previous;
      await root.delete(recursive: true);
    });
  });

  File document(String name, List<int> bytes) {
    final file = File(p.join(directory.path, name));
    file.parent.createSync(recursive: true);
    return file..writeAsBytesSync(bytes);
  }

  DivineVideoDraft makeDraft() {
    final clip = document('camera.mp4', [1, 2, 3]);
    final still = document('frame.jpg', [4, 5]);
    final audio = document(p.join(voiceOverRecordingsDirName, 'voice.m4a'), [
      6,
      7,
    ]);
    final sound = AudioEvent.fromLocalImport(
      id: 'local_import_voice',
      filePath: audio.path,
      createdAt: 1,
      title: 'Voice-over',
      mimeType: 'audio/mp4',
      duration: 4,
    );
    return DivineVideoDraft.create(
      id: 'sender-draft',
      clips: [
        DivineVideoClip(
          id: 'camera',
          video: EditorVideo.file(clip.path),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime.utc(2026),
          targetAspectRatio: AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          trimStart: const Duration(seconds: 1),
          trimEnd: const Duration(seconds: 4),
          volume: 0.4,
          recordingSha256: 'a' * 64,
        ),
        DivineVideoClip(
          id: 'stop-motion',
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.utc(2026),
          targetAspectRatio: AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          stopMotionFrames: [
            StopMotionClipFrame(
              path: still.path,
              duration: const Duration(seconds: 1),
            ),
          ],
        ),
      ],
      title: 'Work in progress',
      description: 'First cut',
      hashtags: {'editing'},
      selectedApproach: 'camera',
      editorStateHistory: history('Original caption', sound),
      editorEditingParameters: {
        'meta': {
          'audio': [sound.toJson()],
        },
      },
      selectedSound: sound,
      collaboratorPubkeys: {_recipient},
      scheduledAt: DateTime.utc(2026, 12),
    );
  }

  Future<Uint8List> encryptedDownload(File project) async {
    final encryption = DmVideoEncryption();
    final encrypted = await encryption.encryptFile(project);
    final bytes = await encrypted.ciphertextFile.readAsBytes();
    final dio = _MockDio();
    when(() => dio.options).thenReturn(BaseOptions());
    when(
      () => dio.get<List<int>>(
        _url,
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
        onReceiveProgress: any(named: 'onReceiveProgress'),
      ),
    ).thenAnswer(
      (_) async => Response<List<int>>(
        requestOptions: RequestOptions(path: _url),
        statusCode: 200,
        data: bytes,
      ),
    );
    return DmVideoDecryptor(dio: dio).decrypt(
      DmMessage(
        id: '1' * 64,
        conversationId: 'feedback-chat',
        senderPubkey: _sender,
        content: _url,
        createdAt: 1,
        giftWrapId: '2' * 64,
        messageKind: 15,
        fileMetadata: DmFileMetadata(
          fileType: DmFileMetadata.editableDraftMimeType,
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: encrypted.key,
          decryptionNonce: encrypted.nonce,
          fileHash: encrypted.ciphertextHash,
          fileSize: encrypted.ciphertextSize,
        ),
      ),
      editableDraft: true,
    );
  }

  test(
    'encrypted project round trips, opens in the editor, edits and returns',
    () async {
      final original = makeDraft();
      expect(displayedText(original), 'Original caption');
      await senderStorage.saveDraft(original);
      final project = await transfer.exportDraft(
        original,
        temporaryDirectory: outbox,
      );
      final imported = await transfer.importDraft(
        messageId: '1' * 64,
        senderPubkey: _sender,
        storage: recipientStorage,
        download: () => encryptedDownload(project),
        stillWanted: () => true,
      );

      expect(imported.id, isNot(original.id));
      expect(await senderStorage.getDraftById(imported.id), isNull);
      final opened = (await recipientStorage.getDraftById(imported.id))!;
      expect(opened.canPost, isTrue);
      expect(opened.publishStatus, PublishStatus.draft);
      expect(opened.collaboratorPubkeys, isEmpty);
      expect(opened.scheduledAt, isNull);
      expect(opened.clips.first.recordingSha256, isNull);
      expect(opened.clips.first.sourceCredits.first.authorPubkey, _sender);
      expect(opened.clips.first.trimStart, const Duration(seconds: 1));
      expect(opened.clips.first.volume, 0.4);
      final copiedVideo = File(opened.clips.first.requireVideo.file!.path);
      expect(
        copiedVideo.path,
        isNot(original.clips.first.requireVideo.file!.path),
      );
      expect(copiedVideo.readAsBytesSync(), [1, 2, 3]);
      expect(
        File(opened.clips.last.stopMotionFrames!.single.path).readAsBytesSync(),
        [4, 5],
      );
      expect(displayedText(opened), 'Original caption');
      final copiedAudio = opened.selectedSound!;
      expect(
        copiedAudio.localFilePath,
        isNot(original.selectedSound!.localFilePath),
      );
      expect(File(copiedAudio.localFilePath!).readAsBytesSync(), [6, 7]);

      final editedAudio = copiedAudio.copyWith(volume: 0.2);
      final edited = opened.copyWith(
        clips: [
          opened.clips.first.copyWith(trimStart: const Duration(seconds: 2)),
          opened.clips.last,
        ],
        editorStateHistory: history('Recipient caption', editedAudio),
        selectedSound: editedAudio,
      );
      await recipientStorage.saveDraft(edited);
      final reopened = await transfer.importDraft(
        messageId: '1' * 64,
        senderPubkey: _sender,
        storage: recipientStorage,
        download: () async => throw StateError('Already imported'),
        stillWanted: () => true,
      );
      expect(displayedText(reopened), 'Recipient caption');

      final revision = await transfer.exportDraft(
        reopened,
        temporaryDirectory: outbox,
      );
      final returned = await transfer.importDraft(
        messageId: '2' * 64,
        senderPubkey: _recipient,
        storage: senderStorage,
        download: () => encryptedDownload(revision),
        stillWanted: () => true,
      );
      expect(displayedText(returned), 'Recipient caption');
      expect(returned.clips.first.trimStart, const Duration(seconds: 2));
      expect(returned.selectedSound!.volume, 0.2);
      expect(
        displayedText((await senderStorage.getDraftById(original.id))!),
        'Original caption',
      );
    },
  );

  test('does not export a project with missing source media', () async {
    final draft = makeDraft();
    File(draft.clips.first.requireVideo.file!.path).deleteSync();
    await expectLater(
      transfer.exportDraft(draft, temporaryDirectory: outbox),
      throwsFormatException,
    );
    expect(outbox.listSync(), isEmpty);
  });

  test(
    'rejects project media that names a local file instead of an index',
    () async {
      final draft = makeDraft();
      final package = await transfer.exportDraft(
        draft,
        temporaryDirectory: outbox,
      );
      final bytes = package.readAsBytesSync();
      final header = ByteData.sublistView(bytes, 0, 8);
      final end = 8 + header.getUint32(4);
      final manifest = jsonDecode(utf8.decode(bytes.sublist(8, end))) as Map;
      final timeline = (manifest['project'] as Map)['clips'] as List;
      (timeline.first as Map)['filePath'] = '../private.mp4';
      final json = utf8.encode(jsonEncode(manifest));
      final badHeader = ByteData(8)
        ..setUint32(0, header.getUint32(0))
        ..setUint32(4, json.length);
      final modified = Uint8List.fromList([
        ...badHeader.buffer.asUint8List(),
        ...json,
        ...bytes.sublist(end),
      ]);
      final before = directory.listSync().length;

      await expectLater(
        transfer.importDraft(
          messageId: '3' * 64,
          senderPubkey: _sender,
          storage: recipientStorage,
          download: () async => modified,
          stillWanted: () => true,
        ),
        throwsFormatException,
      );
      expect(await recipientStorage.getDraftCount(), 0);
      expect(directory.listSync().length, before);
    },
  );
}
