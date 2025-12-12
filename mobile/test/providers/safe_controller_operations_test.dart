// ABOUTME: Tests for safe controller operation helpers that prevent crashes
// ABOUTME: from "No active player with ID" errors when controllers are disposed

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/providers/individual_video_providers.dart';

@GenerateNiceMocks([MockSpec<VideoPlayerController>()])
import 'safe_controller_operations_test.mocks.dart';

void main() {
  group('safeControllerOperation', () {
    late MockVideoPlayerController mockController;

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('returns false when controller is not initialized', () async {
      // Arrange
      when(
        mockController.value,
      ).thenReturn(const VideoPlayerValue(duration: Duration.zero));

      // Act
      final result = await safeControllerOperation(
        mockController,
        'test-video-id',
        () async {},
        operationName: 'test',
      );

      // Assert
      expect(result, false);
    });

    test('returns true when operation succeeds', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );

      // Act
      final result = await safeControllerOperation(
        mockController,
        'test-video-id',
        () async {},
        operationName: 'test',
      );

      // Assert
      expect(result, true);
    });

    test('catches "no active player" error and returns false', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );

      // Act
      final result = await safeControllerOperation(
        mockController,
        'test-video-id',
        () async {
          throw Exception('Bad state: No active player with ID 13');
        },
        operationName: 'test',
      );

      // Assert
      expect(result, false);
    });

    test('catches "bad state" error and returns false', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );

      // Act
      final result = await safeControllerOperation(
        mockController,
        'test-video-id',
        () async {
          throw StateError('Bad state: disposed');
        },
        operationName: 'test',
      );

      // Assert
      expect(result, false);
    });

    test('rethrows unexpected errors', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );

      // Act & Assert
      expect(
        () async =>
            safeControllerOperation(mockController, 'test-video-id', () async {
              throw Exception('Network error');
            }, operationName: 'test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('safePlay', () {
    late MockVideoPlayerController mockController;

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('calls play on initialized controller', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(mockController.play()).thenAnswer((_) async {});

      // Act
      final result = await safePlay(mockController, 'test-video-id');

      // Assert
      expect(result, true);
      verify(mockController.play()).called(1);
    });

    test('returns false for uninitialized controller', () async {
      // Arrange
      when(
        mockController.value,
      ).thenReturn(const VideoPlayerValue(duration: Duration.zero));

      // Act
      final result = await safePlay(mockController, 'test-video-id');

      // Assert
      expect(result, false);
      verifyNever(mockController.play());
    });

    test('handles disposed controller gracefully', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        mockController.play(),
      ).thenThrow(Exception('Bad state: No active player with ID 5'));

      // Act
      final result = await safePlay(mockController, 'test-video-id');

      // Assert
      expect(result, false);
    });
  });

  group('safePause', () {
    late MockVideoPlayerController mockController;

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('calls pause on initialized controller', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(mockController.pause()).thenAnswer((_) async {});

      // Act
      final result = await safePause(mockController, 'test-video-id');

      // Assert
      expect(result, true);
      verify(mockController.pause()).called(1);
    });

    test('returns false for uninitialized controller', () async {
      // Arrange
      when(
        mockController.value,
      ).thenReturn(const VideoPlayerValue(duration: Duration.zero));

      // Act
      final result = await safePause(mockController, 'test-video-id');

      // Assert
      expect(result, false);
      verifyNever(mockController.pause());
    });

    test('handles disposed controller gracefully', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        mockController.pause(),
      ).thenThrow(Exception('Bad state: No active player with ID 13'));

      // Act
      final result = await safePause(mockController, 'test-video-id');

      // Assert
      expect(result, false);
    });
  });

  group('safeSeekTo', () {
    late MockVideoPlayerController mockController;

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('calls seekTo on initialized controller', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(mockController.seekTo(any)).thenAnswer((_) async {});

      // Act
      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        const Duration(seconds: 5),
      );

      // Assert
      expect(result, true);
      verify(mockController.seekTo(const Duration(seconds: 5))).called(1);
    });

    test('handles disposed controller gracefully', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        mockController.seekTo(any),
      ).thenThrow(Exception('player with id 7 not found'));

      // Act
      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        const Duration(seconds: 5),
      );

      // Assert
      expect(result, false);
    });
  });

  group('_isDisposalError', () {
    // Note: _isDisposalError is private, but we test it indirectly through
    // the public functions above. These tests verify the error detection logic.

    test(
      'safeControllerOperation detects "no active player" as disposal error',
      () async {
        final mockController = MockVideoPlayerController();
        when(mockController.value).thenReturn(
          VideoPlayerValue(
            duration: const Duration(seconds: 10),
            isInitialized: true,
          ),
        );

        // These error messages should be caught and return false
        final disposalErrors = [
          'No active player with ID 13',
          'Bad state: controller disposed',
          'The player with id 5 has been disposed',
          'PLAYER WITH ID 99 not found', // case insensitive
        ];

        for (final errorMsg in disposalErrors) {
          when(mockController.play()).thenThrow(Exception(errorMsg));
          final result = await safePlay(mockController, 'test-video-id');
          expect(result, false, reason: 'Should catch: $errorMsg');
        }
      },
    );
  });
}
