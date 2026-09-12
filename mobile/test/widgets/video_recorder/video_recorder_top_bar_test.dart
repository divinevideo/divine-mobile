// ABOUTME: Tests for VideoRecorderTopBar widget
// ABOUTME: Validates top bar UI, close button, and confirm button

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderTopBar Widget Tests', () {
    late _MockVideoRecorderBloc recorderBloc;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [VideoRecorderTopBar()])),
          ),
        ),
      );
    }

    testWidgets('renders top bar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoRecorderTopBar), findsOneWidget);
    });

    testWidgets('contains close button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsLabel('Close video recorder'), findsOneWidget);
    });

    testWidgets('contains next button when hasClips', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Pump to allow AnimatedSwitcher to finish
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Continue to video editor'), findsOneWidget);
    });

    testWidgets('is aligned at top center', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final align = tester.widget<Align>(find.byType(Align).first);

      expect(align.alignment, equals(Alignment.topCenter));
    });

    testWidgets('uses SafeArea for status bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}
