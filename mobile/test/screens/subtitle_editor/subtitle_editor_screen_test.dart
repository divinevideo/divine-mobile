// ABOUTME: Widget tests for SubtitleEditorView — rendering cues, status
// ABOUTME: states, and editing interactions using a mocked cubit.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/providers/subtitle_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_resolver.dart';
import 'package:openvine/widgets/captions/caption_cue_row.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_editor_stage.dart';

import '../../helpers/test_helpers.dart';

class _MockCubit extends MockCubit<SubtitleEditorState>
    implements SubtitleEditorCubit {}

class _MockSubtitleRepository extends Mock implements SubtitleRepository {}

class _FakeVideoEventResolver implements VideoEventResolver {
  _FakeVideoEventResolver(this.video);

  final VideoEvent? video;
  final resolvedIds = <String>[];
  final allowOwnContentBypassValues = <bool>[];
  final requireRawTagsValues = <bool>[];

  @override
  Future<VideoEvent?> resolveById(
    String eventId, {
    bool allowOwnContentBypass = false,
    bool requireRawTags = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    resolvedIds.add(eventId);
    allowOwnContentBypassValues.add(allowOwnContentBypass);
    requireRawTagsValues.add(requireRawTags);
    return video;
  }
}

/// The caption-text field of a cue row.
Finder cueTextFields(AppLocalizations l10n) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == l10n.subtitleEditorCueHint,
);

