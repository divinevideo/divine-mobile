// ABOUTME: Tests for VideoMetadataScreenPure publish button integration with upload status checking
// ABOUTME: Validates waiting for upload completion, error dialogs, and retry functionality

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'video_metadata_screen_publish_test.mocks.dart';

@GenerateMocks([UploadManager])
void main() {
  group('VideoMetadataScreenPure publish button integration', () {
    late MockUploadManager mockUploadManager;
    late DraftStorageService draftStorage;
    late VineDraft testDraft;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftStorage = DraftStorageService(prefs);

      mockUploadManager = MockUploadManager();
      when(mockUploadManager.isInitialized).thenReturn(true);

      // Create test video file
      final tempDir = Directory.systemTemp.createTempSync(
        'video_metadata_test_',
      );
      final videoFile = File('${tempDir.path}/test_video.mp4');
      await videoFile.writeAsBytes([0, 1, 2, 3]); // Dummy video data

      testDraft = VineDraft.create(
        videoFile: videoFile,
        title: 'Test Video',
        description: 'Test description',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(testDraft);
    });

    testWidgets('Publish pressed when upload complete should immediately publish', (
      tester,
    ) async {
      // Arrange: Upload is already complete (readyToPublish status)
      final upload =
          PendingUpload.create(
            localVideoPath: testDraft.videoFile.path,
            nostrPubkey: 'test_pubkey',
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'test_video_id',
            cdnUrl: 'https://cdn.example.com/test.mp4',
          );

      when(mockUploadManager.getUpload(any)).thenReturn(upload);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraft.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Press publish button
      final publishButton = find.text('Publish');
      expect(publishButton, findsOneWidget);
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      // Assert: Should proceed directly to publishing without showing progress dialog
      // (In actual implementation, this would call videoEventPublisher.publishDirectUpload)
      // For now, we just verify no upload progress dialog is shown
      expect(find.text('Uploading video...'), findsNothing);
    });

    testWidgets(
      'Publish pressed when upload in-progress should show progress dialog and wait',
      (tester) async {
        // Arrange: Upload is currently uploading
        final upload = PendingUpload.create(
          localVideoPath: testDraft.videoFile.path,
          nostrPubkey: 'test_pubkey',
        ).copyWith(status: UploadStatus.uploading, uploadProgress: 0.5);

        when(mockUploadManager.getUpload(any)).thenReturn(upload);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWithValue(mockUploadManager),
            ],
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: testDraft.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Press publish button
        final publishButton = find.text('Publish');
        await tester.tap(publishButton);
        await tester.pump(); // Pump once to trigger dialog

        // Assert: Should show upload progress dialog
        expect(find.text('Uploading video...'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
      },
    );

    testWidgets(
      'Publish pressed when upload failed should show error dialog with retry option',
      (tester) async {
        // Arrange: Upload has failed
        final upload = PendingUpload.create(
          localVideoPath: testDraft.videoFile.path,
          nostrPubkey: 'test_pubkey',
        ).copyWith(status: UploadStatus.failed, errorMessage: 'Network error');

        when(mockUploadManager.getUpload(any)).thenReturn(upload);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWithValue(mockUploadManager),
            ],
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: testDraft.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Press publish button
        final publishButton = find.text('Publish');
        await tester.tap(publishButton);
        await tester.pump(); // Pump once to trigger dialog

        // Assert: Should show error dialog
        expect(find.textContaining('Upload failed'), findsOneWidget);
        expect(find.textContaining('Network error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets(
      'User retries failed upload should restart upload and show progress dialog',
      (tester) async {
        // Arrange: Upload has failed
        final failedUpload = PendingUpload.create(
          localVideoPath: testDraft.videoFile.path,
          nostrPubkey: 'test_pubkey',
        ).copyWith(status: UploadStatus.failed, errorMessage: 'Network error');

        final retryingUpload = failedUpload.copyWith(
          status: UploadStatus.uploading,
          uploadProgress: 0.1,
        );

        when(mockUploadManager.getUpload(any)).thenReturn(failedUpload);
        when(mockUploadManager.retryUpload(any)).thenAnswer((_) async {
          when(mockUploadManager.getUpload(any)).thenReturn(retryingUpload);
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWithValue(mockUploadManager),
            ],
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: testDraft.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Act: Press publish button (should show error dialog)
        final publishButton = find.text('Publish');
        await tester.tap(publishButton);
        await tester.pump();

        // Press retry button in error dialog
        final retryButton = find.text('Retry');
        expect(retryButton, findsOneWidget);
        await tester.tap(retryButton);
        await tester.pump();

        // Assert: Should restart upload and show progress dialog
        verify(mockUploadManager.retryUpload(any)).called(1);
        expect(find.text('Uploading video...'), findsOneWidget);
      },
    );
  });
}
