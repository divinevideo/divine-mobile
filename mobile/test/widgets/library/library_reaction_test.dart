// ABOUTME: Exercises reaction handoff and cancellation without native capture.
// ABOUTME: Verifies drafts are kept before recording and only confirmed layouts open.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/video_editor/video_editor_split_screen_layout_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/library/library_reaction.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

class _Auth extends Mock implements AuthService {}

class _Analytics extends Fake implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => events.add((name: name, parameters: parameters));
}

class _CameraReplyObserver extends NavigatorObserver {
  _CameraReplyObserver(this.reply);
  final void Function(Route<dynamic> route, NavigatorState navigator) reply;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == 'video_recorder') {
      scheduleMicrotask(() => reply(route, navigator!));
    }
  }
}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
);

class _Manager extends ClipManagerNotifier {
  Object? bakeError;
  bool saveSucceeds = true;
  Completer<bool>? saveGate;
  final savedClips = <String, DivineVideoClip>{};
  Completer<void>? extractionGate;
  Set<String>? extractedIds;

  @override
  List<DivineVideoClip> abandonExtraction(
    Set<String> clipIds, {
    required int generation,
  }) {
    if (generation != sessionGeneration) return [];
    final removed = clips.where((clip) => clipIds.contains(clip.id)).toList();
    state = state.copyWith(
      clips: clips.where((clip) => !clipIds.contains(clip.id)).toList(),
    );
    return removed;
  }

  @override
  Future<List<DivineVideoClip>> extractClips(Set<String> clipIds) async {
    extractedIds = clipIds;
    final takes = clips.where((clip) => clipIds.contains(clip.id)).toList();
    await extractionGate?.future;
    state = state.copyWith(
      clips: clips.where((clip) => !clipIds.contains(clip.id)).toList(),
    );
    return takes;
  }

  @override
  Future<bool> saveClipToLibrary(DivineVideoClip clip) async {
    final saved = saveGate == null ? saveSucceeds : await saveGate!.future;
    if (saved) savedClips[clip.id] = clip;
    return saved;
  }

  @override
  Future<DivineVideoClip> bakeCapturedChromaKey(DivineVideoClip clip) async {
    if (bakeError case final error?) throw error;
    return clip;
  }

  @override
  ClipManagerState build() => ClipManagerState(clips: [_clip('unfinished')]);

  @override
  List<DivineVideoClip> get clips => state.clips;

  @override
  DivineVideoClip insertClip(int index, DivineVideoClip clip) {
    final next = [...clips]..insert(index, clip);
    state = state.copyWith(clips: next);
    return clip;
  }

  void clear() => state = state.copyWith(clips: []);
}

class _Editor extends VideoEditorNotifier {
  _Editor(this.events);
  final List<String> events;
  Completer<String?>? keepGate;
  final deferredPaths = <String>[];

  @override
  void deferFileCleanup(Iterable<String?> paths) {
    deferredPaths.addAll(paths.whereType<String>());
  }

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<String?> keepAutosaveAsDraft() async {
    events.add('keep draft');
    return keepGate?.future ?? 'kept-draft';
  }

  @override
  Future<void> discardKeptDraft(String draftId) async {
    events.add('discard duplicate $draftId');
  }
}

class _Publish extends VideoPublishNotifier {
  _Publish(this.events, this.manager, {this.clearGate});
  final List<String> events;
  final _Manager manager;
  final Completer<void>? clearGate;

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    events.add('clear session');
    manager.clear();
    await clearGate?.future;
  }
}

