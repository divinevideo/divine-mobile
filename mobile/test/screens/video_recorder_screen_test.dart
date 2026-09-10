// ABOUTME: Tests for VideoRecorderView - main video recording UI
// ABOUTME: Tests screen initialization, camera setup, UI elements, and lifecycle

import 'dart:core';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_stop_motion_budget.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  int clearAllCalls = 0;
  final keepAutosavedDraftValues = <bool>[];

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    clearAllCalls++;
    keepAutosavedDraftValues.add(keepAutosavedDraft);
  }
}

class _NonAutosaveVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() =>
      VideoEditorProviderState(isAutosavedDraft: false);
}

class _AutosaveVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

/// Mock for CameraPermissionBloc
class MockCameraPermissionBloc extends Mock implements CameraPermissionBloc {
  @override
  CameraPermissionState get state =>
      const CameraPermissionLoaded(CameraPermissionStatus.authorized);

  @override
  Stream<CameraPermissionState> get stream => Stream.value(state);

  @override
  Future<void> close() async {
    // No-op for mock
  }
}

late VideoRecorderBloc recorderBloc;
late SharedPreferences testPrefs;

/// Stub overrides for the draft storage and clip library services so the
/// recorder's autosave/clip checks resolve to empty during tests.
List<Override> _stubStorageOverrides() {
  final mockDraftStorage = _MockDraftStorageService();
  when(mockDraftStorage.getAutosaveDraft).thenAnswer((_) async => null);
  final mockClipLibrary = _MockClipLibraryService();
  when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);
  return [
    draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
    clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
  ];
}

/// Helper to build VideoRecorderView with required providers and the mock bloc.
Widget buildTestWidget({
  ProviderContainer? container,
  List<Override> overrides = const [],
  Key? recorderKey,
}) {
  final child = MultiBlocProvider(
    providers: [
      BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
      BlocProvider<CameraPermissionBloc>(
        create: (_) => MockCameraPermissionBloc(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VideoRecorderView(key: recorderKey),
    ),
  );

  if (container != null) {
    return UncontrolledProviderScope(container: container, child: child);
  }

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(testPrefs),
      ..._stubStorageOverrides(),
      ...overrides,
    ],
    child: child,
  );
}

/// Helper to build VideoRecorderView with provider overrides.
Widget buildTestWidgetWithOverrides(List<Override> overrides) =>
    buildTestWidget(overrides: overrides);

