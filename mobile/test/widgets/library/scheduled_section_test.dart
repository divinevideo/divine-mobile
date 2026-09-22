// ABOUTME: Widget tests for the Scheduled tab: row rendering per queue state
// ABOUTME: and the events its row menu dispatches.

import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/blocs/scheduled_posts/scheduled_posts_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/widgets/library/draft_status_badge.dart';
import 'package:openvine/widgets/library/scheduled_section.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';

class _MockScheduledPostsBloc
    extends MockBloc<ScheduledPostsEvent, ScheduledPostsState>
    implements ScheduledPostsBloc {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockDraftsLibraryBloc
    extends MockBloc<DraftsLibraryEvent, DraftsLibraryState>
    implements DraftsLibraryBloc {}

class _MockDraft extends Mock implements DivineVideoDraft {}

void main() {
  final en = AppLocalizationsEn();
  const owner =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  final publishAt = DateTime.utc(2026, 10, 1, 9, 30);

  late _MockScheduledPostsBloc bloc;
  late _MockBackgroundPublishBloc publishBloc;
  late _MockDraftsLibraryBloc draftsBloc;

  Event buildEvent({String d = 'video-1'}) => Event(
    owner,
    34236,
    [
      ['d', d],
      ['title', 'Plants'],
      ['image', 'https://cdn.example.com/thumb.jpg'],
    ],
    'A plant video',
    createdAt: publishAt.millisecondsSinceEpoch ~/ 1000,
  );

  ScheduledPostItem item({
    ScheduledPostStatus status = ScheduledPostStatus.scheduled,
    String d = 'video-1',
  }) {
    final event = buildEvent(d: d);
    return ScheduledPostItem(
      post: ScheduledPost(
        eventId: event.id,
        ownerPubkey: owner,
        draftId: 'draft-1',
        kind: 34236,
        signedEventJson: jsonEncode(event.toJson()),
        publishAt: event.createdAt,
        status: status,
        createdAt: DateTime.utc(2026, 9, 22),
      ),
      draft: null,
    );
  }

  setUpAll(() {
    registerFallbackValue(const ScheduledPostsStarted());
  });

  setUp(() {
    bloc = _MockScheduledPostsBloc();
    publishBloc = _MockBackgroundPublishBloc();
    when(() => publishBloc.state).thenReturn(const BackgroundPublishState());
    draftsBloc = _MockDraftsLibraryBloc();
    when(
      () => draftsBloc.state,
    ).thenReturn(const DraftsLibraryLoaded(drafts: []));
  });

  Widget buildWidget() {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<BackgroundPublishBloc>.value(value: publishBloc),
            BlocProvider<ScheduledPostsBloc>.value(value: bloc),
            BlocProvider<DraftsLibraryBloc>.value(value: draftsBloc),
          ],
          // The scope above resolves the repository; the sliver is what
          // renders, so the test supplies the scroll view it lives in.
          child: const ScheduledPostsDraftsRefresher(
            child: CustomScrollView(slivers: [ScheduledSectionSliver()]),
          ),
        ),
      ),
    );
  }

  group(ScheduledPostsDraftsRefresher, () {
    testWidgets('reloads the drafts list when a publish stops being in '
        'flight', (tester) async {
      final uploads = StreamController<BackgroundPublishState>();
      addTearDown(uploads.close);
      final draft = _MockDraft();
      when(() => draft.id).thenReturn('draft-1');
      when(() => draft.scheduledAt).thenReturn(publishAt);
      when(() => draft.title).thenReturn('Plants');
      when(() => draft.coverThumbnailPath).thenReturn(null);
      whenListen(
        publishBloc,
        uploads.stream,
        initialState: BackgroundPublishState(
          uploads: [BackgroundUpload(draft: draft, result: null, progress: .5)],
        ),
      );
      when(() => bloc.state).thenReturn(
        const ScheduledPostsState(status: ScheduledPostsStatus.loaded),
      );

      await tester.pumpWidget(buildWidget());
      verifyNever(() => draftsBloc.add(const DraftsLibraryLoadRequested()));

      uploads.add(const BackgroundPublishState());
      await tester.pump();

      verify(
        () => draftsBloc.add(const DraftsLibraryLoadRequested()),
      ).called(1);
    });
  });

  group(ScheduledSectionSliver, () {
    group('renders', () {
      testWidgets('nothing at all while loading', (tester) async {
        when(() => bloc.state).thenReturn(
          const ScheduledPostsState(status: ScheduledPostsStatus.loading),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryScheduledSectionTitle), findsNothing);
        expect(find.byType(ListTile), findsNothing);
      });

      testWidgets('nothing at all with nothing scheduled', (tester) async {
        when(() => bloc.state).thenReturn(
          const ScheduledPostsState(status: ScheduledPostsStatus.loaded),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryScheduledSectionTitle), findsNothing);
        expect(find.byType(ListTile), findsNothing);
      });

      testWidgets('one row, not two, while a post is both uploading and '
          'enqueued', (tester) async {
        final draft = _MockDraft();
        when(() => draft.id).thenReturn('draft-1');
        when(() => draft.scheduledAt).thenReturn(publishAt);
        when(() => draft.title).thenReturn('Plants');
        when(() => draft.coverThumbnailPath).thenReturn(null);
        when(() => publishBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: .5),
            ],
          ),
        );
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            // Same draft the upload above carries.
            items: [item()],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text(en.libraryScheduledBadgeUploading), findsNothing);
      });

      testWidgets('both headers once there is a row to show', (tester) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item()],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryScheduledSectionTitle), findsOneWidget);
        // The closing label separates the drafts under it from this run.
        expect(find.text(en.libraryTabDrafts), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
      });

      testWidgets('a scheduled row with its time and no badge', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item()],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text('Plants'), findsOneWidget);
        expect(find.textContaining('Oct 1'), findsOneWidget);
        // The header already says "Scheduled"; the row repeats nothing.
        expect(find.byType(DraftStatusBadge), findsNothing);
      });

      testWidgets('the waiting badge before the relay accepts it', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item(status: ScheduledPostStatus.pendingSubmit)],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(
          find.text(en.libraryScheduledBadgeWaitingForServer),
          findsOneWidget,
        );
      });

      testWidgets('the failed badge and a retry action', (tester) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item(status: ScheduledPostStatus.failed)],
          ),
        );

        await tester.pumpWidget(buildWidget());
        expect(find.text(en.libraryScheduledBadgeFailed), findsOneWidget);

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryScheduledActionRetry), findsOneWidget);
      });

      testWidgets('a row for a post scheduled on another device', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            remotePosts: [
              RemoteScheduledPost(eventId: 'f' * 64, publishAt: publishAt),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());
        expect(find.text(en.libraryScheduledRemoteTitle), findsOneWidget);

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        // Only cancelling is possible for a post this device cannot re-sign.
        expect(find.text(en.libraryScheduledActionCancel), findsOneWidget);
        expect(find.text(en.libraryScheduledActionReschedule), findsNothing);
      });
    });

    group('actions', () {
      setUp(() {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item()],
          ),
        );
      });

      Future<void> openMenu(WidgetTester tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();
      }

      testWidgets('post now dispatches the event', (tester) async {
        await openMenu(tester);

        await tester.tap(find.text(en.libraryScheduledActionPublishNow));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(any(that: isA<ScheduledPostsPublishNowRequested>())),
        ).called(1);
      });

      testWidgets('cancel asks first and only then dispatches', (
        tester,
      ) async {
        await openMenu(tester);

        await tester.tap(find.text(en.libraryScheduledActionCancel));
        await tester.pumpAndSettle();
        expect(find.text(en.libraryScheduledCancelTitle), findsOneWidget);
        verifyNever(
          () => bloc.add(any(that: isA<ScheduledPostsCancelRequested>())),
        );

        await tester.tap(find.text(en.libraryScheduledCancelConfirm));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(any(that: isA<ScheduledPostsCancelRequested>())),
        ).called(1);
      });

      testWidgets('change time opens the picker', (tester) async {
        await openMenu(tester);

        await tester.tap(find.text(en.libraryScheduledActionReschedule));
        await tester.pumpAndSettle();

        expect(find.byType(ScheduleDateTimeSheet), findsOneWidget);
      });
    });
  });
}
