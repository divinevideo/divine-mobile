// ABOUTME: Widget tests for the Scheduled tab: row rendering per queue state
// ABOUTME: and the events its row menu dispatches.

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
import 'package:openvine/blocs/scheduled_posts/scheduled_posts_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/scheduled_tab.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';

class _MockScheduledPostsBloc
    extends MockBloc<ScheduledPostsEvent, ScheduledPostsState>
    implements ScheduledPostsBloc {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

void main() {
  final en = AppLocalizationsEn();
  const owner =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  final publishAt = DateTime.utc(2026, 10, 1, 9, 30);

  late _MockScheduledPostsBloc bloc;
  late _MockBackgroundPublishBloc publishBloc;

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
          ],
          // The page above resolves the repository; the view is what renders.
          child: const ScheduledTabView(),
        ),
      ),
    );
  }

  group(ScheduledTab, () {
    group('renders', () {
      testWidgets('a spinner while loading', (tester) async {
        when(() => bloc.state).thenReturn(
          const ScheduledPostsState(status: ScheduledPostsStatus.loading),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      });

      testWidgets('the empty state with nothing scheduled', (tester) async {
        when(() => bloc.state).thenReturn(
          const ScheduledPostsState(status: ScheduledPostsStatus.loaded),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryScheduledEmptyTitle), findsOneWidget);
      });

      testWidgets('a scheduled row with its time and badge', (tester) async {
        when(() => bloc.state).thenReturn(
          ScheduledPostsState(
            status: ScheduledPostsStatus.loaded,
            items: [item()],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text('Plants'), findsOneWidget);
        expect(find.text(en.libraryScheduledBadgeScheduled), findsOneWidget);
        expect(find.textContaining('Oct 1'), findsOneWidget);
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
