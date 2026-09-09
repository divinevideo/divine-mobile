// ABOUTME: Widget tests for VideoEditorRemoveArea - displays delete icon that scales up when layer is over it.
// ABOUTME: Tests scale animation based on isLayerOverRemoveArea state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_remove_area.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorRemoveArea', () {
    late _MockVideoEditorMainBloc mockBloc;

    setUp(() {
      mockBloc = _MockVideoEditorMainBloc();

      when(() => mockBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget({VideoEditorMainState? state}) {
      if (state != null) {
        when(() => mockBloc.state).thenReturn(state);
      }

      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              playTimeNotifier: ValueNotifier(Duration.zero),
              playheadAdvancingNotifier: ValueNotifier<bool>(false),
              fromLibrary: false,
              onOpenCamera: () {},
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onAddEditTextLayer: ([layer]) async => null,
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              child: BlocProvider<VideoEditorMainBloc>.value(
                value: mockBloc,
                child: const VideoEditorRemoveArea(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders delete icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('has scale 1.0 when layer is not over remove area', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(state: const VideoEditorMainState()));
      await tester.pumpAndSettle();

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 1.0);
    });

    testWidgets('has scale > 1 when layer is over remove area', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          state: const VideoEditorMainState(isLayerOverRemoveArea: true),
        ),
      );
      await tester.pumpAndSettle();

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, greaterThan(1));
    });

    testWidgets('animates scale when isLayerOverRemoveArea changes', (
      tester,
    ) async {
      final stateController =
          StreamController<VideoEditorMainState>.broadcast();

      when(() => mockBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Initial scale should be 1.0
      var animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 1.0);

      // Emit new state with isLayerOverRemoveArea = true
      when(
        () => mockBloc.state,
      ).thenReturn(const VideoEditorMainState(isLayerOverRemoveArea: true));
      stateController.add(
        const VideoEditorMainState(isLayerOverRemoveArea: true),
      );

      // Pump a few frames to start animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After full animation
      await tester.pumpAndSettle();

      animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, greaterThan(1));

      await stateController.close();
    });
  });
}
