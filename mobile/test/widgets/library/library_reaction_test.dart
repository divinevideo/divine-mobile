// ABOUTME: Exercises reaction handoff and cancellation without native capture.
// ABOUTME: Verifies drafts are kept before recording and only confirmed layouts open.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_split_screen_layout_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/library/library_reaction.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

class _Auth extends Mock implements AuthService {}

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
  final cleanedPaths = <String>[];

  @override
  void deferFileCleanup(Iterable<String?> paths) {
    cleanedPaths.addAll(paths.whereType<String>());
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
  _Publish(this.events, this.manager);
  final List<String> events;
  final _Manager manager;

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    events.add('clear session');
    manager.clear();
  }
}

void main() {
  group('library reaction', () {
    late List<String> events;
    late _Manager manager;
    late _Editor editor;
    late _Auth auth;
    late String owner;

    setUp(() {
      events = [];
      manager = _Manager();
      editor = _Editor(events);
      auth = _Auth();
      owner =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
    });

    Future<void> start(
      WidgetTester tester, {
      required SplitScreenCellPicker record,
      required LibraryReactionLayout layout,
      LibraryReactionMerge? merge,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            clipManagerProvider.overrideWith(() => manager),
            videoEditorProvider.overrideWith(() => editor),
            videoPublishProvider.overrideWith(() => _Publish(events, manager)),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
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
                    cleanupAbandoned: (paths) async =>
                        editor.cleanedPaths.addAll(paths),
                    openEditor: (_) async => events.add('open editor'),
                  ),
                  child: const Text('react'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('react'));
      await tester.pumpAndSettle();
    }

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
      expect(editor.cleanedPaths, [
        '/documents/combined.mp4',
        '/documents/combined.mp4.jpg',
      ]);
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
        expect(editor.cleanedPaths, [
          '/documents/combined.mp4',
          '/documents/combined.mp4.jpg',
        ]);
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
      expect(
        find.text('Could not merge clips. Please try again.'),
        findsOneWidget,
      );
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
