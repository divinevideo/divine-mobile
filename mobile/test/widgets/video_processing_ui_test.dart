// ABOUTME: Tests for video processing UI states and user feedback during upload/processing
// ABOUTME: Validates processing indicators, error states, and user messaging for video uploads

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/widgets/video_processing_status_widget.dart';

@GenerateMocks([UploadManager])
import 'video_processing_ui_test.mocks.dart';

void main() {
  group('VideoProcessingStatusWidget', () {
    late MockUploadManager mockUploadManager;

    setUp(() {
      mockUploadManager = MockUploadManager();
    });

    testWidgets(
      'should show processing indicator when upload is in processing state',
      (tester) async {
        // Create upload with processing state
        final processingUpload = PendingUpload(
          id: 'test_upload_123',
          localVideoPath: '/test/video.mp4',
          title: 'Test Video',
          hashtags: ['test'],
          status: UploadStatus.processing, // Key: processing state
          uploadProgress: 0.9,
          createdAt: DateTime.now(),
          nostrPubkey: 'test_pubkey',
        );

        when(
          mockUploadManager.getUpload('test_upload_123'),
        ).thenReturn(processingUpload);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWith((ref) => mockUploadManager),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: VideoProcessingStatusWidget(uploadId: 'test_upload_123'),
              ),
            ),
          ),
        );

        // Should show processing indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Processing video'), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);

        // Should NOT show error indicators
        expect(find.byIcon(Icons.error), findsNothing);
        expect(find.text('Upload failed'), findsNothing);
      },
    );

    testWidgets(
      'should show progress bar with correct percentage during processing',
      (tester) async {
        final processingUpload = PendingUpload(
          id: 'test_upload_456',
          localVideoPath: '/test/video.mp4',
          title: 'Test Video',
          hashtags: ['test'],
          status: UploadStatus.processing,
          uploadProgress: 0.75, // 75% complete
          createdAt: DateTime.now(),
          nostrPubkey: 'test_pubkey',
        );

        when(
          mockUploadManager.getUpload('test_upload_456'),
        ).thenReturn(processingUpload);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWith((ref) => mockUploadManager),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: VideoProcessingStatusWidget(uploadId: 'test_upload_456'),
              ),
            ),
          ),
        );

        // Find LinearProgressIndicator
        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );

        expect(progressIndicator.value, equals(0.75));
        expect(find.text('75% complete'), findsOneWidget);
      },
    );

    testWidgets('should show success state when processing completes', (
      tester,
    ) async {
      final completedUpload = PendingUpload(
        id: 'test_upload_789',
        localVideoPath: '/test/video.mp4',
        title: 'Test Video',
        hashtags: ['test'],
        status: UploadStatus.readyToPublish, // Completed processing
        uploadProgress: 1.0,
        cdnUrl: 'https://stream.cloudflare.com/test.mp4',
        thumbnailPath: 'https://stream.cloudflare.com/thumb.jpg',
        createdAt: DateTime.now(),
        nostrPubkey: 'test_pubkey',
      );

      when(
        mockUploadManager.getUpload('test_upload_789'),
      ).thenReturn(completedUpload);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWith((ref) => mockUploadManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoProcessingStatusWidget(uploadId: 'test_upload_789'),
            ),
          ),
        ),
      );

      // Should show success indicators
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Processing complete'), findsOneWidget);

      // Should NOT show processing indicators
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    });

    testWidgets('should show error state when processing fails', (
      tester,
    ) async {
      final failedUpload = PendingUpload(
        id: 'test_upload_error',
        localVideoPath: '/test/video.mp4',
        title: 'Test Video',
        hashtags: ['test'],
        status: UploadStatus.failed,
        uploadProgress: 0.5,
        errorMessage: 'Video processing timeout',
        createdAt: DateTime.now(),
        nostrPubkey: 'test_pubkey',
      );

      when(
        mockUploadManager.getUpload('test_upload_error'),
      ).thenReturn(failedUpload);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWith((ref) => mockUploadManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoProcessingStatusWidget(uploadId: 'test_upload_error'),
            ),
          ),
        ),
      );

      // Should show error indicators
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Video processing timeout'), findsOneWidget);

      // Should show retry button
      expect(find.text('RETRY'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should handle upload state changes dynamically', (
      tester,
    ) async {
      // Initial state: uploading
      final uploadingUpload = PendingUpload(
        id: 'dynamic_upload',
        localVideoPath: '/test/video.mp4',
        title: 'Test Video',
        hashtags: ['test'],
        status: UploadStatus.uploading,
        uploadProgress: 0.3,
        createdAt: DateTime.now(),
        nostrPubkey: 'test_pubkey',
      );

      when(
        mockUploadManager.getUpload('dynamic_upload'),
      ).thenReturn(uploadingUpload);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWith((ref) => mockUploadManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoProcessingStatusWidget(uploadId: 'dynamic_upload'),
            ),
          ),
        ),
      );

      // Verify initial state: uploading
      expect(find.text('Uploading video'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);

      // Create new upload with processing state
      final processingUpload = PendingUpload(
        id: 'dynamic_upload',
        localVideoPath: '/test/video.mp4',
        title: 'Test Video',
        hashtags: ['test'],
        status: UploadStatus.processing,
        uploadProgress: 0.9,
        createdAt: DateTime.now(),
        nostrPubkey: 'test_pubkey',
      );

      // Update mock to return processing upload
      when(
        mockUploadManager.getUpload('dynamic_upload'),
      ).thenReturn(processingUpload);

      // Create new widget with same upload ID to force refresh
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWith((ref) => mockUploadManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoProcessingStatusWidget(uploadId: 'dynamic_upload'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify new state: processing
      expect(find.text('Processing video'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });
  });
}
