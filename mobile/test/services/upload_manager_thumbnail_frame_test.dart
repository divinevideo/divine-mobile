// ABOUTME: Pins that an upload's thumbnail goes from the decoded frame to the
// ABOUTME: PUT without a file, so a failed disk write cannot sink the post.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// Not exported from pro_video_editor's barrel — imported via path so we can
// subclass MethodChannelProVideoEditor and skip its EventChannel subscription.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

/// Routes calls through the mocked `pro_video_editor` channel without
/// subscribing to the plugin's EventChannels.
class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

const _thumbnailUrl = 'https://media.divine.video/thumb-1.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadManager default thumbnail extractor', () {
    const editorChannel = MethodChannel('pro_video_editor');
    const connectivityChannel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

    late Directory testDir;
    late PathProviderPlatform originalPathProvider;
    late ProVideoEditor originalProVideoEditor;
    late _MockBlossomUploadService blossom;
    late UploadManager uploadManager;

    setUpAll(() {
      registerFallbackValue(File(''));
      registerFallbackValue(Uint8List(0));
    });

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp(
        'upload_thumbnail_frame_test_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      // The documents directory is never created, so any write into it
      // fails — the way the thumbnail file write failed on iOS 1.0.34.
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(testDir.path)
        ..setApplicationDocumentsPath('${testDir.path}/documents')
        ..setApplicationSupportPath('${testDir.path}/support');
      await Directory('${testDir.path}/support').create(recursive: true);
      await TestHelpers.cleanupHiveBox('pending_uploads');
      await TestHelpers.initHiveHome();

      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(editorChannel, (call) async {
          if (call.method == 'getThumbnails') return [frame];
          return null;
        })
        ..setMockMethodCallHandler(connectivityChannel, (call) async {
          if (call.method == 'check') return ['wifi'];
          return null;
        });

      blossom = _MockBlossomUploadService();
      when(() => blossom.isBlossomEnabled()).thenAnswer((_) async => false);
      when(
        () => blossom.uploadVideoWithResume(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          useBackgroundFirst: any(named: 'useBackgroundFirst'),
          resumableTimeout: any(named: 'resumableTimeout'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'vid-1',
          url: 'https://media.divine.video/vid-1',
          fallbackUrl: 'https://media.divine.video/vid-1',
        ),
      );
      when(
        () => blossom.uploadImageBytes(
          bytes: any(named: 'bytes'),
          nostrPubkey: any(named: 'nostrPubkey'),
          filename: any(named: 'filename'),
          allowResumable: any(named: 'allowResumable'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          url: _thumbnailUrl,
          fallbackUrl: _thumbnailUrl,
        ),
      );

      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: blossom,
        retryConfig: const UploadRetryConfig(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      await uploadManager.initialize();
    });

    tearDown(() async {
      uploadManager.dispose();
      ProVideoEditor.instance = originalProVideoEditor;
      PathProviderPlatform.instance = originalPathProvider;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(editorChannel, null)
        ..setMockMethodCallHandler(connectivityChannel, null);
      await TestHelpers.cleanupHiveBox('pending_uploads');
      await testDir.delete(recursive: true);
    });

    group('startUpload', () {
      test('publishes the thumbnail when the disk refuses a write', () async {
        final videoFile = File('${testDir.path}/video.mp4')
          ..writeAsBytesSync([0, 1, 2, 3]);

        final upload = await uploadManager.startUpload(
          videoFile: videoFile,
          nostrPubkey: 'pubkey-1',
        );

        expect(upload.status, equals(UploadStatus.readyToPublish));
        expect(upload.thumbnailPath, equals(_thumbnailUrl));
        verify(
          () => blossom.uploadImageBytes(
            bytes: frame,
            nostrPubkey: 'pubkey-1',
            filename: 'thumbnail.jpg',
            allowResumable: false,
          ),
        ).called(1);
      });
    });
  });
}
