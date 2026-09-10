// ABOUTME: Widget tests for VoiceOverRecorderView.
// ABOUTME: Covers rendering, record toggle, permission UI, and done/close.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_editor/voice_over_recorder_screen.dart';

class _MockVoiceOverCubit extends MockCubit<VoiceOverState>
    implements VoiceOverCubit {}

// The toolbar also renders DivineIcons (close/done), so match the warning icon
// specifically rather than by widget type.
final Finder _warningIcon = find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == DivineIconName.warning,
);

AudioEvent _take(String id) => AudioEvent.fromLocalImport(
  id: 'local_import_voice_over_$id',
  filePath: '/tmp/$id.m4a',
  createdAt: 0,
  title: 'Recorded audio',
  mimeType: 'audio/mp4',
  duration: 1,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VoiceOverRecorderView, () {
    late _MockVoiceOverCubit cubit;

    setUp(() {
      cubit = _MockVoiceOverCubit();
      when(() => cubit.toggleRecording()).thenAnswer((_) async {});
      when(() => cubit.deleteLastTake()).thenAnswer((_) async {});
      when(() => cubit.discardAll()).thenAnswer((_) async {});
      when(() => cubit.openSettings()).thenAnswer((_) async {});
    });

    void stub(VoiceOverState state) => whenListen(
      cubit,
      const Stream<VoiceOverState>.empty(),
      initialState: state,
    );

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<VoiceOverCubit>.value(
          value: cubit,
          child: const VoiceOverRecorderView(),
        ),
      );
    }

    group('renders', () {
      testWidgets('record control and hint when idle', (tester) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorVoiceOverHint), findsOneWidget);
        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(0)),
          findsOneWidget,
        );
      });

      testWidgets('stop control while recording', (tester) async {
        stub(const VoiceOverState(status: VoiceOverStatus.recording));

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverStopSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('recording count for captured takes', (tester) async {
        stub(VoiceOverState(takes: [_take('a'), _take('b')]));

        await tester.pumpWidget(buildSubject());

        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(2)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorVoiceOverDeleteLast),
          findsOneWidget,
        );
      });

      testWidgets('shows total recorded time over available length', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('0:02 / 0:06'), findsOneWidget);
      });

      testWidgets('marks the time readout red when audio is too long', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());

        final readout = tester.widget<Text>(find.text('0:02 / 0:01'));
        expect(readout.style?.color, equals(VineTheme.error));
      });

      testWidgets('shows a non-color warning cue when audio is too long', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());

        // Color alone misses color-blind users, so a warning icon accompanies
        // the red readout.
        expect(_warningIcon, findsOneWidget);
      });

      testWidgets('omits the warning cue when audio fits the video', (
        tester,
      ) async {
        stub(
          VoiceOverState(
            takes: [_take('a'), _take('b')],
            availableDuration: const Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(_warningIcon, findsNothing);
      });

      testWidgets('count and time ignore voice-over already on the timeline', (
        tester,
      ) async {
        stub(
          const VoiceOverState(
            priorTakeCount: 3,
            availableDuration: Duration(seconds: 6),
          ),
        );

        await tester.pumpWidget(buildSubject());

        // Count and the time readout reset each session — prior takes only
        // affect the take numbering, which is applied in the cubit.
        expect(
          find.text(l10n.videoEditorVoiceOverRecordingsCount(0)),
          findsOneWidget,
        );
        expect(find.textContaining(' / '), findsNothing);
      });

      testWidgets('permission prompt when denied', (tester) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.text(l10n.videoEditorVoiceOverPermissionTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorVoiceOverOpenSettings),
          findsOneWidget,
        );
      });

      testWidgets('hides the record button while permission is denied', (
        tester,
      ) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());

        // The "Open Settings" CTA is the only action; the record button must
        // not compete with it.
        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverStopSemanticLabel),
          findsNothing,
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping the record control toggles recording', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
        );

        verify(() => cubit.toggleRecording()).called(1);
      });

      testWidgets('tapping delete last removes the last take', (tester) async {
        stub(VoiceOverState(takes: [_take('a')]));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text(l10n.videoEditorVoiceOverDeleteLast));

        verify(() => cubit.deleteLastTake()).called(1);
      });

      testWidgets('open settings delegates to the cubit', (tester) async {
        stub(
          const VoiceOverState(status: VoiceOverStatus.permissionDenied),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text(l10n.videoEditorVoiceOverOpenSettings));

        verify(() => cubit.openSettings()).called(1);
      });
    });

    group('waveform', () {
      testWidgets('animates while recording without leaking the ticker', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());

        controller.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            waveformBars: [0.4, 0.8],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        controller.add(const VoiceOverState());
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

    group('announcements', () {
      // Captures the messages SemanticsService.sendAnnouncement delivers on
      // the platform accessibility channel, mirroring the precedent in
      // conversation_view_test.dart.
      List<Object?> setUpAnnouncementCapture(WidgetTester tester) {
        final announced = <Object?>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (message) async {
                if (message is Map && message['type'] == 'announce') {
                  announced.add((message['data'] as Map?)?['message']);
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );
        return announced;
      }

      testWidgets('announces when a take is saved (count grows)', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(VoiceOverState(takes: [_take('a')]));
        await tester.pump();

        expect(announced, contains(l10n.videoEditorVoiceOverRecordingSaved));
      });

      testWidgets('does not announce "saved" when a take is deleted', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: VoiceOverState(takes: [_take('a'), _take('b')]),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(VoiceOverState(takes: [_take('a')]));
        await tester.pump();

        expect(
          announced,
          isNot(contains(l10n.videoEditorVoiceOverRecordingSaved)),
        );
      });

      testWidgets('announces when recording starts', (tester) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        controller.add(
          const VoiceOverState(status: VoiceOverStatus.recording),
        );
        await tester.pump();

        expect(
          announced,
          contains(l10n.videoEditorVoiceOverRecordingStarted),
        );
      });

      testWidgets('announces when the recording first outgrows the video', (
        tester,
      ) async {
        final controller = StreamController<VoiceOverState>();
        addTearDown(controller.close);
        whenListen(
          cubit,
          controller.stream,
          initialState: const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: Duration(seconds: 1),
          ),
        );

        await tester.pumpWidget(buildSubject());
        final announced = setUpAnnouncementCapture(tester);

        // The recorded time crosses past the 1s clip, flipping isOverAvailable.
        controller.add(
          const VoiceOverState(
            status: VoiceOverStatus.recording,
            availableDuration: Duration(seconds: 1),
            currentDuration: Duration(seconds: 2),
          ),
        );
        await tester.pump();

        expect(announced, contains(l10n.videoEditorVoiceOverTooLong));
      });
    });

    group('reduced motion', () {
      Widget buildReducedMotionSubject() {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<VoiceOverCubit>.value(
              value: cubit,
              child: const VoiceOverRecorderView(),
            ),
          ),
        );
      }

      testWidgets('record button morph is instant when animations disabled', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildReducedMotionSubject());

        final animated = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animated.duration, equals(Duration.zero));
      });

      testWidgets('record button morph animates when animations enabled', (
        tester,
      ) async {
        stub(const VoiceOverState());

        await tester.pumpWidget(buildSubject());

        final animated = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animated.duration, greaterThan(Duration.zero));
      });
    });

    group('navigation', () {
      // Pushes the view and records the pop result into [onResult] when the
      // route completes (after Done/Close pops it).
      Future<void> pushView(
        WidgetTester tester,
        void Function(List<AudioEvent>? result) onResult,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    onResult(
                      await Navigator.of(context).push<List<AudioEvent>>(
                        MaterialPageRoute<List<AudioEvent>>(
                          builder: (_) => BlocProvider<VoiceOverCubit>.value(
                            value: cubit,
                            child: const VoiceOverRecorderView(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      testWidgets('done returns the recorded takes', (tester) async {
        final takes = [_take('a'), _take('b')];
        stub(VoiceOverState(takes: takes));

        List<AudioEvent>? captured;
        var popped = false;
        await pushView(tester, (result) {
          captured = result;
          popped = true;
        });

        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorApplyToolChangesSemanticLabel(
              l10n.videoEditorVoiceOverLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(popped, isTrue);
        expect(captured, equals(takes));
        // Done commits the takes so the cubit's close() keeps their files.
        verify(() => cubit.markCommitted()).called(1);
      });

      testWidgets('close discards takes and returns nothing', (tester) async {
        stub(VoiceOverState(takes: [_take('a')]));

        List<AudioEvent>? captured;
        var popped = false;
        await pushView(tester, (result) {
          captured = result;
          popped = true;
        });

        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorDiscardToolChangesSemanticLabel(
              l10n.videoEditorVoiceOverLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => cubit.discardAll()).called(1);
        expect(popped, isTrue);
        expect(captured, isNull);
        expect(find.byType(VoiceOverRecorderView), findsNothing);
      });
    });
  });

  group(VoiceOverRecorderScreen, () {
    testWidgets('builds its own cubit without reading l10n in create', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(
            child: VoiceOverRecorderScreen(
              availableDuration: Duration(seconds: 6),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(VoiceOverRecorderView), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoEditorVoiceOverRecordSemanticLabel),
        findsOneWidget,
      );
    });
  });
}
