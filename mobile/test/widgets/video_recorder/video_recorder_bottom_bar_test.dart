// ABOUTME: Tests for VideoRecorderBottomBar widget
// ABOUTME: Validates bottom bar UI, mode selector, library button, and opacity

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderBottomBar, () {
    late _MockClipLibraryService mockClipLibrary;
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() async {
      mockClipLibrary = _MockClipLibraryService();
      when(() => mockClipLibrary.getAllClips()).thenAnswer((_) async => []);
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          clipLibraryServiceProvider.overrideWithValue(mockClipLibrary),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [VideoRecorderBottomBar()])),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderBottomBar', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderModeSelectorWheel', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders $VideoRecorderLibraryButton', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(VideoRecorderLibraryButton), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses $SafeArea with top: false', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final safeArea = tester.widget<SafeArea>(
          find.descendant(
            of: find.byType(VideoRecorderBottomBar),
            matching: find.byType(SafeArea),
          ),
        );
        expect(safeArea.top, isFalse);
      });

      testWidgets('wraps content in $AnimatedOpacity', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(
          find.descendant(
            of: find.byType(VideoRecorderBottomBar),
            matching: find.byType(AnimatedOpacity),
          ),
          findsOneWidget,
        );
      });

      testWidgets('library button is aligned to center-left', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final aligns = tester.widgetList<Align>(
          find.descendant(
            of: find.byType(VideoRecorderBottomBar),
            matching: find.byType(Align),
          ),
        );

        final leftAlign = aligns.where(
          (a) => a.alignment == Alignment.centerLeft,
        );
        expect(leftAlign, isNotEmpty);
      });
    });

    group('opacity', () {
      testWidgets('is fully opaque when not recording', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(VideoRecorderBottomBar),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });
    });
  });
}
