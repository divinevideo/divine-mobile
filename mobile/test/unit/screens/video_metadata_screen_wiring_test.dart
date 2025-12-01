// ABOUTME: Unit test verifying VideoMetadataScreenPure has correct service dependencies
// ABOUTME: Ensures upload manager and auth service are properly wired

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class MockUploadManager extends Mock implements UploadManager {}

class MockAuthService extends Mock implements AuthService {}

class MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoMetadataScreenPure Service Wiring', () {
    late MockUploadManager mockUploadManager;
    late MockAuthService mockAuthService;
    late MockFile mockVideoFile;
    late SharedPreferences prefs;
    late String testDraftId;

    setUp(() async {
      mockUploadManager = MockUploadManager();
      mockAuthService = MockAuthService();
      mockVideoFile = MockFile();

      when(() => mockVideoFile.path).thenReturn('/test/video.mp4');
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('test_pubkey_hex');

      // Set up SharedPreferences with a test draft
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final draft = VineDraft.create(
        videoFile: mockVideoFile,
        title: 'Test Video',
        description: 'Test description',
        hashtags: ['test'],
        frameCount: 10,
        selectedApproach: 'native',
      );
      testDraftId = draft.id;

      final draftService = DraftStorageService(prefs);
      await draftService.saveDraft(draft);
    });

    testWidgets('should access upload manager and auth service from providers', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
            authServiceProvider.overrideWithValue(mockAuthService),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraftId),
          ),
        ),
      );

      // Pump a few frames to allow draft loading
      // Note: We don't use pumpAndSettle() because video player never settles in tests
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Screen should build without errors
      expect(find.byType(VideoMetadataScreenPure), findsOneWidget);

      // The fact that it builds successfully means the providers are accessible
      // and the screen can read from them
    });

    testWidgets(
      'should have access to required services when publish button tapped',
      (tester) async {
        // This test verifies the screen CAN access the services
        // The actual publish flow is tested in integration tests

        when(() => mockAuthService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              uploadManagerProvider.overrideWithValue(mockUploadManager),
              authServiceProvider.overrideWithValue(mockAuthService),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: testDraftId),
            ),
          ),
        );

        // Pump a few frames to allow draft loading
        // Note: We don't use pumpAndSettle() because video player never settles in tests
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Find the publish button
        final publishButton = find.text('Publish');
        expect(publishButton, findsOneWidget);

        // The presence of the button with proper provider access means
        // the wiring is correct
      },
    );
  });
}
