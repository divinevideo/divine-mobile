// ABOUTME: Tests for ClipOperationProgressOverlays: a running clip operation
// ABOUTME: hides the editor from screen readers and announces what it waits on.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/clip_operation_progress_overlays.dart';

import '../../helpers/text_lines.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

List<String> _captureAnnouncements(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data']! as Map<Object?, Object?>;
        announced.add(data['message']! as String);
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

// Carries its own progress, so the overlay does not read the plugin's
// progress stream.
const _importing = ClipEditorState(
  isImportingLibraryClips: true,
  libraryImportRenderId: 'library_import',
  libraryImportProgress: 0.5,
);

// The next picked clip, under its own render id.
const _importingNextClip = ClipEditorState(
  isImportingLibraryClips: true,
  libraryImportRenderId: 'library_import_2',
  libraryImportProgress: 0.25,
);

void main() {
  group(ClipOperationProgressOverlays, () {
    late _MockClipEditorBloc bloc;

    setUp(() {
      bloc = _MockClipEditorBloc();
    });

    Future<void> pump(
      WidgetTester tester, {
      Locale? locale,
      double textScale = 1,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: BlocProvider<ClipEditorBloc>.value(
              value: bloc,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Split'),
                    ),
                  ),
                  const ClipOperationProgressOverlays(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'hides the editor from screen readers from the first frame of an '
      'operation',
      (tester) async {
        whenListen(
          bloc,
          Stream.value(_importing),
          initialState: const ClipEditorState(),
        );
        await pump(tester);
        expect(find.semantics.byLabel('Split'), findsOne);

        // The overlay is still fully transparent in this frame.
        await tester.pump();

        expect(find.semantics.byLabel('Split'), findsNothing);
      },
    );

    testWidgets('keeps every German word whole on a small phone at the '
        'largest text size', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(
          isStabilizing: true,
          stabilizingClipId: 'clip',
          stabilizeRenderId: 'stabilize',
          stabilizeProgress: 0.4,
        ),
      );

      await pump(tester, locale: const Locale('de'), textScale: 3.12);
      await tester.pump();

      final de = lookupAppLocalizations(const Locale('de'));
      expect(tester.takeException(), isNull);
      expect(
        wordsSplitAcrossLines(
          tester,
          find.text(de.videoEditorStabilizeProgressLabel),
        ),
        isEmpty,
      );
    });

    testWidgets('scrolls instead of overflowing on a screen shorter than its '
        'content', (tester) async {
      tester.view.physicalSize = const Size(375, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(
          isStabilizing: true,
          stabilizingClipId: 'clip',
          stabilizeRenderId: 'stabilize',
          stabilizeProgress: 0.4,
        ),
      );

      await pump(tester, locale: const Locale('de'), textScale: 3.12);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('announces the operation it waits on', (tester) async {
      final announced = _captureAnnouncements(tester);
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: _importing,
      );

      await pump(tester);
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(announced, equals([l10n.videoEditorLibraryImportProgressLabel]));
    });

    testWidgets('announces an import once, not once per clip', (
      tester,
    ) async {
      final announced = _captureAnnouncements(tester);
      final states = StreamController<ClipEditorState>();
      addTearDown(states.close);
      whenListen(bloc, states.stream, initialState: const ClipEditorState());
      await pump(tester);

      states.add(_importing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(announced, hasLength(1));

      states.add(_importingNextClip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate(
          (widget) => widget is PartialCircleSpinner && widget.progress == 0.25,
        ),
        findsOne,
      );
      expect(announced, hasLength(1));
    });
  });
}
