import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/widgets/video_recorder/modes/chroma_key/video_recorder_chroma_key_settings.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoRecorderChromaKeyChip, () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.isClosed).thenReturn(false);
    });

    Future<void> pumpChip(
      WidgetTester tester, {
      ChromaKeyMeasurementStatus status = ChromaKeyMeasurementStatus.idle,
    }) async {
      // Tall enough for the whole settings panel to sit on screen.
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.chromaKey,
          chromaKeyMeasurementStatus: status,
        ),
      );
      await tester.pumpWidget(
        BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: Row(children: [VideoRecorderChromaKeyChip()]),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text(l10n.videoEditorChromaKeyTitle));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('names the chroma-key settings', (tester) async {
        await pumpChip(tester);

        expect(find.text(l10n.videoEditorChromaKeyTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorChromaKeyAutoDetect), findsNothing);
      });

      testWidgets('says inline when the wall could not be found', (
        tester,
      ) async {
        await pumpChip(tester, status: ChromaKeyMeasurementStatus.failed);
        await openSettings(tester);

        // A snackbar would land on the scaffold underneath the sheet.
        expect(
          find.text(l10n.videoEditorChromaKeyDetectFailed),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('opens the settings and holds remote record while open', (
        tester,
      ) async {
        await pumpChip(tester);
        await openSettings(tester);

        expect(find.text(l10n.videoEditorChromaKeyAutoDetect), findsOneWidget);
        verify(
          () => recorderBloc.add(const VideoRecorderRemoteRecordPaused()),
        ).called(1);
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRemoteRecordResumed()),
        );

        // Tap the clear area above the sheet to close it.
        await tester.tapAt(const Offset(540, 40));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorChromaKeyAutoDetect), findsNothing);
        verify(
          () => recorderBloc.add(const VideoRecorderRemoteRecordResumed()),
        ).called(1);
      });

      testWidgets('measures the wall on Auto-detect', (tester) async {
        await pumpChip(tester);
        await openSettings(tester);

        await tester.tap(find.text(l10n.videoEditorChromaKeyAutoDetect));

        verify(
          () => recorderBloc.add(
            const VideoRecorderChromaKeyMeasureRequested(),
          ),
        ).called(1);
      });

      testWidgets('switches to the blue-screen preset', (tester) async {
        await pumpChip(tester);
        await openSettings(tester);

        await tester.tap(find.text(l10n.videoEditorChromaKeyPresetBlue));

        verify(
          () => recorderBloc.add(
            const VideoRecorderChromaKeyPresetSelected(
              ChromaKey.blueScreen(),
            ),
          ),
        ).called(1);
      });

      testWidgets('clears the backdrop', (tester) async {
        await pumpChip(tester);
        await openSettings(tester);

        await tester.tap(find.text(l10n.videoEditorChromaKeyBackgroundNone));

        verify(
          () => recorderBloc.add(
            const VideoRecorderChromaKeyBackdropSet.transparent(),
          ),
        ).called(1);
      });
    });
  });
}
