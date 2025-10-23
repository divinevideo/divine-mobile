// ABOUTME: TDD test for missing ExploreScreen methods expected by main.dart
// ABOUTME: Tests onScreenHidden, onScreenVisible, exitFeedMode, showHashtagVideos, playSpecificVideo, and isInFeedMode getter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/explore_screen.dart';
import '../providers/test_infrastructure.dart';
import '../helpers/test_provider_overrides.dart';

// Mock class for VideoEvents provider
class VideoEventsMock extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    return Stream.value(<VideoEvent>[]);
  }
}

void main() {
  group('ExploreScreen Missing Methods (TDD)', () {
    late ProviderContainer container;
    late List<VideoEvent> mockVideos;

    setUp(() {
      container = ProviderContainer();
      mockVideos = TestDataBuilder.createMockVideos(10);
    });

    tearDown(() {
      container.dispose();
    });

    group('GREEN Phase: Tests for working methods', () {
      testWidgets('ExploreScreen should have onScreenHidden method that works correctly', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that onScreenHidden method exists and can be called successfully
        expect(() {
          (key.currentState! as dynamic).onScreenHidden();
        }, returnsNormally);

        testContainer.dispose();
      });

      testWidgets('ExploreScreen should have onScreenVisible method that works correctly', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that onScreenVisible method exists and can be called successfully
        expect(() {
          (key.currentState! as dynamic).onScreenVisible();
        }, returnsNormally);

        testContainer.dispose();
      });

      testWidgets('ExploreScreen should have exitFeedMode method that works correctly', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that exitFeedMode method exists and can be called successfully
        expect(() {
          (key.currentState! as dynamic).exitFeedMode();
        }, returnsNormally);

        testContainer.dispose();
      });

      testWidgets('ExploreScreen should have showHashtagVideos method that works correctly', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that showHashtagVideos method exists and can be called successfully
        expect(() {
          (key.currentState! as dynamic).showHashtagVideos('test');
        }, returnsNormally);

        testContainer.dispose();
      });

      testWidgets('ExploreScreen should have isInFeedMode getter that works correctly', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that isInFeedMode getter exists and returns correct boolean value
        final isInFeedMode = (key.currentState! as dynamic).isInFeedMode;
        expect(isInFeedMode, isA<bool>());
        expect(isInFeedMode, false); // Should start as false

        testContainer.dispose();
      });

      testWidgets('ExploreScreen should have playSpecificVideo method with correct signature', (tester) async {
        final testContainer = ProviderContainer(
          overrides: [
          ...getStandardTestOverrides(),
            videoEventsProvider.overrideWith(() => VideoEventsMock()),
          ],
        );

        final key = GlobalKey();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: testContainer,
            child: MaterialApp(
              home: ExploreScreen(key: key),
            ),
          ),
        );

        await tester.pump();

        // Test that playSpecificVideo method exists with the signature main.dart expects
        expect(() {
          (key.currentState! as dynamic).playSpecificVideo(mockVideos[0], mockVideos, 0);
        }, returnsNormally);

        testContainer.dispose();
      });
    });
  });
}
