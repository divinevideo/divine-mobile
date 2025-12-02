// ABOUTME: Tests for VideoErrorOverlay widget
// ABOUTME: Verifies error display, 401 age-restricted content handling, and retry functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/widgets/video_error_overlay.dart';

import '../builders/test_video_event_builder.dart';
import 'video_error_overlay_test.mocks.dart';

@GenerateMocks([AgeVerificationService])
void main() {
  group('VideoErrorOverlay', () {
    late VideoEvent testVideo;
    late VideoControllerParams controllerParams;
    late MockAgeVerificationService mockAgeVerification;

    setUp(() {
      testVideo = TestVideoEventBuilder.create(
        id: 'test-video-id',
        videoUrl: 'https://example.com/video.mp4',
      );

      controllerParams = VideoControllerParams(
        videoId: testVideo.id,
        videoUrl: testVideo.videoUrl!,
        videoEvent: testVideo,
      );

      mockAgeVerification = MockAgeVerificationService();
    });

    Widget buildWidget({
      required String errorDescription,
      bool isActive = true,
    }) {
      return ProviderScope(
        overrides: [
          ageVerificationServiceProvider.overrideWithValue(mockAgeVerification),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoErrorOverlay(
              video: testVideo,
              controllerParams: controllerParams,
              errorDescription: errorDescription,
              isActive: isActive,
            ),
          ),
        ),
      );
    }

    testWidgets('displays 401 error UI for unauthorized errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'HttpException: Invalid statusCode: 401'),
      );

      // Should show lock icon for 401
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Age-restricted content'), findsOneWidget);
      expect(find.text('Verify Age'), findsOneWidget);

      // Should NOT show error icon
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays generic error UI for non-401 errors', (tester) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'HttpException: Invalid statusCode: 404'),
      );

      // Should show error icon for non-401
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Video not found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Should NOT show lock icon
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('translates 404 error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'HttpException: Invalid statusCode: 404'),
      );

      expect(find.text('Video not found'), findsOneWidget);
    });

    testWidgets('translates network error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Network error: Connection failed'),
      );

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('translates timeout error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(errorDescription: 'Request timeout'));

      expect(find.text('Loading timeout'), findsOneWidget);
    });

    testWidgets('translates format error to user-friendly message', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Unsupported codec'),
      );

      expect(find.text('Unsupported video format'), findsOneWidget);
    });

    testWidgets('shows generic error message for unknown errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(errorDescription: 'Some unknown error'),
      );

      expect(find.text('Video playback error'), findsOneWidget);
    });

    testWidgets('hides error overlay when video is inactive', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 401',
          isActive: false,
        ),
      );

      // Should show thumbnail but no error overlay
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows error overlay when video is active', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          errorDescription: 'HttpException: Invalid statusCode: 401',
          isActive: true,
        ),
      );

      // Should show error overlay with button
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('tapping Verify Age button shows age verification dialog', (
      tester,
    ) async {
      when(
        mockAgeVerification.verifyAdultContentAccess(any),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildWidget(errorDescription: 'HttpException: Invalid statusCode: 401'),
      );

      // Tap the "Verify Age" button
      await tester.tap(find.text('Verify Age'));
      await tester.pumpAndSettle();

      // Verify age verification service was called
      verify(mockAgeVerification.verifyAdultContentAccess(any)).called(1);
    });

    testWidgets(
      '401 error with "unauthorized" in lowercase triggers age verification UI',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(errorDescription: 'unauthorized access'),
        );

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.text('Age-restricted content'), findsOneWidget);
        expect(find.text('Verify Age'), findsOneWidget);
      },
    );
  });
}
