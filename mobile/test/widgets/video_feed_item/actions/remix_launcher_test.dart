// ABOUTME: Tests for opening a remix clip in the editor from a video sheet.
// ABOUTME: Covers keeping an autosaved session as a draft and the editor push.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/remix_launcher.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Clears the clip manager the way the real teardown does, and records when.
class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  _FakeVideoPublishNotifier(this.calls);

  final List<String> calls;
  final keepAutosavedDraftValues = <bool>[];

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    calls.add('clearAll');
    keepAutosavedDraftValues.add(keepAutosavedDraft);
    await ref.read(clipManagerProvider.notifier).clearSessionClips();
  }
}

/// Keeps the clip manager's autosave hooks from reaching real storage.
class _FakeVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  void invalidateFinalRenderedClip() {}

  @override
  void triggerAutosave() {}
}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime.utc(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
);

DivineVideoDraft _autosave({required List<DivineVideoClip> clips}) =>
    DivineVideoDraft.create(
      clips: clips,
      title: 'Half-finished idea',
      description: '',
      hashtags: const {},
      selectedApproach: 'native',
    ).copyWith(id: VideoEditorConstants.autoSaveId);

void main() {
  const openSheetLabel = 'open sheet';
  const remixLabel = 'remix';
  const editorLabel = 'editor';
  final l10n = lookupAppLocalizations(const Locale('en'));
  final remixClip = _clip('classic_vine_remix');
  final sessionClip = _clip('earlier_session_clip');

  late _MockDraftStorageService draftStorage;
  late List<String> calls;
  late _FakeVideoPublishNotifier publish;
  late ProviderContainer container;
  late List<Uri> editorLocations;

  setUpAll(() {
    registerFallbackValue(_autosave(clips: const []));
  });

  setUp(() {
    draftStorage = _MockDraftStorageService();
    calls = <String>[];
    editorLocations = <Uri>[];
    publish = _FakeVideoPublishNotifier(calls);
    when(
      () => draftStorage.draftExists(VideoEditorConstants.autoSaveId),
    ).thenAnswer((_) async => false);
    when(() => draftStorage.saveDraft(any())).thenAnswer((_) async {
      calls.add('saveDraft');
    });
  });

  void stubAutosave(DivineVideoDraft draft) {
    when(
      () => draftStorage.draftExists(VideoEditorConstants.autoSaveId),
    ).thenAnswer((_) async => true);
    when(
      () => draftStorage.getDraftById(VideoEditorConstants.autoSaveId),
    ).thenAnswer((_) async => draft);
  }

  Widget buildSubject() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => Consumer(
                  builder: (sheetContext, ref, _) => TextButton(
                    onPressed: () =>
                        openRemixInEditor(sheetContext, ref, remixClip),
                    child: const Text(remixLabel),
                  ),
                ),
              ),
              child: const Text(openSheetLabel),
            ),
          ),
        ),
        GoRoute(
          path: VideoEditorScreen.path,
          builder: (_, state) {
            editorLocations.add(state.uri);
            return const Scaffold(body: Text(editorLabel));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        draftStorageServiceProvider.overrideWithValue(draftStorage),
        videoPublishProvider.overrideWith(() => publish),
        videoEditorProvider.overrideWith(_FakeVideoEditorNotifier.new),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    );
  }

  Future<void> remixFromSheet(WidgetTester tester) async {
    await tester.tap(find.text(openSheetLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(remixLabel));
    await tester.pumpAndSettle();
  }

  group('openRemixInEditor', () {
    testWidgets(
      'saves an autosaved session as a new draft before clearing it',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);

        await remixFromSheet(tester);

        expect(calls, ['saveDraft', 'clearAll']);
        final saved =
            verify(() => draftStorage.saveDraft(captureAny())).captured.single
                as DivineVideoDraft;
        expect(saved.id, isNot(VideoEditorConstants.autoSaveId));
        expect(saved.clips.map((clip) => clip.id), [sessionClip.id]);
        expect(saved.title, 'Half-finished idea');
        expect(publish.keepAutosavedDraftValues, [isFalse]);
        expect(container.read(clipManagerProvider).clips, [remixClip]);
      },
    );

    testWidgets('closes the sheet and opens the editor from the library', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      expect(find.text(remixLabel), findsNothing);
      expect(find.text(editorLabel), findsOneWidget);
      expect(
        editorLocations.single.queryParameters[VideoEditorScreen
            .originQueryParameter],
        VideoEditorScreen.libraryOrigin,
      );
    });

    testWidgets('writes no draft when there is no autosaved session', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      verifyNever(() => draftStorage.saveDraft(any()));
      verifyNever(() => draftStorage.getDraftById(any()));
      expect(calls, ['clearAll']);
      expect(container.read(clipManagerProvider).clips, [remixClip]);
    });

    testWidgets('writes no draft when the autosave holds no clips', (
      tester,
    ) async {
      stubAutosave(_autosave(clips: const []));

      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      verifyNever(() => draftStorage.saveDraft(any()));
      expect(calls, ['clearAll']);
      expect(container.read(clipManagerProvider).clips, [remixClip]);
      expect(find.text(editorLabel), findsOneWidget);
    });

    testWidgets(
      'keeps the session and opens nothing when the draft cannot be saved',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));
        when(
          () => draftStorage.saveDraft(any()),
        ).thenThrow(Exception('disk full'));

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);

        await remixFromSheet(tester);

        expect(calls, isEmpty);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);
        expect(find.text(editorLabel), findsNothing);
        expect(find.text(remixLabel), findsNothing);
        expect(find.text(l10n.shareActionFailed), findsOneWidget);
      },
    );
  });
}
