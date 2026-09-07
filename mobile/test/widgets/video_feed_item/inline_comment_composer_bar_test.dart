// ABOUTME: Widget tests for InlineCommentComposerBar — the bottom-of-screen
// ABOUTME: comment field used by the fullscreen video player on
// ABOUTME: Explore / Search / Profile entry points.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';

class _MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockInlineCommentComposerCubit
    extends MockCubit<InlineCommentComposerState>
    implements InlineCommentComposerCubit {}

void main() {
  group(InlineCommentComposerBar, () {
    late _MockFullscreenFeedBloc fullscreenBloc;
    late _MockInlineCommentComposerCubit composerCubit;

    VideoEvent buildVideo() {
      final now = DateTime.now();
      return VideoEvent(
        id: 'video-id',
        pubkey: 'author-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'caption',
        videoUrl: 'https://example.com/v.mp4',
      );
    }

    FullscreenFeedState stateWithVideo(VideoEvent video) {
      return FullscreenFeedState(
        status: FullscreenFeedStatus.ready,
        videos: [video],
      );
    }

    setUpAll(() {
      registerFallbackValue(buildVideo());
    });

    setUp(() {
      fullscreenBloc = _MockFullscreenFeedBloc();
      composerCubit = _MockInlineCommentComposerCubit();

      when(
        () => fullscreenBloc.state,
      ).thenReturn(stateWithVideo(buildVideo()));
      when(
        () => composerCubit.state,
      ).thenReturn(const InlineCommentComposerState());
    });

    tearDown(() {
      fullscreenBloc.close();
      composerCubit.close();
    });

    Widget buildBar() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<FullscreenFeedBloc>.value(value: fullscreenBloc),
              BlocProvider<InlineCommentComposerCubit>.value(
                value: composerCubit,
              ),
            ],
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: InlineCommentComposerBar(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the "Add comment..." hint', (tester) async {
      await tester.pumpWidget(buildBar());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoOverlayCommentBarHint), findsOneWidget);
    });

    testWidgets('hides the send button when the field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      expect(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        findsNothing,
      );
    });

    testWidgets('shows the send button once the user types text', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      await tester.enterText(
        find.bySemanticsIdentifier('inline_comment_composer_field'),
        'hello',
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        findsOneWidget,
      );
    });

    testWidgets(
      'configures the field to grow from 1 to 5 lines on long input, '
      'matching the comments-sheet composer',
      (tester) async {
        await tester.pumpWidget(buildBar());

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.bySemanticsIdentifier('inline_comment_composer_field'),
            matching: find.byType(TextField),
          ),
        );

        expect(field.minLines, 1);
        expect(field.maxLines, 5);
        expect(field.keyboardType, TextInputType.multiline);
      },
    );

    testWidgets('enables spell check on the composer field', (tester) async {
      await tester.pumpWidget(buildBar());

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.bySemanticsIdentifier('inline_comment_composer_field'),
          matching: find.byType(TextField),
        ),
      );

      expect(
        field.spellCheckConfiguration,
        DivineTextField.defaultSpellCheckConfiguration,
      );
    });

    testWidgets(
      'still hides the send button when the field only has whitespace',
      (tester) async {
        await tester.pumpWidget(buildBar());

        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          '   \n  ',
        );
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping send forwards the text + active video to the cubit and '
      'clears the field',
      (tester) async {
        final activeVideo = buildVideo();
        when(
          () => fullscreenBloc.state,
        ).thenReturn(stateWithVideo(activeVideo));
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildBar());
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'great video!',
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        );
        await tester.pump();

        verify(
          () => composerCubit.submit(
            video: activeVideo,
            content: 'great video!',
          ),
        ).called(1);

        // Field is cleared after submit so the send affordance disappears.
        expect(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'submitting via the keyboard send action triggers the cubit',
      (tester) async {
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildBar());
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'hi',
        );
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();

        verify(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: 'hi',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'shows the success snackbar when the cubit emits submitted',
      (tester) async {
        whenListen<InlineCommentComposerState>(
          composerCubit,
          Stream.fromIterable(const [
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitting,
            ),
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitted,
            ),
          ]),
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());
        await tester.pump();
        // Allow the snackbar entrance animation to settle.
        await tester.pump(const Duration(seconds: 1));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoOverlayCommentPostedSnackbar),
          findsOneWidget,
        );
        verify(() => composerCubit.acknowledge()).called(1);
      },
    );

    testWidgets(
      'shows the failure snackbar when the cubit emits failure',
      (tester) async {
        whenListen<InlineCommentComposerState>(
          composerCubit,
          Stream.fromIterable(const [
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitting,
            ),
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.failure,
            ),
          ]),
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoOverlayCommentPostFailedSnackbar),
          findsOneWidget,
        );
        verify(() => composerCubit.acknowledge()).called(1);
      },
    );

    testWidgets(
      'restores the draft and re-shows the send button when the cubit '
      'emits failure after an optimistic clear',
      (tester) async {
        // Reproduces the full submit-then-fail loop the user sees in
        // production: type → tap send (optimistic clear) → cubit emits
        // failure → bar restores the typed text from `_pendingDraft`
        // so the user can retry without retyping. Matches
        // `CommentComposerBloc._emitSubmitRollback` of `mainInputText`
        // on publish error.
        // Uses a [StreamController] so the failure emits AFTER the tap
        // — `whenListen` with `Stream.fromIterable` would drain the
        // sequence on subscription, before the test has had a chance
        // to capture a draft.
        final activeVideo = buildVideo();
        when(
          () => fullscreenBloc.state,
        ).thenReturn(stateWithVideo(activeVideo));
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});
        final stateController = StreamController<InlineCommentComposerState>();
        addTearDown(stateController.close);
        whenListen<InlineCommentComposerState>(
          composerCubit,
          stateController.stream,
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());

        const draft = 'lost in the void';
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          draft,
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        );
        await tester.pump();

        // Now drive the failure through.
        stateController.add(
          const InlineCommentComposerState(
            status: InlineCommentComposerStatus.failure,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Draft is back in the field and the send affordance is back
        // along with it (since `_hasText` flips true on the restored
        // controller value).
        expect(find.text(draft), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not clobber freshly-typed text if the user starts a new '
      'draft before the failure arrives',
      (tester) async {
        final activeVideo = buildVideo();
        when(
          () => fullscreenBloc.state,
        ).thenReturn(stateWithVideo(activeVideo));
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});
        final stateController = StreamController<InlineCommentComposerState>();
        addTearDown(stateController.close);
        whenListen<InlineCommentComposerState>(
          composerCubit,
          stateController.stream,
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'first draft',
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        );
        await tester.pump();

        // User starts typing a new comment before the failure lands.
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'new thought',
        );
        await tester.pump();

        // Now the publish fails. The bar must NOT overwrite "new
        // thought" with the stale "first draft" — the guard on
        // `_controller.text.isEmpty` is what protects us.
        stateController.add(
          const InlineCommentComposerState(
            status: InlineCommentComposerStatus.failure,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('new thought'), findsOneWidget);
        expect(find.text('first draft'), findsNothing);
      },
    );

    testWidgets('does nothing on send when there is no active video', (
      tester,
    ) async {
      when(
        () => fullscreenBloc.state,
      ).thenReturn(FullscreenFeedState());

      await tester.pumpWidget(buildBar());
      await tester.enterText(
        find.bySemanticsIdentifier('inline_comment_composer_field'),
        'orphan',
      );
      await tester.pump();
      await tester.tap(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
      );
      await tester.pump();

      verifyNever(
        () => composerCubit.submit(
          video: any(named: 'video'),
          content: any(named: 'content'),
        ),
      );
    });
  });
}
