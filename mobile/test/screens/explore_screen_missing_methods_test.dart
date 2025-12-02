// ABOUTME: TDD test for missing ExploreScreen methods expected by main.dart
// ABOUTME: Tests onScreenHidden, onScreenVisible, exitFeedMode, showHashtagVideos, playSpecificVideo, and isInFeedMode getter

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/explore_screen.dart';
import '../providers/test_infrastructure.dart';
import '../helpers/test_provider_overrides.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Fake Firebase implementation for testing
class FakeFirebaseCore extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FakeFirebaseApp();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FakeFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps => [FakeFirebaseApp()];
}

class FakeFirebaseApp extends Fake implements FirebaseAppPlatform {
  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'fake-api-key',
    appId: 'fake-app-id',
    messagingSenderId: 'fake-sender-id',
    projectId: 'fake-project-id',
  );
}

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = FakeFirebaseCore();
}

// Mock class for VideoEvents provider
class VideoEventsMock extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    return Stream.value(<VideoEvent>[]);
  }
}

void main() async {
  // Initialize Flutter bindings and mock Firebase
  setupFirebaseCoreMocks();

  // Mock Firebase Analytics method channel
  const MethodChannel analyticsChannel = MethodChannel(
    'plugins.flutter.io/firebase_analytics',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(analyticsChannel, (
        MethodCall methodCall,
      ) async {
        return null; // Analytics methods don't need return values in tests
      });

  // Initialize Firebase for tests
  await Firebase.initializeApp();

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
      testWidgets(
        'ExploreScreen should have onScreenHidden method that works correctly',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that onScreenHidden method exists and can be called successfully
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          expect(() {
            (state! as dynamic).onScreenHidden();
          }, returnsNormally);

          testContainer.dispose();
        },
      );

      testWidgets(
        'ExploreScreen should have onScreenVisible method that works correctly',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that onScreenVisible method exists and can be called successfully
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          expect(() {
            (state! as dynamic).onScreenVisible();
          }, returnsNormally);

          testContainer.dispose();
        },
      );

      testWidgets(
        'ExploreScreen should have exitFeedMode method that works correctly',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that exitFeedMode method exists and can be called successfully
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          expect(() {
            (state! as dynamic).exitFeedMode();
          }, returnsNormally);

          testContainer.dispose();
        },
      );

      testWidgets(
        'ExploreScreen should have showHashtagVideos method that works correctly',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that showHashtagVideos method exists and can be called successfully
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          expect(() {
            (state! as dynamic).showHashtagVideos('test');
          }, returnsNormally);

          testContainer.dispose();
        },
      );

      testWidgets(
        'ExploreScreen should have isInFeedMode getter that works correctly',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that isInFeedMode getter exists and returns correct boolean value
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          final isInFeedMode = (state! as dynamic).isInFeedMode;
          expect(isInFeedMode, isA<bool>());
          expect(isInFeedMode, false); // Should start as false

          testContainer.dispose();
        },
      );

      testWidgets(
        'ExploreScreen should have playSpecificVideo method with correct signature',
        (tester) async {
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
              child: MaterialApp(home: ExploreScreen(key: key)),
            ),
          );

          await tester.pumpAndSettle();

          // Test that playSpecificVideo method exists with the signature main.dart expects
          final state = key.currentState;
          expect(
            state,
            isNotNull,
            reason: 'ExploreScreen state should be created',
          );
          expect(() {
            (state! as dynamic).playSpecificVideo(mockVideos[0], mockVideos, 0);
          }, returnsNormally);

          testContainer.dispose();
        },
      );
    });
  });
}
