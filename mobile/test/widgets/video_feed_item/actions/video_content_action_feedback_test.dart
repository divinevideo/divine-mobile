// ABOUTME: Tests the shared feedback for per-video content actions.
// ABOUTME: Runs each result against a real VineBottomSheet on a real navigator.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoContentActionsBloc
    extends MockBloc<VideoContentActionsEvent, VideoContentActionsState>
    implements VideoContentActionsBloc {}

const _sheetBodyText = 'sheet body';

/// Opens a [VineBottomSheet] whose body is built by [body] and returns once it
/// has settled. [body] receives a context inside the sheet route.
Future<void> _pumpOpenSheet(
  WidgetTester tester, {
  required Widget Function(BuildContext sheetContext) body,
}) async {
  late BuildContext opener;
  await tester.pumpWidget(
    testMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            opener = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  unawaited(
    VineBottomSheet.show<void>(
      context: opener,
      body: Builder(builder: body),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showVideoContentActionFeedback', () {
    late BuildContext sheetContext;

    Future<void> pumpSheet(WidgetTester tester) => _pumpOpenSheet(
      tester,
      body: (context) {
        sheetContext = context;
        return const Text(_sheetBodyText);
      },
    );

    testWidgets('closes the sheet, then confirms a successful save', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(_sheetBodyText), findsOneWidget);

      showVideoContentActionFeedback(
        sheetContext,
        VideoContentSaveResult(succeeded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.shareAddedToBookmarks), findsOneWidget);
    });

    testWidgets('names the network when a save timed out', (tester) async {
      await pumpSheet(tester);

      showVideoContentActionFeedback(
        sheetContext,
        VideoContentSaveResult(
          succeeded: false,
          failure: BookmarkToggleFailure.timedOut,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.profileSetupNoRelaysConnected), findsOneWidget);
    });

    testWidgets('names the library a clip was saved to', (tester) async {
      await pumpSheet(tester);

      showVideoContentActionFeedback(
        sheetContext,
        VideoContentClipImportResult(succeeded: true, libraryTitle: 'x'),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.shareSheetSavedClipToClips('x')), findsOneWidget);
    });

    testWidgets('copies the event ID and confirms it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpSheet(tester);

      showVideoContentActionFeedback(
        sheetContext,
        VideoContentCopiedToClipboard(
          kind: VideoContentCopiedKind.eventId,
          text: 'nevent1synthetic',
        ),
      );
      await tester.pumpAndSettle();

      expect(copied, equals(['nevent1synthetic']));
      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.shareCopiedEventId), findsOneWidget);
    });

    testWidgets('closes the sheet before reporting a failed action', (
      tester,
    ) async {
      await pumpSheet(tester);

      showVideoContentActionFeedback(
        sheetContext,
        VideoContentActionFailure(),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.shareActionFailed), findsOneWidget);
    });
  });

  group(VideoContentActionsFeedbackListener, () {
    late _MockVideoContentActionsBloc bloc;

    setUp(() => bloc = _MockVideoContentActionsBloc());

    testWidgets('reports a result the bloc emits', (tester) async {
      final results = StreamController<VideoContentActionsState>();
      addTearDown(results.close);
      whenListen(
        bloc,
        results.stream,
        initialState: const VideoContentActionsState(),
      );
      await _pumpOpenSheet(
        tester,
        body: (_) => BlocProvider<VideoContentActionsBloc>.value(
          value: bloc,
          child: const VideoContentActionsFeedbackListener(
            child: Text(_sheetBodyText),
          ),
        ),
      );

      results.add(
        VideoContentActionsState(
          actionResult: VideoContentSaveResult(succeeded: true, removed: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_sheetBodyText), findsNothing);
      expect(find.text(l10n.shareRemovedFromBookmarks), findsOneWidget);
    });
  });

  group('requestAddToClips', () {
    late _MockVideoContentActionsBloc bloc;

    setUpAll(
      () => registerFallbackValue(const VideoContentSaveRequested()),
    );

    setUp(() {
      bloc = _MockVideoContentActionsBloc();
      when(() => bloc.state).thenReturn(const VideoContentActionsState());
      when(() => bloc.defaultClipTitle).thenReturn('Default title');
    });

    Future<void> pumpSheetAndRequest(WidgetTester tester) async {
      await _pumpOpenSheet(
        tester,
        body: (_) => BlocProvider<VideoContentActionsBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => requestAddToClips(context),
              child: const Text(_sheetBodyText),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_sheetBodyText));
      await tester.pumpAndSettle();
    }

    testWidgets('prompts with the default title and adds the chosen one', (
      tester,
    ) async {
      await pumpSheetAndRequest(tester);

      expect(find.text('Default title'), findsOneWidget);
      await tester.tap(find.text(l10n.shareSheetSaveClip));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const VideoContentAddToClipsRequested(libraryTitle: 'Default title'),
        ),
      ).called(1);
    });

    testWidgets('adds nothing when the prompt is cancelled', (tester) async {
      await pumpSheetAndRequest(tester);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });
  });
}