void main() {
  group('library reaction', () {
    late List<String> events;
    late _Manager manager;
    late _Editor editor;
    late _Auth auth;
    late String owner;
    late List<String> abandoned;
    late List<String>? deferredWhenEditorOpened;
    late _Analytics analytics;
    late CreationAnalyticsTracker tracker;

    setUp(() {
      events = [];
      abandoned = [];
      deferredWhenEditorOpened = null;
      manager = _Manager();
      editor = _Editor(events);
      auth = _Auth();
      analytics = _Analytics();
      tracker = CreationAnalyticsTracker(analytics: analytics);
      owner =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
    });

    Future<void> start(
      WidgetTester tester, {
      required SplitScreenCellPicker? record,
      required LibraryReactionLayout? layout,
      LibraryReactionMerge? merge,
      NavigatorObserver? observer,
      Completer<void>? clearGate,
      Future<void> Function(CreationAnalyticsSession)? onOpenEditor,
      bool reducedMotion = false,
      bool pushed = false,
    }) async {
      final libraryView = Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => recordLibraryReaction(
              context,
              ref,
              _clip('source'),
              recordWithCamera: record,
              showLayout: layout,
              mergeTakes: merge,
              extractThumbnail: (path) async =>
                  (path: '$path.jpg', timestamp: Duration.zero),
              cleanupAbandoned: (paths) async => abandoned.addAll(paths),
              openEditor: (_, session) async {
                deferredWhenEditorOpened = [...editor.deferredPaths];
                events.add('open editor');
                await onOpenEditor?.call(session);
              },
            ),
            child: const Text('react'),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            creationAnalyticsTrackerProvider.overrideWithValue(tracker),
            clipManagerProvider.overrideWith(() => manager),
            videoEditorProvider.overrideWith(() => editor),
            videoPublishProvider.overrideWith(
              () => _Publish(events, manager, clearGate: clearGate),
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [?observer],
            builder: reducedMotion
                ? (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: child!,
                  )
                : null,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: pushed
                ? Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => libraryView),
                        ),
                        child: const Text('open library'),
                      ),
                    ),
                  )
                : libraryView,
          ),
        ),
      );
      if (pushed) {
        await tester.tap(find.text('open library'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('react'));
      await tester.pumpAndSettle();
    }

    void reportCameraUse(Route<dynamic> route, NavigatorState navigator) {
      final recorder = (route as PageRouteBuilder<bool>).pageBuilder(
        navigator.context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
      ) as VideoRecorderRoute;
      unawaited(
        tracker.cameraOpened(
          mode: .capture,
          entryPoint: recorder.entryPoint,
          session: recorder.analyticsSession,
        ),
      );
      unawaited(
        tracker.recordingStarted(.capture, session: recorder.analyticsSession),
      );
    }

    testWidgets(
      'canceled library capture leaves the next camera funnel fresh',
      (
        tester,
      ) async {
        await start(
          tester,
          record: null,
          layout: (_, _, _, _) async => fail('canceled camera opens no Layout'),
          observer: _CameraReplyObserver((route, navigator) {
            reportCameraUse(route, navigator);
            navigator.pop(false);
          }),
        );

        await tracker.cameraOpened(mode: .capture, entryPoint: 'bottom_nav');
        await tracker.recordingStarted(.capture);
        expect(analytics.events.map((event) => event.name), [
          'camera_opened',
          'recording_started',
          'creation_abandoned',
          'camera_opened',
          'recording_started',
        ]);
        expect(analytics.events.first.parameters['entry_point'], 'library');
        expect(
          analytics.events
              .lastWhere((event) => event.name == 'camera_opened')
              .parameters['entry_point'],
          'bottom_nav',
        );
      },
    );

    testWidgets('an unmounted editor push leaves no reaction funnel open', (
      tester,
    ) async {
      await start(
        tester,
        record: null,
        observer: _CameraReplyObserver((route, navigator) {
          reportCameraUse(route, navigator);
          manager.insertClip(0, _clip('capture'));
          navigator.pop(true);
        }),
        layout: (_, _, _, _) async => _clip('layout'),
        // The navigation returns without a destination claiming the session.
        onOpenEditor: (_) async {},
      );

      expect(events.last, 'open editor');
      expect(analytics.events.map((event) => event.name), [
        'camera_opened',
        'recording_started',
        'recording_completed',
        'creation_abandoned',
      ]);
      expect(tracker.activeMode, isNull);
    });

    testWidgets('library re-recording continues the funnel into the editor', (
      tester,
    ) async {
      var captures = 0;
      await start(
        tester,
        record: null,
        observer: _CameraReplyObserver((route, navigator) {
          reportCameraUse(route, navigator);
          manager.insertClip(0, _clip('capture-${++captures}'));
          navigator.pop(true);
        }),
        layout: (context, _, _, recordAgain) async {
          final takes = await recordAgain(
            context,
            cellAspectRatio: 0.5,
            maxClips: 1,
          );
          expect(takes?.single.id, 'capture-2');
          return _clip('layout');
        },
        onOpenEditor: tracker.claimEditorSession,
      );

      expect(captures, 2);
      expect(analytics.events.map((event) => event.name), [
        'camera_opened',
        'recording_started',
        'recording_completed',
        'editor_opened',
      ]);
      expect(analytics.events.first.parameters['entry_point'], 'library');
      expect(analytics.events[2].parameters, containsPair('clip_count', 1));
    });

    for (final path in [
      RoutePaths.videoRecorder,
      RoutePaths.videoEditor,
      RoutePaths.videoMetadata,
    ]) {
      testWidgets('cannot replace the active session on $path', (tester) async {
        final router = GoRouter(
          initialLocation: path,
          routes: [
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(clipManagerProvider);
                    return TextButton(
                      onPressed: () =>
                          recordLibraryReaction(context, ref, _clip('source')),
                      child: const Text('react'),
                    );
                  },
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(auth),
              clipManagerProvider.overrideWith(() => manager),
              videoEditorProvider.overrideWith(() => editor),
              videoPublishProvider.overrideWith(
                () => _Publish(events, manager),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(manager.clips.map((clip) => clip.id), ['unfinished']);
        await tester.tap(find.text('react'));
        await tester.pumpAndSettle();
        expect(events, isEmpty);
        expect(manager.clips.map((clip) => clip.id), ['unfinished']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'pending session cleanup cannot open a camera over a newer route',
      (
        tester,
      ) async {
        final clearGate = Completer<void>();
        var cameraPushes = 0;
        await start(
          tester,
          record: null,
          layout: (_, _, _, _) async =>
              fail('the old route cannot open Layout'),
          clearGate: clearGate,
          observer: _CameraReplyObserver((_, navigator) {
            cameraPushes++;
            navigator.pop(false);
          }),
        );
        expect(events, ['keep draft', 'clear session']);
        expect(clearGate.isCompleted, isFalse);
        final library = tester.element(find.text('react'));
        Navigator.of(library).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('newer route')),
          ),
        );
        await tester.pumpAndSettle();
        expect(library.mounted, isTrue);
        expect(ModalRoute.of(library)?.isCurrent, isFalse);
        expect(find.text('newer route'), findsOneWidget);

        clearGate.complete();
        await tester.pumpAndSettle();

        expect(cameraPushes, 0);
        expect(find.text('newer route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final confirmed in [true, false]) {
      testWidgets(
        'shows preparation after the real camera closure returns $confirmed',
        (tester) async {
          final gate = Completer<void>();
          manager.extractionGate = gate;
          var layouts = 0;
          await start(
            tester,
            record: null,
            reducedMotion: true,
            observer: _CameraReplyObserver((route, navigator) {
              final recorder = (route as PageRouteBuilder<bool>).pageBuilder(
                navigator.context,
                const AlwaysStoppedAnimation<double>(1),
                const AlwaysStoppedAnimation<double>(1),
              ) as VideoRecorderRoute;
              expect(recorder.fromEditor, isTrue);
              expect(recorder.cropGuideAspectRatio, 0.5);
              manager.insertClip(0, _clip('captured'));
              navigator.pop(confirmed);
            }),
            layout: (_, clips, _, _) async {
              layouts++;
              expect(clips.map((clip) => clip.id), ['source', 'captured']);
              return null;
            },
          );
          final context = tester.element(find.text('react'));
          final label = context.l10n.libraryPreparingVideo;
          final showedPreparation = find.text(label).evaluate().isNotEmpty;
          final blockedBack =
              ModalRoute.of(context)!.popDisposition ==
              RoutePopDisposition.doNotPop;
          final handledBack = await Navigator.of(context).maybePop();
          gate.complete();
          await tester.pumpAndSettle();
          expect(showedPreparation, isTrue);
          expect(blockedBack, isFalse);
          expect(handledBack, isFalse);
          expect(manager.extractedIds, {'captured'});
          expect(layouts, confirmed ? 1 : 0);
          expect(find.text(label), findsNothing);
          expect(
            ModalRoute.of(context)!.popDisposition,
            isNot(RoutePopDisposition.doNotPop),
          );
          expect(manager.clips, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('Back leaves an unfinished preparation without a late Layout', (
      tester,
    ) async {
      final gate = Completer<void>();
      manager.extractionGate = gate;
      await start(
        tester,
        record: null,
        pushed: true,
        reducedMotion: true,
        observer: _CameraReplyObserver((route, navigator) {
          reportCameraUse(route, navigator);
          manager.insertClip(
            0,
            _clip('captured').copyWith(
              secondaryCamera: SecondaryCameraTake(
                clip: _clip('secondary').copyWith(
                  thumbnailPath: '/documents/secondary.jpg',
                ),
                compositeThumbnailPath: '/documents/composite.jpg',
              ),
            ),
          );
          navigator.pop(true);
        }),
        layout: (_, _, _, _) async =>
            fail('a departed flow must not open Layout'),
      );
      final context = tester.element(find.text('react'));
      final label = context.l10n.libraryPreparingVideo;
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(context.l10n.commonBack));
      await tester.pumpAndSettle();
      // The native work is still pending, but its screen is not a trap.
      expect(gate.isCompleted, isFalse);
      expect(find.text('open library'), findsOneWidget);
      expect(find.text(label), findsNothing);
      final releasedImmediately = manager.clips.isEmpty;
      expect(abandoned, isEmpty);
      expect(analytics.events.last.name, 'creation_abandoned');
      await tracker.cameraOpened(mode: .classic, entryPoint: 'bottom_nav');
      manager.insertClip(0, _clip('new-session'));
      gate.complete();
      await tester.pumpAndSettle();
      expect(events, ['keep draft', 'clear session']);
      expect(releasedImmediately, isTrue);
      expect(manager.clips.map((clip) => clip.id), ['new-session']);
      expect(tracker.activeMode?.name, 'classic');
      expect(
        abandoned,
        containsAll([
          '/documents/secondary.jpg',
          '/documents/composite.jpg',
        ]),
      );
      expect(abandoned, isNot(contains('/documents/secondary.mp4')));
      expect(abandoned, isNot(contains('/documents/captured.mp4')));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'programmatic route replacement removes pending preparation UI',
      (tester) async {
        final gate = Completer<void>();
        manager.extractionGate = gate;
        await start(
          tester,
          record: null,
          reducedMotion: true,
          observer: _CameraReplyObserver((_, navigator) {
            manager.insertClip(0, _clip('captured'));
            navigator.pop(true);
          }),
          layout: (_, _, _, _) async =>
              fail('a departed flow must not open Layout'),
        );
        final context = tester.element(find.text('react'));
        final label = context.l10n.libraryPreparingVideo;
        expect(find.text(label), findsOneWidget);
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('moved')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('moved'), findsOneWidget);
        expect(find.text(label), findsNothing);
        final releasedImmediately = manager.clips.isEmpty;
        gate.complete();
        await tester.pumpAndSettle();
        expect(events, ['keep draft', 'clear session']);
        expect(releasedImmediately, isTrue);
        expect(manager.clips, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'preparation failure clears progress and reports the failed take',
      (tester) async {
        final gate = Completer<void>();
        manager.extractionGate = gate;
        await start(
          tester,
          record: null,
          reducedMotion: true,
          observer: _CameraReplyObserver((_, navigator) {
            manager.insertClip(0, _clip('captured'));
            navigator.pop(true);
          }),
          layout: (_, _, _, _) async =>
              fail('failed preparation must not open Layout'),
        );
        final context = tester.element(find.text('react'));
        expect(find.text(context.l10n.libraryPreparingVideo), findsOneWidget);
        gate.completeError(Exception('take processing failed'));
        await tester.pumpAndSettle();
        expect(find.text(context.l10n.libraryPreparingVideo), findsNothing);
        expect(
          find.text(context.l10n.videoEditorClipSaveFailed),
          findsOneWidget,
        );
        expect(
          ModalRoute.of(context)!.popDisposition,
          isNot(RoutePopDisposition.doNotPop),
        );
        expect(manager.clips.map((clip) => clip.id), ['captured']);
        expect(events, ['keep draft', 'clear session']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('leaves the active session intact when keeping it fails', (
      tester,
    ) async {
      final write = Completer<String?>();
      editor.keepGate = write;

      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async {
          events.add('open camera');
          return null;
        },
        layout: (_, _, _, _) async => fail('must not open Layout'),
      );
      final context = tester.element(find.text('react'));
      write.completeError(Exception('Autosave write refused'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(events, ['keep draft']);
      expect(manager.clips.single.id, 'unfinished');
      expect(
        find.text(context.l10n.videoMetadataFailedToSaveSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('persists an unedited own-source layout outside the session', (
      tester,
    ) async {
      final layout = _clip('layout');
      final autosave = DivineVideoDraft.create(
        clips: [layout],
        title: '',
        description: '',
        hashtags: {},
        selectedApproach: 'video',
      );
      expect(autosave.hasBeenEdited, isFalse);
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('reaction'),
        ],
        layout: (_, _, _, _) async => layout,
      );
      expect(manager.savedClips['layout'], same(layout));
      manager.clear();
      expect(manager.clips, isEmpty);
      expect(manager.savedClips['layout'], same(layout));
    });

    testWidgets('waits for library persistence before opening the editor', (
      tester,
    ) async {
      final gate = Completer<bool>();
      manager.saveGate = gate;
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('reaction'),
        ],
        layout: (_, _, _, _) async => _clip('layout'),
      );
      final openedBeforeSave = events.contains('open editor');
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(openedBeforeSave, isFalse);
      expect(manager.savedClips, contains('layout'));
      expect(events.last, 'open editor');
    });

    testWidgets('failed layout persistence reports failure without an editor', (
      tester,
    ) async {
      manager.saveSucceeds = false;
      await start(
        tester,
        record: null,
        observer: _CameraReplyObserver((route, navigator) {
          reportCameraUse(route, navigator);
          manager.insertClip(0, _clip('reaction'));
          navigator.pop(true);
        }),
        layout: (_, _, _, _) async => _clip('layout'),
      );
      final context = tester.element(find.text('react'));
      expect(find.text(context.l10n.videoEditorClipSaveFailed), findsOneWidget);
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
      expect(manager.savedClips, isEmpty);
      expect(abandoned, ['/documents/layout.mp4']);
      expect(analytics.events.last.name, 'creation_abandoned');
      expect(analytics.events.last.parameters['last_stage'], 'recording');
      expect(tracker.activeMode, isNull);
    });

    testWidgets('account change during layout save does not open an editor', (
      tester,
    ) async {
      final gate = Completer<bool>();
      manager.saveGate = gate;
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('reaction'),
        ],
        layout: (_, _, _, _) async => _clip('layout'),
      );
      owner =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
      expect(abandoned, ['/documents/layout.mp4']);
    });

    testWidgets(
      'keeps the draft, records, and opens only the confirmed layout',
      (tester) async {
        await start(
          tester,
          record: (_, {required cellAspectRatio, required maxClips}) async {
            expect(manager.clips, isEmpty);
            expect(cellAspectRatio, 0.5);
            expect(maxClips, 1);
            events.add('record');
            return [_clip('reaction')];
          },
          layout: (_, clips, _, _) async {
            expect(clips.map((clip) => clip.id), ['source', 'reaction']);
            expect(manager.clips, isEmpty);
            events.add('confirm layout');
            return _clip('layout');
          },
        );
        expect(events, [
          'keep draft',
          'clear session',
          'record',
          'confirm layout',
          'open editor',
        ]);
        expect(manager.clips.map((clip) => clip.id), ['layout']);
      },
    );

    testWidgets('opens its own layout with the original beside the take', (
      tester,
    ) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async {
          events.add('record');
          return [_clip('reaction')];
        },
        layout: null,
      );
      final layout = tester
          .element(find.byType(VideoEditorSplitScreenLayoutView))
          .read<SplitScreenLayoutCubit>()
          .state;
      expect(layout.activeCells.map((cell) => cell?.clip.id), [
        'source',
        'reaction',
      ]);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(VideoEditorSplitScreenLayoutView), findsNothing);
      expect(events, ['keep draft', 'clear session', 'record']);
      expect(manager.clips, isEmpty);
    });

    testWidgets('combines every recorded cut into the reaction cell', (
      tester,
    ) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('cut-one'),
          _clip('cut-two'),
        ],
        merge: ({required clips, required renderId}) async {
          expect(clips.map((clip) => clip.id), ['cut-one', 'cut-two']);
          events.add('merge cuts');
          return _clip('combined').copyWith(
            duration: const Duration(seconds: 4),
            originalAspectRatio: 9 / 16,
            videoAspectRatio: 9 / 16,
            thumbnailPath: '/documents/cut-one.jpg',
          );
        },
        layout: (_, clips, _, _) async {
          expect(clips.map((clip) => clip.id), ['source', 'combined']);
          expect(clips.last.duration, const Duration(seconds: 4));
          expect(clips.last.videoAspectRatio, 1);
          expect(clips.last.originalAspectRatio, 9 / 16);
          expect(clips.last.thumbnailPath, '/documents/combined.mp4.jpg');
          return _clip('layout');
        },
      );
      expect(events, [
        'keep draft',
        'clear session',
        'merge cuts',
        'open editor',
      ]);
      expect(deferredWhenEditorOpened, [
        '/documents/combined.mp4',
        '/documents/combined.mp4.jpg',
      ]);
      expect(abandoned, isEmpty);
    });

    testWidgets(
      'cancelling a multi-cut layout cleans only generated intermediates',
      (tester) async {
        await start(
          tester,
          record: (_, {required cellAspectRatio, required maxClips}) async => [
            _clip('cut-one'),
            _clip('cut-two'),
          ],
          merge: ({required clips, required renderId}) async =>
              _clip('combined'),
          layout: (_, _, _, _) async => null,
        );
        expect(events, ['keep draft', 'clear session']);
        expect(abandoned, [
          '/documents/combined.mp4',
          '/documents/combined.mp4.jpg',
        ]);
        expect(editor.deferredPaths, isEmpty);
        expect(manager.clips, isEmpty);
      },
    );

    testWidgets('failed combination does not silently use the first cut', (
      tester,
    ) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('cut-one'),
          _clip('cut-two'),
        ],
        merge: ({required clips, required renderId}) async => null,
        layout: (_, _, _, _) async {
          fail('failed merge must not reach layout');
        },
      );
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
      final context = tester.element(find.text('react'));
      expect(find.text(context.l10n.videoEditorMergeFailed), findsOneWidget);
    });

    for (final rerecord in [false, true]) {
      testWidgets(
        'shows preparation failure during ${rerecord ? 'layout re-record' : 'initial capture'}',
        (tester) async {
          manager.bakeError = Exception('capture bake unavailable');
          var captures = 0;
          await start(
            tester,
            record: (_, {required cellAspectRatio, required maxClips}) async {
              captures++;
              if (rerecord && captures == 1) return [_clip('initial')];
              return [
                for (final id in ['one', 'two'])
                  _clip(id).copyWith(
                    captureChromaKey: const ClipChromaKey(key: ChromaKey()),
                  ),
              ];
            },
            merge: ({required clips, required renderId}) async {
              fail('a failed bake must not merge raw camera cuts');
            },
            layout: (context, _, _, recordAgain) async {
              expect(rerecord, isTrue);
              expect(
                await recordAgain(context, cellAspectRatio: 0.5, maxClips: 1),
                isNull,
              );
              return null;
            },
          );
          final context = tester.element(find.text('react'));
          expect(
            find.text(context.l10n.videoEditorMergeFailed),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(manager.clips, isEmpty);
          expect(events, ['keep draft', 'clear session']);
        },
      );
    }

    testWidgets('cancelled recording opens no layout or editor', (
      tester,
    ) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async =>
            null,
        layout: (_, _, _, _) async {
          fail('cancelled recording must not open the layout');
        },
      );
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
    });

    testWidgets('cancelled layout opens no editor', (tester) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async => [
          _clip('reaction'),
        ],
        layout: (_, _, _, _) async => null,
      );
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
    });

    testWidgets('account change during recording does not open the layout', (
      tester,
    ) async {
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async {
          owner = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          return [_clip('reaction')];
        },
        layout: (_, _, _, _) async {
          fail('another account must not receive the reaction');
        },
      );
      expect(events, ['keep draft', 'clear session']);
      expect(manager.clips, isEmpty);
    });

    testWidgets('leaving while saving keeps the active session intact', (
      tester,
    ) async {
      final gate = Completer<String?>();
      editor.keepGate = gate;
      await start(
        tester,
        record: (_, {required cellAspectRatio, required maxClips}) async {
          fail('must not record after leaving the library');
        },
        layout: (_, _, _, _) async => null,
      );
      expect(manager.clips.map((clip) => clip.id), ['unfinished']);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete('kept-draft');
      await tester.pumpAndSettle();
      expect(events, ['keep draft', 'discard duplicate kept-draft']);
    });
  });
}
