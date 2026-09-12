// ABOUTME: Tests for VideoRecorderFocusPoint widget
// ABOUTME: Validates focus point indicator, animations, and position calculations

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderFocusPoint Widget Tests', () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildTestWidget() {
      return BlocProvider<VideoRecorderBloc>.value(
        value: recorderBloc,
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoRecorderFocusPoint()),
        ),
      );
    }

    testWidgets('renders focus point widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderFocusPoint), findsOneWidget);
    });

    testWidgets('contains IgnorePointer to prevent touch interference', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is initially invisible when focusPoint is zero', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0.0));
    });

    testWidgets('renders focus point at correct position', (tester) async {
      const cameraSize = Size(400, 600);
      await tester.binding.setSurfaceSize(cameraSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(focusPoint: Offset(0.5, 0.5)),
      );

      await tester.pumpWidget(
        BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: cameraSize.width,
                height: cameraSize.height,
                child: const VideoRecorderFocusPoint(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Positioned widget within VideoRecorderFocusPoint
      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(Positioned),
        ),
      );

      const indicatorSize = VideoRecorderFocusPoint.indicatorSize;

      expect(positioned.left, equals(cameraSize.width / 2 - indicatorSize / 2));
      expect(positioned.top, equals(cameraSize.height / 2 - indicatorSize / 2));
    });
  });
}
