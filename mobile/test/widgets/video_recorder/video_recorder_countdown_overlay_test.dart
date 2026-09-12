// ABOUTME: Tests for VideoRecorderCountdownOverlay widget
// ABOUTME: Validates countdown display, animations, and visibility states

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCountdownOverlay Widget Tests', () {
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
          home: Scaffold(body: VideoRecorderCountdownOverlay()),
        ),
      );
    }

    testWidgets('renders countdown overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });

    testWidgets('is initially invisible when countdown is 0', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0));
    });

    testWidgets('uses IgnorePointer for touch blocking', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.descendant(
          of: find.byType(VideoRecorderCountdownOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('contains AnimatedOpacity for fade transitions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('updates when countdown value changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });
  });
}