/// [text] as it appears in the editable cue list.
///
/// Scoped, because the same cue can also appear in the preview's caption pill.
Finder cueTextInList(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

/// Scrolls the cue list until [target] is on screen.
///
/// Rows past the first can start below the fold, whether the list fills the
/// screen or rides on the sheet over the video.
Future<void> revealInList(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(ListView),
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

/// A video with no playable URL unless one is asked for, so a test opts into
/// the stage — and its native player — deliberately.
VideoEvent _video({String? videoUrl}) => VideoEvent(
  id: 'v',
  pubkey: 'pk',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'd1',
  videoUrl: videoUrl,
);

/// A loader that never reaches the network or the frame extractor.
Stream<List<TimelineFrame>> noFrames({
  required String videoUrl,
  required String videoId,
  required Duration duration,
  required double devicePixelRatio,
}) => const Stream.empty();

void main() {
  late _MockCubit cubit;

  setUpAll(() {
    registerFallbackValue(TestHelpers.createVideoEvent(id: 'fallback'));
  });

  setUp(() => cubit = _MockCubit());

  /// Pumps the view for a video with no playable URL, so the tests below
  /// exercise the cue list without standing up a native player. The stage's
  /// own behaviour is covered by its widget test.
  Widget pump({String? videoUrl}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SubtitleEditorCubit>.value(
      value: cubit,
      child: SubtitleEditorView(
        video: _video(videoUrl: videoUrl),
        loadFrames: noFrames,
      ),
    ),
  );

  testWidgets('renders a text field per cue when ready', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(cueTextFields(l10n), findsNWidgets(2));
    expect(cueTextInList('one'), findsOneWidget);
  });

  testWidgets('shows processing message when status is processing', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.processing),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorProcessing), findsOneWidget);
  });

  testWidgets('shows the no-speech message when status is empty', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorNoSpeech), findsOneWidget);
    expect(find.text(l10n.subtitleEditorProcessing), findsNothing);
  });

  testWidgets('shows the load error when status is unavailable', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.unavailable),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
    expect(find.text(l10n.subtitleEditorProcessing), findsNothing);
  });

  testWidgets('a failed load keeps its reason on screen', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.failure),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorLoadError), findsOneWidget);
    expect(find.text(l10n.subtitleEditorWriteOwn), findsOneWidget);
  });

  testWidgets('a failed save keeps the cues the creator wrote', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.failure,
        isDirty: true,
        cues: [EditableCue(start: 0, end: 1000, text: 'written')],
      ),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(cueTextInList('written'), findsOneWidget);
    expect(find.text(l10n.subtitleEditorLoadError), findsNothing);
  });

  testWidgets('retry from a no-cue state reloads', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    when(cubit.load).thenAnswer((_) async {});
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorRetry));
    verify(cubit.load).called(1);
  });

  testWidgets('offers writing your own captions when the track is empty', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const SubtitleEditorState(status: SubtitleEditorStatus.empty));
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorWriteOwn));
    verify(cubit.addCue).called(1);
  });

  testWidgets('does not offer authoring while transcription runs', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(status: SubtitleEditorStatus.processing),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorWriteOwn), findsNothing);
  });

  testWidgets('add-a-line is reachable from the cue list', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 1000, text: 'one')],
      ),
    );
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await revealInList(tester, find.text(l10n.subtitleEditorAddCue));
    await tester.tap(find.text(l10n.subtitleEditorAddCue));
    verify(cubit.addCue).called(1);
  });

  testWidgets('add-a-line is disabled once the cues fill the video', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        videoDurationMs: 2000,
        cues: [EditableCue(start: 0, end: 2000, text: 'one')],
      ),
    );
    when(cubit.addCue).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l10n.subtitleEditorAddCue), warnIfMissed: false);
    verifyNever(cubit.addCue);
  });

  testWidgets('the trash action removes that row', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    when(() => cubit.removeCue(any())).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await revealInList(
      tester,
      find.bySemanticsLabel(l10n.subtitleEditorRemoveCue).last,
    );
    await tester.tap(find.bySemanticsLabel(l10n.subtitleEditorRemoveCue).last);
    verify(() => cubit.removeCue(1)).called(1);
  });

  testWidgets('a row reads its timing back from the cue', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 1500, end: 2000, text: 'one')],
      ),
    );
    await tester.pumpWidget(pump());

    expect(find.text('1.5s'), findsOneWidget);
    expect(find.text('2.0s'), findsOneWidget);
  });

  testWidgets('a row retimes its cue from the range slider', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        videoDurationMs: 4000,
        cues: [EditableCue(start: 0, end: 2000, text: 'one')],
      ),
    );
    when(
      () => cubit.updateCueTiming(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenReturn(null);
    await tester.pumpWidget(pump());

    // The end thumb sits at 2s of a 4s track, i.e. mid-slider. Dragging it a
    // quarter of the track to the left has to shorten the cue.
    final slider = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(slider.center, Offset(-slider.width / 4, 0));
    await tester.pump();

    final captured = verify(
      () => cubit.updateCueTiming(
        0,
        start: captureAny(named: 'start'),
        end: captureAny(named: 'end'),
      ),
    ).captured;
    expect(captured.last as int, lessThan(2000));
  });

  group('video stage', () {
    testWidgets('the video stage is skipped when there is nothing to play', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 0, end: 1000, text: 'one')],
        ),
      );
      await tester.pumpWidget(pump());

      expect(find.byType(SubtitleEditorStage), findsNothing);
      expect(cueTextInList('one'), findsOneWidget);
    });

    testWidgets('the rows fill the screen when there is nothing to play', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 0, end: 1000, text: 'one')],
        ),
      );
      await tester.pumpWidget(pump());

      // Without a picture the sheet has nothing to sit on: parked halfway up it
      // would leave the top of the screen empty above the rows.
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      final list = tester.getRect(find.byType(ListView));
      final body = tester.getRect(find.byType(Scaffold));
      expect(list.top - body.top, lessThan(body.height / 4));
    });

    testWidgets('no-stage rows clear the keyboard inset', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      when(() => cubit.state).thenReturn(
        const SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 0, end: 1000, text: 'one')],
        ),
      );
      await tester.pumpWidget(pump());

      final saveButton = find.text(
        lookupAppLocalizations(const Locale('en')).subtitleEditorSave,
      );
      expect(tester.getBottomLeft(saveButton).dy, lessThan(600 - 260));
    });

    testWidgets(
      'the cue sheet rests on the stage and cannot collapse past it',
      (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const SubtitleEditorState(
            status: SubtitleEditorStatus.ready,
            videoDurationMs: 6000,
            cues: [
              EditableCue(start: 0, end: 1000, text: 'one'),
              EditableCue(start: 1000, end: 2000, text: 'two'),
            ],
          ),
        );
        await tester.pumpWidget(
          pump(videoUrl: 'https://example.com/video.mp4'),
        );
        await tester.pump();

        double sheetTop() => tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(DraggableScrollableSheet),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .top;

        // A one-pixel divider closes the stage, so the sheet's edge meets it.
        final stageBottom = tester
            .getRect(find.byType(SubtitleEditorStage))
            .bottom;
        expect(sheetTop() - stageBottom, closeTo(1, 0.5));

        await tester.drag(find.byType(ListView), const Offset(0, 80));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          sheetTop() - stageBottom,
          closeTo(1, 0.5),
          reason:
              'the picture is a fixed height, so a lower sheet would only '
              'open a band of empty background under it',
        );
      },
    );

    testWidgets('the stage plays the renditions the feed would pick', (
      tester,
    ) async {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      when(() => cubit.state).thenReturn(
        const SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 0, end: 1000, text: 'one')],
        ),
      );
      await tester.pumpWidget(
        pump(videoUrl: 'https://media.divine.video/$hash'),
      );
      await tester.pump();

      final stage = tester.widget<SubtitleEditorStage>(
        find.byType(SubtitleEditorStage),
      );

      // The editor must not carry its own ladder: #7550 is what happens when it
      // does. The shared ladder tries renditions first and preserves the bare
      // blob as its last-resort fallback.
      expect(
        stage.playbackUrls,
        equals(
          resolvePlaybackSources(
            _video(videoUrl: 'https://media.divine.video/$hash'),
            urlResolver: (video) => video.getOptimalVideoUrlForPlatform(),
          ),
        ),
      );
      expect(
        stage.playbackUrls,
        equals([
          'https://media.divine.video/$hash/720p.mp4',
          'https://media.divine.video/$hash/hls/master.m3u8',
          'https://media.divine.video/$hash',
        ]),
      );
    });
  });

  testWidgets('focusing a row selects its cue on the timeline', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        videoDurationMs: 4000,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    when(() => cubit.selectCue(any())).thenReturn(null);
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    await revealInList(tester, cueTextFields(l10n).last);
    await tester.tap(cueTextFields(l10n).last);
    await tester.pump();

    verify(() => cubit.selectCue(1)).called(1);
  });

  testWidgets('tapping a row selects its cue without targeting the field', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        videoDurationMs: 4000,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );
    when(() => cubit.selectCue(any())).thenReturn(null);
    await tester.pumpWidget(pump());

    final row = find.byType(CaptionCueRow).last;
    await revealInList(tester, row);
    final topLeft = tester.getTopLeft(row);
    await tester.tapAt(topLeft + const Offset(8, 8));
    await tester.pump();

    verify(() => cubit.selectCue(1)).called(1);
  });

  testWidgets('rows follow the cue that moved into their position', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream<SubtitleEditorState>.fromIterable(const [
        SubtitleEditorState(
          status: SubtitleEditorStatus.ready,
          cues: [EditableCue(start: 1000, end: 2000, text: 'two')],
        ),
      ]),
      initialState: const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [
          EditableCue(start: 0, end: 1000, text: 'one'),
          EditableCue(start: 1000, end: 2000, text: 'two'),
        ],
      ),
    );

    await tester.pumpWidget(pump());
    expect(cueTextInList('one'), findsOneWidget);

    // 'one' was deleted; the surviving cue slides into row 0 and its text
    // field has to follow rather than keep showing the removed line.
    await tester.pump();

    expect(cueTextInList('one'), findsNothing);
    expect(cueTextInList('two'), findsOneWidget);
  });

  testWidgets('save stays disabled while a cue is incomplete', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        isDirty: true,
        cues: [EditableCue(start: 0, end: 2000, text: '  ')],
      ),
    );
    await tester.pumpWidget(pump());

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.subtitleEditorInvalidHint), findsOneWidget);

    await tester.tap(find.text(l10n.subtitleEditorSave));
    verifyNever(cubit.save);
  });

  testWidgets('editing a field dispatches updateCueText', (tester) async {
    when(() => cubit.state).thenReturn(
      const SubtitleEditorState(
        status: SubtitleEditorStatus.ready,
        cues: [EditableCue(start: 0, end: 1000, text: 'one')],
      ),
    );
    await tester.pumpWidget(pump());
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.enterText(cueTextFields(l10n).first, 'edited');
    verify(() => cubit.updateCueText(0, 'edited')).called(1);
  });

  testWidgets('load failure shows the load error copy', (tester) async {
    whenListen(
      cubit,
      Stream<SubtitleEditorState>.fromIterable(const [
        SubtitleEditorState(status: SubtitleEditorStatus.failure),
      ]),
      initialState: const SubtitleEditorState(),
    );

    await tester.pumpWidget(pump());
    await tester.pump();

    // Scoped to the snackbar: the body now carries the same copy, since a
    // snackbar fades and the reason has to outlive it.
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(l10n.subtitleEditorLoadError),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.subtitleEditorSaveError), findsNothing);
  });

  group(SubtitleEditorScreen, () {
    testWidgets('resolves video by id when no prefetched route extra exists', (
      tester,
    ) async {
      final video = TestHelpers.createVideoEvent(
        id: '0000000000000000000000000000000000000000000000000000000000000000',
      );
      final resolver = _FakeVideoEventResolver(video);
      final repository = _MockSubtitleRepository();
      when(() => repository.loadCues(any())).thenAnswer(
        (_) async => const SubtitleFetchResult(
          SubtitleFetchStatus.available,
          cues: [SubtitleCue(start: 0, end: 1000, text: 'hello')],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEventResolverProvider.overrideWithValue(resolver),
            subtitleRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SubtitleEditorScreen(videoId: video.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(resolver.resolvedIds, [video.id]);
      expect(resolver.allowOwnContentBypassValues, [isTrue]);
      expect(resolver.requireRawTagsValues, [isTrue]);
      expect(cueTextInList('hello'), findsOneWidget);
      verify(() => repository.loadCues(video)).called(1);
    });

    testWidgets('shows route error when the video id cannot be resolved', (
      tester,
    ) async {
      const videoId =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      final resolver = _FakeVideoEventResolver(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEventResolverProvider.overrideWithValue(resolver)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SubtitleEditorScreen(videoId: videoId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(resolver.resolvedIds, [videoId]);
      expect(find.text(l10n.routeInvalidVideoId), findsOneWidget);
    });
  });
}
