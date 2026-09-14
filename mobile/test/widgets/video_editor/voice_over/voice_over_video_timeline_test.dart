// ABOUTME: Widget tests for VoiceOverVideoTimeline: which takes it draws, how
// ABOUTME: the take in progress glides, and the strip's clamping to the video.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/voice_over/voice_over_video_timeline.dart';

class _MockVoiceOverCubit extends MockCubit<VoiceOverState>
    implements VoiceOverCubit {}

AudioEvent _take(String id, {required double seconds}) =>
    AudioEvent.fromLocalImport(
      id: 'local_import_voice_over_$id',
      filePath: '/tmp/$id.m4a',
      createdAt: 0,
      title: id,
      mimeType: 'audio/mp4',
      duration: seconds,
    );

void main() {
  const available = Duration(seconds: 6);

  group(VoiceOverVideoTimeline, () {
    late _MockVoiceOverCubit cubit;

    setUp(() {
      cubit = _MockVoiceOverCubit();
    });

    void stub(VoiceOverState state) => whenListen(
      cubit,
      const Stream<VoiceOverState>.empty(),
      initialState: state,
    );

    // Stubs the cubit with [initialState] and feeds it [states] once the
    // strip listens, so a recording can advance from here.
    StreamController<VoiceOverState> stubStates(VoiceOverState initialState) {
      final states = StreamController<VoiceOverState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: initialState);
      return states;
    }

    Widget buildSubject({bool reduceMotion = false}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<VoiceOverCubit>.value(
            value: cubit,
            child: const Center(
              child: SizedBox(
                width: 300,
                height: VoiceOverVideoTimeline.height,
                child: VoiceOverVideoTimeline(),
              ),
            ),
          ),
        ),
      );
    }

    VoiceOverVideoTimelinePainter painter(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(VoiceOverVideoTimeline),
          matching: find.byType(CustomPaint),
        ),
      );
      return paint.painter! as VoiceOverVideoTimelinePainter;
    }

    group('renders', () {
      testWidgets('completed takes where they land on the video', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a', seconds: 2), _take('b', seconds: 1)],
            availableDuration: available,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(painter(tester).windows, [
          (start: Duration.zero, end: const Duration(seconds: 2)),
          (start: const Duration(seconds: 2), end: const Duration(seconds: 3)),
        ]);
        expect(painter(tester).liveWindow, isNull);
        expect(painter(tester).available, available);
      });

      testWidgets('the take in progress growing from its start', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            status: VoiceOverStatus.recording,
            takes: [_take('a', seconds: 2)],
            currentDuration: const Duration(milliseconds: 1500),
            availableDuration: available,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          painter(tester).liveWindow,
          (
            start: const Duration(seconds: 2),
            end: const Duration(milliseconds: 3500),
          ),
        );
      });

      testWidgets('is excluded from semantics', (tester) async {
        stub(const VoiceOverState(availableDuration: available));

        await tester.pumpWidget(buildSubject());

        expect(
          find.descendant(
            of: find.byType(VoiceOverVideoTimeline),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
      });
    });

    group('take in progress', () {
      VoiceOverState recording(Duration currentDuration) => VoiceOverState(
        status: VoiceOverStatus.recording,
        takes: [_take('a', seconds: 2)],
        currentDuration: currentDuration,
        availableDuration: available,
      );

      testWidgets('glides to the next sample instead of stepping', (
        tester,
      ) async {
        final states = stubStates(recording(const Duration(seconds: 1)));
        await tester.pumpWidget(buildSubject());

        states.add(recording(const Duration(seconds: 2)));
        await tester.pump();
        await tester.pump(VoiceOverCubit.amplitudeInterval ~/ 2);

        final midway = painter(tester).liveWindow!.end;
        expect(midway, greaterThan(const Duration(seconds: 3)));
        expect(midway, lessThan(const Duration(seconds: 4)));

        await tester.pump(VoiceOverCubit.amplitudeInterval);

        expect(painter(tester).liveWindow!.end, const Duration(seconds: 4));
      });

      testWidgets('steps to the next sample under reduced motion', (
        tester,
      ) async {
        final states = stubStates(recording(const Duration(seconds: 1)));
        await tester.pumpWidget(buildSubject(reduceMotion: true));

        states.add(recording(const Duration(seconds: 2)));
        await tester.pump();

        expect(painter(tester).liveWindow!.end, const Duration(seconds: 4));
      });

      testWidgets('stays drawn while a stopped take lands', (tester) async {
        final states = stubStates(recording(const Duration(seconds: 1)));
        await tester.pumpWidget(buildSubject());

        states.add(
          VoiceOverState(
            status: VoiceOverStatus.stopping,
            takes: [_take('a', seconds: 2)],
            currentDuration: const Duration(seconds: 1),
            availableDuration: available,
          ),
        );
        await tester.pump();

        expect(
          painter(tester).liveWindow,
          (start: const Duration(seconds: 2), end: const Duration(seconds: 3)),
        );
      });

      testWidgets('is dropped once the take has landed', (tester) async {
        final states = stubStates(recording(const Duration(seconds: 1)));
        await tester.pumpWidget(buildSubject());

        states.add(
          VoiceOverState(
            takes: [_take('a', seconds: 2), _take('b', seconds: 1)],
            availableDuration: available,
          ),
        );
        await tester.pump();

        expect(painter(tester).liveWindow, isNull);
        expect(painter(tester).windows, hasLength(2));
      });
    });
  });

  group(VoiceOverVideoTimelinePainter, () {
    VoiceOverVideoTimelinePainter build({
      List<({Duration start, Duration end})> windows = const [],
      ({Duration start, Duration end})? liveWindow,
      Duration available = available,
    }) => VoiceOverVideoTimelinePainter(
      windows: windows,
      liveWindow: liveWindow,
      available: available,
      trackColor: const Color(0xFF111111),
      takeColor: const Color(0xFF222222),
      liveTakeColor: const Color(0xFF333333),
    );

    test('repaints when a take window moves', () {
      final base = build();

      expect(build().shouldRepaint(base), isFalse);
      expect(
        build(
          windows: [(start: Duration.zero, end: const Duration(seconds: 1))],
        ).shouldRepaint(base),
        isTrue,
      );
      expect(
        build(
          liveWindow: (start: Duration.zero, end: const Duration(seconds: 1)),
        ).shouldRepaint(base),
        isTrue,
      );
    });

    test('maps a video position onto the strip', () {
      expect(build().xFor(const Duration(seconds: 3), 300), 150);
    });

    test('clamps positions past either end to the track', () {
      final painter = build();

      expect(painter.xFor(const Duration(seconds: 30), 300), 300);
      expect(painter.xFor(const Duration(seconds: -1), 300), 0);
    });
  });
}