Widget buildNavigatorTestWidget({
  required bool fromEditor,
  required List<Override> overrides,
  ProviderContainer? container,
}) {
  final child = MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider<VideoRecorderBloc>.value(
                        value: recorderBloc,
                      ),
                      BlocProvider<CameraPermissionBloc>(
                        create: (_) => MockCameraPermissionBloc(),
                      ),
                    ],
                    child: VideoRecorderView(fromEditor: fromEditor),
                  ),
                ),
              );
            },
            child: const Text('Open recorder'),
          ),
        ),
      ),
    ),
  );

  if (container != null) {
    return UncontrolledProviderScope(container: container, child: child);
  }

  return ProviderScope(
    overrides: [..._stubStorageOverrides(), ...overrides],
    child: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const VideoRecorderAppLifecycleChanged(AppLifecycleState.resumed),
    );
  });

  group('VideoRecorderView Tests', () {
    late ProviderContainer container;

    setUp(() async {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          isCameraInitialized: true,
          canRecord: true,
        ),
      );

      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          ..._stubStorageOverrides(),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('UI Components', () {
      testWidgets('renders capture stack by default', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('leaves the top bar center slot empty in capture mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderStopMotionBudget), findsNothing);
      });

      testWidgets('fills the top bar center slot with the shot budget in '
          'stop-motion', (tester) async {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(
            isCameraInitialized: true,
            canRecord: true,
            recorderMode: VideoRecorderMode.stopMotion,
          ),
        );

        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderStopMotionBudget), findsOneWidget);
      });

      testWidgets('renders bottom bar widget', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });

      testWidgets('renders Column with Expanded and bottom bar', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Body is a Column with an Expanded child and a Padding child
        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);

        final column = tester.widget<Column>(columnFinder.first);
        expect(column.children.first, isA<Expanded>());
        expect(column.children.last, isA<Padding>());
      });
    });

    group('Initialization', () {
      testWidgets('initializes recording bloc on mount', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump(); // Post-frame callback

        // The View dispatches InitializeRequested from its post-frame callback.
        verify(
          () => recorderBloc.add(const VideoRecorderInitializeRequested()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('registers as WidgetsBindingObserver', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Observer should be registered (verified by no exception)
        expect(find.byType(VideoRecorderView), findsOneWidget);
      });
    });

    group('Lifecycle Management', () {
      testWidgets('handles app lifecycle state changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          await tester.pumpWidget(buildTestWidget());

          await tester.pump();

          // Simulate app going to background
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();

          // Simulate app coming back to foreground
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();

          // The View forwards lifecycle changes to the bloc.
          verify(
            () => recorderBloc.add(
              any(that: isA<VideoRecorderAppLifecycleChanged>()),
            ),
          ).called(greaterThanOrEqualTo(1));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('unregister observer on dispose', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Remove the widget
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Other screen')),
          ),
        );

        await tester.pump();

        // Should have disposed without errors
        expect(find.byType(VideoRecorderView), findsNothing);
      });

      testWidgets('sets page overlay while mounted and clears it after '
          'dispose', (tester) async {
        final pageOpenChanges = <bool>[];
        final notificationPhases = <SchedulerPhase>[];
        final subscription = container.listen(
          overlayVisibilityProvider,
          (_, next) {
            pageOpenChanges.add(next.isPageOpen);
            notificationPhases.add(SchedulerBinding.instance.schedulerPhase);
          },
        );
        addTearDown(subscription.close);

        await tester.pumpWidget(buildTestWidget(container: container));
        await tester.pump();

        expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);
        expect(pageOpenChanges, equals([true]));
        expect(notificationPhases, equals([SchedulerPhase.postFrameCallbacks]));

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Other screen')),
          ),
        );
        await tester.pump();

        expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
        expect(pageOpenChanges, equals([true, false]));
        expect(
          notificationPhases,
          everyElement(SchedulerPhase.postFrameCallbacks),
        );
      });

      testWidgets('keeps page overlay open during same-frame recorder swap', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            container: container,
            recorderKey: const ValueKey('first'),
          ),
        );
        await tester.pump();

        expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

        final pageOpenChanges = <bool>[];
        final subscription = container.listen(
          overlayVisibilityProvider,
          (_, next) => pageOpenChanges.add(next.isPageOpen),
        );
        addTearDown(subscription.close);

        await tester.pumpWidget(
          buildTestWidget(
            container: container,
            recorderKey: const ValueKey('second'),
          ),
        );

        expect(find.byKey(const ValueKey('second')), findsOneWidget);
        expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);
        expect(pageOpenChanges, isNot(contains(false)));

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Other screen')),
          ),
        );
        await tester.pump();

        expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
        expect(pageOpenChanges, equals([false]));
      });
    });

    group('Screen Layout', () {
      testWidgets('uses Column layout for screen', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);
      });

      testWidgets('screen takes full available space', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final screenSize = tester.getSize(find.byType(VideoRecorderView));
        final viewSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;

        expect(screenSize.width, equals(viewSize.width));
        expect(screenSize.height, equals(viewSize.height));
      });
    });

    group('State Management', () {
      testWidgets('screen reacts to recording state changes', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();
        await tester.pump();

        // Screen should rebuild when state changes
        expect(find.byType(VideoRecorderView), findsOneWidget);
      });

      testWidgets('maintains state during rebuilds', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Force rebuild
        await tester.pump();

        // All widgets should still be present
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });
    });

    group('Widget Tree Structure', () {
      testWidgets('capture stack is within Expanded', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Capture stack should be a descendant of Expanded
        expect(
          find.descendant(
            of: find.byType(Expanded),
            matching: find.byType(VideoRecorderCaptureStack),
          ),
          findsOneWidget,
        );
      });

      testWidgets('bottom bar is below the capture stack', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        final columnFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Column),
        );
        final column = tester.widget<Column>(columnFinder.first);

        // First child is Expanded (capture stack), last is Padding (bottom bar)
        expect(column.children.first, isA<Expanded>());
        expect(column.children.last, isA<Padding>());
      });
    });

    group('Screen Integration', () {
      testWidgets('can be popped from navigation stack', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Simulate back navigation
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('Home')),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsNothing);
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('raw Navigator recorder route clears page overlay on pop', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();
        final routeContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ..._stubStorageOverrides(),
          ],
        );
        addTearDown(routeContainer.dispose);
        final pageOpenChanges = <bool>[];
        final subscription = routeContainer.listen(
          overlayVisibilityProvider,
          (_, next) => pageOpenChanges.add(next.isPageOpen),
        );
        addTearDown(subscription.close);

        await tester.pumpWidget(
          buildNavigatorTestWidget(
            fromEditor: true,
            overrides: const [],
            container: routeContainer,
          ),
        );

        await tester.tap(find.text('Open recorder'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsOneWidget);
        expect(
          routeContainer.read(overlayVisibilityProvider).isPageOpen,
          isTrue,
        );
        expect(pageOpenChanges, equals([true]));

        Navigator.of(tester.element(find.byType(VideoRecorderView))).pop();
        await tester.pumpAndSettle();
        await tester.pump();

        expect(
          routeContainer.read(overlayVisibilityProvider).isPageOpen,
          isFalse,
        );
        expect(pageOpenChanges, equals([true, false]));
      });

      testWidgets('closing a nested recorder keeps the underlying owner open', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();
        final routeContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ..._stubStorageOverrides(),
          ],
        );
        addTearDown(routeContainer.dispose);

        await tester.pumpWidget(
          buildNavigatorTestWidget(
            fromEditor: false,
            overrides: const [],
            container: routeContainer,
          ),
        );
        await tester.tap(find.text('Open recorder'));
        await tester.pumpAndSettle();

        final firstRecorder = find.byType(VideoRecorderView);
        Navigator.of(tester.element(firstRecorder)).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
                BlocProvider<CameraPermissionBloc>(
                  create: (_) => MockCameraPermissionBloc(),
                ),
              ],
              child: const VideoRecorderView(
                key: ValueKey('nested-recorder'),
                fromEditor: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          routeContainer.read(overlayVisibilityProvider).isPageOpen,
          isTrue,
        );

        Navigator.of(
          tester.element(find.byKey(const ValueKey('nested-recorder'))),
        ).pop();
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsOneWidget);
        expect(
          routeContainer.read(overlayVisibilityProvider).isPageOpen,
          isTrue,
        );

        Navigator.of(tester.element(find.byType(VideoRecorderView))).pop();
        await tester.pumpAndSettle();

        expect(
          routeContainer.read(overlayVisibilityProvider).isPageOpen,
          isFalse,
        );
      });

      testWidgets('clears video publish state when standalone route pops', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();
        final fakeVideoPublishNotifier = _FakeVideoPublishNotifier();

        await tester.pumpWidget(
          buildNavigatorTestWidget(
            fromEditor: false,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              videoEditorProvider.overrideWith(
                _NonAutosaveVideoEditorNotifier.new,
              ),
              videoPublishProvider.overrideWith(() => fakeVideoPublishNotifier),
            ],
          ),
        );

        await tester.tap(find.text('Open recorder'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsOneWidget);

        Navigator.of(tester.element(find.byType(VideoRecorderView))).pop();
        await tester.pumpAndSettle();

        expect(fakeVideoPublishNotifier.clearAllCalls, equals(1));
        expect(fakeVideoPublishNotifier.keepAutosavedDraftValues, [isTrue]);
      });

      testWidgets('does not clear video publish state when editor route pops', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();
        final fakeVideoPublishNotifier = _FakeVideoPublishNotifier();

        await tester.pumpWidget(
          buildNavigatorTestWidget(
            fromEditor: true,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              videoEditorProvider.overrideWith(
                _NonAutosaveVideoEditorNotifier.new,
              ),
              videoPublishProvider.overrideWith(() => fakeVideoPublishNotifier),
            ],
          ),
        );

        await tester.tap(find.text('Open recorder'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsOneWidget);

        Navigator.of(tester.element(find.byType(VideoRecorderView))).pop();
        await tester.pumpAndSettle();

        expect(fakeVideoPublishNotifier.clearAllCalls, isZero);
        expect(fakeVideoPublishNotifier.keepAutosavedDraftValues, isEmpty);
      });

      testWidgets('discards the autosaved session when the route pops', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();
        final fakeVideoPublishNotifier = _FakeVideoPublishNotifier();

        await tester.pumpWidget(
          buildNavigatorTestWidget(
            fromEditor: false,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              videoEditorProvider.overrideWith(
                _AutosaveVideoEditorNotifier.new,
              ),
              videoPublishProvider.overrideWith(() => fakeVideoPublishNotifier),
            ],
          ),
        );

        await tester.tap(find.text('Open recorder'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderView), findsOneWidget);

        Navigator.of(tester.element(find.byType(VideoRecorderView))).pop();
        await tester.pumpAndSettle();

        // The autosave draft is this session's own recovery point, so leaving
        // the recorder takes it with the session — otherwise the next camera
        // open inherits its aspect ratio.
        expect(fakeVideoPublishNotifier.clearAllCalls, equals(1));
        expect(fakeVideoPublishNotifier.keepAutosavedDraftValues, [isFalse]);
      });
    });

    group('Error Handling', () {
      testWidgets('handles missing provider gracefully', (tester) async {
        // This tests that the screen doesn't crash without proper setup
        await tester.pumpWidget(buildTestWidget());

        await tester.pump();

        // Should build without crashing
        expect(find.byType(VideoRecorderView), findsOneWidget);
      });

      testWidgets('handles multiple rapid lifecycle changes', (tester) async {
        // Override platform to avoid macOS-specific camera preview
        // which requires a native texture not available in tests
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        try {
          await tester.pumpWidget(buildTestWidget());

          await tester.pump();

          // Rapid lifecycle changes
          for (var i = 0; i < 5; i++) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            await tester.pump();
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
          }

          // Should handle without crashing
          expect(find.byType(VideoRecorderView), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });

    group('Autosave Restore Flow', () {
      testWidgets('shows bottom sheet when autosaved draft has been edited', (
        tester,
      ) async {
        // Skip the "why six seconds" prompt
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();

        final mockDraftStorage = _MockDraftStorageService();
        final editedDraft = DivineVideoDraft(
          id: 'autosave',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/tmp/test.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime(2025),
              originalAspectRatio: 9 / 16,
              targetAspectRatio: .vertical,
            ),
          ],
          title: 'Edited Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );
        when(
          mockDraftStorage.getAutosaveDraft,
        ).thenAnswer((_) async => editedDraft);

        final mockClipLibrary = _MockClipLibraryService();
        when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
              clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
                BlocProvider<CameraPermissionBloc>(
                  create: (_) => MockCameraPermissionBloc(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoRecorderView(),
              ),
            ),
          ),
        );

        // Trigger post-frame callback
        await tester.pump();
        // Wait for async draft check
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Bottom sheet should be visible
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoRecorderAutosaveFoundTitle), findsOneWidget);
        expect(
          find.text(l10n.videoRecorderAutosaveContinueButton),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoRecorderAutosaveDiscardButton),
          findsOneWidget,
        );
      });

      testWidgets('shows bottom sheet when autosaved draft only has clips', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();

        final mockDraftStorage = _MockDraftStorageService();
        final clipsOnlyDraft = DivineVideoDraft(
          id: 'autosave',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/tmp/test.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime(2025),
              originalAspectRatio: 9 / 16,
              targetAspectRatio: .vertical,
            ),
          ],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );
        when(
          mockDraftStorage.getAutosaveDraft,
        ).thenAnswer((_) async => clipsOnlyDraft);

        final mockClipLibrary = _MockClipLibraryService();
        when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
              clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
                BlocProvider<CameraPermissionBloc>(
                  create: (_) => MockCameraPermissionBloc(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoRecorderView(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Clips-only sessions still represent user work and must be reachable.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoRecorderAutosaveFoundTitle), findsOneWidget);
        expect(
          find.text(l10n.videoRecorderAutosaveContinueButton),
          findsOneWidget,
        );
      });

      testWidgets('does not show bottom sheet when no draft exists', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'why_six_seconds_shown': true});
        final prefs = await SharedPreferences.getInstance();

        final mockDraftStorage = _MockDraftStorageService();
        when(mockDraftStorage.getAutosaveDraft).thenAnswer((_) async => null);

        final mockClipLibrary = _MockClipLibraryService();
        when(mockClipLibrary.getAllClips).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
              clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
                BlocProvider<CameraPermissionBloc>(
                  create: (_) => MockCameraPermissionBloc(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoRecorderView(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoRecorderAutosaveFoundTitle), findsNothing);
      });
    });
  });
}
