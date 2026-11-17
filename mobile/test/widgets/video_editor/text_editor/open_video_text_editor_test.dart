// ABOUTME: Pins that the text editor closes its sub-editor when dismissed, and
// ABOUTME: leaves the editor's closed blocs alone when the editor goes away.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/widgets/video_editor/text_editor/open_video_text_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _homePath = '/';
const _editorPath = '/editor';

/// The editor's page as the app router builds it: its blocs are created and
/// closed with the page, the way `VideoEditorScreen` provides them.
class _EditorPage extends StatelessWidget {
  const _EditorPage();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VideoEditorMainBloc()),
        BlocProvider(create: (_) => VideoEditorTextBloc()),
      ],
      child: const Scaffold(body: _EditorBody()),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  group('openVideoTextEditor', () {
    late SharedPreferences prefs;
    late GoRouter router;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      router = GoRouter(
        initialLocation: _homePath,
        routes: [
          GoRoute(path: _homePath, builder: (_, _) => const SizedBox()),
          GoRoute(path: _editorPath, builder: (_, _) => const _EditorPage()),
        ],
      );
      addTearDown(router.dispose);
    });

    Future<BuildContext> pumpEditor(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // The editor opens over the page the user came from, a feed tab say.
      unawaited(router.push<void>(_editorPath));
      await tester.pumpAndSettle();
      return tester.element(find.byType(_EditorBody));
    }

    testWidgets('closes the panels and the sub-editor when the text editor '
        'is dismissed', (tester) async {
      final context = await pumpEditor(tester);
      final mainBloc = context.read<VideoEditorMainBloc>();
      final textBloc = context.read<VideoEditorTextBloc>();

      final opened = openVideoTextEditor(
        context,
        mainBloc: mainBloc,
        textBloc: textBloc,
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoTextEditorScreen), findsOneWidget);
      expect(mainBloc.state.openSubEditor, equals(SubEditorType.text));

      textBloc.add(const VideoEditorTextColorPickerToggled());
      await tester.pumpAndSettle();
      expect(textBloc.state.showColorPicker, isTrue);

      router.pop();
      await tester.pumpAndSettle();

      expect(await opened, isNull);
      expect(mainBloc.state.openSubEditor, isNull);
      expect(textBloc.state.showColorPicker, isFalse);
    });

    testWidgets('returns null without touching the closed editor blocs when '
        'a navigation drops the editor under the text editor', (
      tester,
    ) async {
      final context = await pumpEditor(tester);
      final mainBloc = context.read<VideoEditorMainBloc>();
      final textBloc = context.read<VideoEditorTextBloc>();

      final opened = openVideoTextEditor(
        context,
        mainBloc: mainBloc,
        textBloc: textBloc,
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoTextEditorScreen), findsOneWidget);

      // What a notification tap, a deep link or a home-screen quick action
      // to a page below the editor does: the editor's page goes in this
      // frame, and the text editor above it fades out after it.
      router.go(_homePath);
      await tester.pumpAndSettle();

      expect(find.byType(_EditorBody), findsNothing);
      expect(mainBloc.isClosed, isTrue);
      expect(textBloc.isClosed, isTrue);
      expect(await opened, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
