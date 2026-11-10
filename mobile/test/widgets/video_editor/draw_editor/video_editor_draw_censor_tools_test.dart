// ABOUTME: Tests the censor tools of the draw editor: a tool's name stays
// ABOUTME: whole at a larger text size, its item widening to fit it.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_censor_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

void main() {
  group(VideoEditorDrawCensorTools, () {
    group('renders', () {
      testWidgets('a long German tool name whole at a larger text size', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.65;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final bloc = _MockVideoEditorDrawBloc();
        when(() => bloc.state).thenReturn(const VideoEditorDrawState());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: BlocProvider<VideoEditorDrawBloc>.value(
                    value: bloc,
                    child: VideoEditorDrawCensorTools(onToolSelected: (_) {}),
                  ),
                ),
              ),
            ),
          ),
        );

        final name = lookupAppLocalizations(
          const Locale('de'),
        ).videoEditorBlurLabel;
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(name))
              .didExceedMaxLines,
          isFalse,
        );
      });
    });
  });
}
