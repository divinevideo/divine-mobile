// ABOUTME: Tests for UploadProgressDialog widget that shows blocking upload progress UI
// ABOUTME: Validates progress display, non-dismissibility, auto-close, and polling behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/widgets/upload_progress_dialog.dart';

// Simple mock that only implements getUpload
class MockUploadManager {
  PendingUpload mockUpload;

  MockUploadManager({required this.mockUpload});

  PendingUpload? getUpload(String id) => mockUpload;
}

void main() {
  group('UploadProgressDialog', () {
    testWidgets('displays current upload progress percentage', (
      WidgetTester tester,
    ) async {
      // Arrange: Create mock upload at 50% progress
      final mockUpload = PendingUpload.create(
        localVideoPath: '/test/video.mp4',
        nostrPubkey: 'test_pubkey',
      ).copyWith(status: UploadStatus.uploading, uploadProgress: 0.5);

      final mockManager = MockUploadManager(mockUpload: mockUpload);

      // Act: Show dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UploadProgressDialog(
                uploadId: mockUpload.id,
                uploadManager: mockManager,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Should display "50%"
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Uploading video...'), findsOneWidget);
    });

    testWidgets('dialog is non-dismissible (barrierDismissible: false)', (
      WidgetTester tester,
    ) async {
      // Arrange
      final mockUpload = PendingUpload.create(
        localVideoPath: '/test/video.mp4',
        nostrPubkey: 'test_pubkey',
      ).copyWith(status: UploadStatus.uploading, uploadProgress: 0.3);

      final mockManager = MockUploadManager(mockUpload: mockUpload);

      // Act: Show dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => UploadProgressDialog(
                        uploadId: mockUpload.id,
                        uploadManager: mockManager,
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Uploading video...'), findsOneWidget);

      // Try to dismiss by tapping outside (barrier)
      await tester.tapAt(const Offset(10, 10)); // Tap outside dialog
      await tester.pumpAndSettle();

      // Assert: Dialog should still be visible (not dismissed)
      expect(find.text('Uploading video...'), findsOneWidget);
    });

    testWidgets(
      'dialog auto-closes when upload reaches readyToPublish status',
      (WidgetTester tester) async {
        // Arrange: Start with uploading status
        var mockUpload = PendingUpload.create(
          localVideoPath: '/test/video.mp4',
          nostrPubkey: 'test_pubkey',
        ).copyWith(status: UploadStatus.uploading, uploadProgress: 0.8);

        final mockManager = MockUploadManager(mockUpload: mockUpload);
        bool dialogPopped = false;

        // Act: Show dialog
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => UploadProgressDialog(
                          uploadId: mockUpload.id,
                          uploadManager: mockManager,
                        ),
                      );
                      dialogPopped = true;
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog is shown
        expect(find.text('Uploading video...'), findsOneWidget);
        expect(dialogPopped, false);

        // Simulate upload completion by updating mock upload
        mockManager.mockUpload = mockUpload.copyWith(
          status: UploadStatus.readyToPublish,
          uploadProgress: 1.0,
        );

        // Wait for polling cycle to detect completion
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Assert: Dialog should be closed
        expect(find.text('Uploading video...'), findsNothing);
        expect(dialogPopped, true);
      },
    );

    testWidgets('dialog polls UploadManager every 500ms for status updates', (
      WidgetTester tester,
    ) async {
      // Arrange: Track how many times getUpload was called
      int pollCount = 0;
      var mockUpload = PendingUpload.create(
        localVideoPath: '/test/video.mp4',
        nostrPubkey: 'test_pubkey',
      ).copyWith(status: UploadStatus.uploading, uploadProgress: 0.3);

      final mockManager = _CountingMockUploadManager(
        mockUpload: mockUpload,
        onGetUpload: () => pollCount++,
      );

      // Act: Show dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UploadProgressDialog(
                uploadId: mockUpload.id,
                uploadManager: mockManager,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial poll count should be at least 1
      expect(pollCount, greaterThanOrEqualTo(1));

      // Wait for one polling cycle (500ms)
      await tester.pump(const Duration(milliseconds: 500));
      final pollCountAfterOneCycle = pollCount;

      // Wait for another polling cycle
      await tester.pump(const Duration(milliseconds: 500));
      final pollCountAfterTwoCycles = pollCount;

      // Assert: Poll count should increase with each cycle
      expect(pollCountAfterOneCycle, greaterThan(1));
      expect(pollCountAfterTwoCycles, greaterThan(pollCountAfterOneCycle));

      // Cleanup: Complete upload to close dialog
      mockManager.mockUpload = mockUpload.copyWith(
        status: UploadStatus.readyToPublish,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });
  });
}

class _CountingMockUploadManager extends MockUploadManager {
  _CountingMockUploadManager({
    required PendingUpload mockUpload,
    required this.onGetUpload,
  }) : super(mockUpload: mockUpload);

  final VoidCallback onGetUpload;

  @override
  PendingUpload? getUpload(String id) {
    onGetUpload();
    return mockUpload;
  }
}
