// ABOUTME: Exercises retained DM videos across the native decoder and real
// ABOUTME: gallery-save boundary, with late replies and private diagnostics.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/encrypted_video_save/encrypted_video_save_cubit.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

class _NoopInitEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

class _GrantedPermissions extends Fake implements PermissionsService {
  @override
  Future<PermissionStatus> checkGalleryStatus() async =>
      PermissionStatus.granted;
}

class _DownloadsPathProvider extends PathProviderPlatform {
  _DownloadsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getDownloadsPath() async => path;
}

DmMessage _message(String id) => DmMessage(
  id: id * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://media.example/video',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00' * 32,
    decryptionNonce: '00' * 12,
    fileHash: 'd' * 64,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const editorChannel = MethodChannel('pro_video_editor');
  const galChannel = MethodChannel('gal');
  late Directory root;
  late DmVideoStore store;
  late ProVideoEditor originalEditor;
  late PathProviderPlatform originalPaths;
  late Uint8List fetchedVideo;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('kept_dm_boundary_');
    originalEditor = ProVideoEditor.instance;
    originalPaths = PathProviderPlatform.instance;
    ProVideoEditor.instance = _NoopInitEditor();
    fetchedVideo = Uint8List.fromList([1, 2, 3]);
    store = DmVideoStore(
      ownerPubkey: 'e' * 64,
      fetchVideo: (_, {maxBytes, timeLimit, limitsApply, stillWanted}) async =>
          fetchedVideo,
      rootDirectory: () async => root,
      maxBytes: 0,
    );
    await LogCaptureService().clearAllLogs();
  });

  // Its own folder for gallery copies, apart from other test files' runs.
  GallerySaveService gallery() => GallerySaveService(
    permissionsService: _GrantedPermissions(),
    copyRoot: () => Directory('${root.path}/gallery_copies'),
  );

  File keptVideo(DmMessage message) => File(
    '${root.path}/${DmVideoStore.dirName}/${'e' * 64}/'
    '${DmVideoStore.videoFileNameFor(message)}',
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(editorChannel, null)
      ..setMockMethodCallHandler(galChannel, null);
    ProVideoEditor.instance = originalEditor;
    PathProviderPlatform.instance = originalPaths;
    debugDefaultTargetPlatformOverride = null;
    await store.dispose();
    await LogCaptureService().clearAllLogs();
    root.deleteSync(recursive: true);
  });

  group('native frame completion', () {
    test(
      'keeps the decoder turn and video leased after the UI deadline',
      () async {
        final nativeStarted = Completer<void>();
        final nativeReply = Completer<Object?>();
        var nativeCalls = 0;
        var activeNative = 0;
        var maxActiveNative = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(editorChannel, (call) async {
              expect(call.method, 'getThumbnails');
              nativeCalls++;
              activeNative++;
              if (activeNative > maxActiveNative) {
                maxActiveNative = activeNative;
              }
              try {
                if (nativeCalls == 1) {
                  nativeStarted.complete();
                  return await nativeReply.future;
                }
                return [
                  Uint8List.fromList([4, 5, 6]),
                ];
              } finally {
                activeNative--;
              }
            });

        final firstMessage = _message('a');
        final first = store.previewFor(firstMessage);
        await nativeStarted.future;
        // The store's ten-second card deadline, not a test delay. The default
        // reader sets none of its own: it waits for the native reply.
        expect(await first, isNull);
        final firstVideo = File(
          '${root.path}/${DmVideoStore.dirName}/${'e' * 64}/'
          '${DmVideoStore.videoFileNameFor(firstMessage)}',
        );
        var secondCompleted = false;
        final second = store.previewFor(_message('f')).then((
          frame,
        ) {
          secondCompleted = true;
          return frame;
        });
        // Longer than its own card deadline, entirely spent in the queue, and
        // past the ten seconds a reader that gave up by itself would wait.
        // Waiting for the result with a test deadline does not release it.
        await second.timeout(
          const Duration(seconds: 11),
          onTimeout: () => null,
        );
        await store.prune();

        File? secondFrame;
        try {
          expect(secondCompleted, isFalse);
          expect(nativeCalls, 1);
          expect(firstVideo.existsSync(), isTrue);
        } finally {
          nativeReply.complete([
            Uint8List.fromList([7, 8, 9]),
          ]);
          secondFrame = await second;
        }
        expect(secondFrame, isNotNull);
        expect(nativeCalls, 2);
        expect(maxActiveNative, 1);
        await store.prune();
        expect(firstVideo.existsSync(), isFalse);
      },
    );
  });

  group('real DM gallery save', () {
    test('hands the gallery a copy not named after the message, and keeps '
        'the video', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      String? galleryPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galChannel, (call) async {
            if (call.method != 'putVideo') return true;
            final args = call.arguments as Map<Object?, Object?>;
            galleryPath = args['path']! as String;
            return null;
          });
      final cubit = EncryptedVideoSaveCubit(
        resolveStore: () => store,
        gallerySaveService: gallery(),
      );
      addTearDown(cubit.close);
      final message = _message('a');

      await cubit.save(message);

      expect(cubit.state.status, DmVideoSaveStatus.saved);
      expect(galleryPath, isNotNull);
      expect(galleryPath, isNot(contains(message.id)));
      expect(galleryPath, isNot(contains(DmVideoStore.dirName)));
      expect(keptVideo(message).existsSync(), isTrue);
    });
  });

  group('real DM gallery-save diagnostics', () {
    for (final fails in [false, true]) {
      test(
        'keeps retained paths out of ${fails ? 'failure' : 'success'} logs',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          String? savedPath;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(galChannel, (call) async {
                if (call.method != 'putVideo') return true;
                final args = call.arguments as Map<Object?, Object?>;
                savedPath = args['path']! as String;
                if (fails) {
                  throw PlatformException(
                    code: 'UNEXPECTED',
                    message: 'Cannot save $savedPath',
                  );
                }
                return null;
              });
          final cubit = EncryptedVideoSaveCubit(
            resolveStore: () => store,
            gallerySaveService: gallery(),
          );
          addTearDown(cubit.close);

          await cubit.save(_message('a'));

          expect(savedPath, isNotNull);
          expect(
            cubit.state.status,
            fails ? DmVideoSaveStatus.failed : DmVideoSaveStatus.saved,
          );
          final logs = LogCaptureService().getRecentLogs();
          expect(
            logs.where((entry) => entry.name == 'GallerySaveService'),
            isNotEmpty,
          );
          for (final entry in logs) {
            final text = '${entry.message} ${entry.error} ${entry.stackTrace}';
            expect(text, isNot(contains(savedPath)));
            expect(text, isNot(contains('dm_videos')));
          }
        },
      );
    }

    test('keeps a retained file name out of a native failure when handed '
        'the file itself', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      String? fileName;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galChannel, (call) async {
            if (call.method != 'putVideo') return true;
            final args = call.arguments as Map<Object?, Object?>;
            fileName = File(args['path']! as String).uri.pathSegments.last;
            throw PlatformException(
              code: 'UNEXPECTED',
              message: 'The file “$fileName” couldn’t be opened.',
            );
          });
      final video = await store.videoFor(_message('a'));

      final result = await gallery().saveVideoToGallery(
        EditorVideo.file(video.path),
      );

      expect(fileName, DmVideoStore.videoFileNameFor(_message('a')));
      expect(result, isA<GallerySaveFailure>());
      final logs = LogCaptureService().getRecentLogs();
      expect(
        logs.map((entry) => entry.message),
        contains(contains('couldn’t be opened')),
      );
      for (final entry in logs) {
        expect('${entry.message} ${entry.error}', isNot(contains(fileName)));
      }
    });

    test("logs a saved file's size only to one significant figure", () async {
      fetchedVideo = Uint8List(1234567);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            galChannel,
            (call) async => call.method == 'putVideo' ? null : true,
          );
      final cubit = EncryptedVideoSaveCubit(
        resolveStore: () => store,
        gallerySaveService: gallery(),
      );
      addTearDown(cubit.close);

      await cubit.save(_message('a'));

      expect(cubit.state.status, DmVideoSaveStatus.saved);
      final saveLog = LogCaptureService()
          .getRecentLogs()
          .map((entry) => entry.message)
          .singleWhere((message) => message.contains('Gal.putVideo'));
      expect(saveLog, contains('size=1 MB'));
      expect(saveLog, isNot(contains('1234567')));
    });

    test('keeps a name derived from the retained file out of a native '
        'failure when handed the file itself', () async {
      // Android's gallery plugin numbers a copy whose name is taken.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      String? stem;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galChannel, (call) async {
            if (call.method != 'putVideo') return true;
            final args = call.arguments as Map<Object?, Object?>;
            final name = File(args['path']! as String).uri.pathSegments.last;
            stem = name.substring(0, name.lastIndexOf('.'));
            throw PlatformException(
              code: 'UNEXPECTED',
              message: 'Could not insert ${stem}1.mp4',
            );
          });
      final video = await store.videoFor(_message('a'));

      final result = await gallery().saveVideoToGallery(
        EditorVideo.file(video.path),
      );

      expect(stem, 'a' * 64);
      expect(result, isA<GallerySaveFailure>());
      final logs = LogCaptureService().getRecentLogs();
      expect(
        logs.map((entry) => entry.message),
        contains(contains('Could not insert')),
      );
      for (final entry in logs) {
        expect('${entry.message} ${entry.error}', isNot(contains(stem)));
      }
    });

    for (final removeSource in [false, true]) {
      test(
        'redacts desktop fallback ${removeSource ? 'failure' : 'success'}',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          final downloads = Directory('${root.path}/downloads')..createSync();
          PathProviderPlatform.instance = _DownloadsPathProvider(
            downloads.path,
          );
          String? galleryPath;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(galChannel, (call) async {
                if (call.method != 'putVideo') return true;
                final args = call.arguments as Map<Object?, Object?>;
                galleryPath = args['path']! as String;
                // The Downloads fallback copies the kept video, not the
                // gallery's copy.
                if (removeSource) keptVideo(_message('a')).deleteSync();
                throw PlatformException(
                  code: 'UNEXPECTED',
                  message: 'Cannot save $galleryPath',
                );
              });
          final cubit = EncryptedVideoSaveCubit(
            resolveStore: () => store,
            gallerySaveService: gallery(),
          );
          addTearDown(cubit.close);

          await cubit.save(_message('a'));

          expect(galleryPath, isNotNull);
          expect(
            cubit.state.status,
            removeSource ? DmVideoSaveStatus.failed : DmVideoSaveStatus.saved,
          );
          expect(downloads.listSync(), removeSource ? isEmpty : hasLength(1));
          final logs = LogCaptureService().getRecentLogs();
          expect(
            logs.where((entry) => entry.message.contains('Downloads')),
            isNotEmpty,
          );
          for (final entry in logs) {
            final text = '${entry.message} ${entry.error} ${entry.stackTrace}';
            expect(text, isNot(contains(root.path)));
            expect(text, isNot(contains('dm_videos')));
          }
        },
      );
    }
  });
}
