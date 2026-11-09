// ABOUTME: Tests the page where a creator manages their video replies: pinning
// ABOUTME: and hiding one, and what shows while they load or fail to.

import 'package:bloc_test/bloc_test.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_replies/video_replies_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/sticker_responses_filter_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/video_replies/video_replies_screen.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoRepliesCubit extends MockCubit<VideoRepliesState>
    implements VideoRepliesCubit {}

class _MockFeedRepository extends Mock implements FeedRepository {}

UserProfile _profile(String pubkey, String displayName) => UserProfile(
  pubkey: pubkey,
  displayName: displayName,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'e' * 64,
);

VideoEvent _reply(int n, {String? name}) => VideoEvent(
  id: '$n'.padLeft(64, '0'),
  pubkey: '$n'.padLeft(64, 'f'),
  createdAt: 1778120201 + n,
  content: '',
  timestamp: DateTime.utc(2026),
  authorName: name,
);

void main() {
  group(VideoRepliesView, () {
    late _MockVideoRepliesCubit cubit;
    late Map<String, UserProfile> profiles;
    // The replies the creator's content settings would hide.
    late Set<String> hiddenBySettings;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockVideoRepliesCubit();
      profiles = {};
      hiddenBySettings = <String>{};
      when(() => cubit.pinToggled(any())).thenAnswer((_) async {});
      when(() => cubit.hideToggled(any())).thenAnswer((_) async {});
      when(() => cubit.load()).thenAnswer((_) async {});
    });

    // The profiles of the replies' authors, read when a reply came without
    // its author's name, and the creator's content settings.
    List<Override> profileOverrides() => [
      for (final n in [1, 2])
        fetchUserProfileProvider(
          _reply(n).pubkey,
        ).overrideWith((ref) async => profiles[_reply(n).pubkey]),
      repliesHiddenBySettingsProvider.overrideWithValue(
        (reply) => hiddenBySettings.contains(reply.id),
      ),
    ];

    Future<void> pump(WidgetTester tester, VideoRepliesState state) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(
        ProviderScope(
          overrides: profileOverrides(),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VideoRepliesCubit>.value(
              value: cubit,
              child: const VideoRepliesView(),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('each reply, which one is pinned and which hidden', (
        tester,
      ) async {
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [
              _reply(1, name: 'Alice'),
              _reply(2, name: 'Bob'),
            ],
            curation: RepliesCuration(
              pinnedId: _reply(1).id,
              hiddenIds: {_reply(2).id},
            ),
          ),
        );

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesPinned), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesHidden), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesUnpin), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesShow), findsOneWidget);
      });

      testWidgets('a reply of an account the creator blocked as hidden, even '
          'when pinned', (tester) async {
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [
              _reply(1, name: 'Alice'),
              _reply(2, name: 'Bob'),
            ],
            curation: RepliesCuration(
              pinnedId: _reply(1).id,
              hiddenAuthors: {_reply(1).pubkey},
            ),
          ),
        );

        // Viewers do not see it, pinned or not.
        expect(find.text(l10n.videoStickerRepliesHidden), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesPinned), findsNothing);
        expect(find.text(l10n.videoStickerRepliesShow), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesUnpin), findsOneWidget);
      });

      testWidgets("the name in a reply's profile when it came without one", (
        tester,
      ) async {
        profiles[_reply(1).pubkey] = _profile(_reply(1).pubkey, 'Carol');
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [_reply(1), _reply(2)],
          ),
        );
        await tester.pump();

        expect(find.text('Carol'), findsOneWidget);
        expect(
          find.text(UserProfile.generatedNameFor(_reply(2).pubkey)),
          findsOneWidget,
        );
      });

      testWidgets(
        "a reply blurred by the creator's settings, not its own tag",
        (
          tester,
        ) async {
          await pump(
            tester,
            VideoRepliesState(
              status: VideoRepliesStatus.loaded,
              replies: [
                _reply(1, name: 'Alice').copyWith(warnLabels: ['nudity']),
                // Tagged by its author, while the creator's settings show it.
                _reply(2, name: 'Bob').copyWith(contentWarningLabels: ['gore']),
              ],
            ),
          );

          expect(find.byType(ImageFiltered), findsOneWidget);
          expect(
            find.ancestor(
              of: find.byType(ImageFiltered),
              matching: find.widgetWithText(Row, 'Alice'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('that there are none yet', (tester) async {
        await pump(
          tester,
          const VideoRepliesState(status: VideoRepliesStatus.loaded),
        );

        expect(find.text(l10n.videoStickerRepliesEmpty), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('pins and hides a reply', (tester) async {
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [_reply(1, name: 'Alice')],
          ),
        );

        await tester.tap(find.text(l10n.videoStickerRepliesPin));
        await tester.tap(find.text(l10n.videoStickerRepliesHide));

        verify(() => cubit.pinToggled(_reply(1).id)).called(1);
        verify(() => cubit.hideToggled(_reply(1).id)).called(1);
      });

      testWidgets('pins and hides an addressable reply by its address', (
        tester,
      ) async {
        final reply = _reply(1, name: 'Alice').copyWith(
          addressableDTag: 'reply-1',
        );
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [reply],
          ),
        );

        await tester.tap(find.text(l10n.videoStickerRepliesPin));
        await tester.tap(find.text(l10n.videoStickerRepliesHide));

        // By address, so the pin and the hide outlive an edit of the reply.
        verify(() => cubit.pinToggled(reply.addressableId!)).called(1);
        verify(() => cubit.hideToggled(reply.addressableId!)).called(1);
      });

      testWidgets('opens a reply in the feed under the replies title', (
        tester,
      ) async {
        final opened = <Object?>[];
        when(() => cubit.state).thenReturn(
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [
              _reply(1, name: 'Alice'),
              _reply(2, name: 'Bob'),
            ],
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider<VideoRepliesCubit>.value(
                value: cubit,
                child: const VideoRepliesView(),
              ),
              routes: [
                GoRoute(
                  path: ':feed',
                  builder: (_, state) {
                    opened.add(state.extra);
                    return const Scaffold();
                  },
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
              ...profileOverrides(),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.tap(find.text('Bob'));
        await tester.pumpAndSettle();

        expect(
          opened.single,
          isA<PooledFullscreenVideoFeedArgs>()
              .having(
                (args) => args.contextTitle,
                'contextTitle',
                l10n.videoStickerRepliesManageTitle,
              )
              .having(
                (args) => args.initialVideoId,
                'initialVideoId',
                _reply(2).id,
              ),
        );
      });

      testWidgets("never plays a reply the creator's settings would hide", (
        tester,
      ) async {
        final opened = <Object?>[];
        hiddenBySettings = {_reply(1).id};
        when(() => cubit.state).thenReturn(
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [
              _reply(1, name: 'Alice'),
              _reply(2, name: 'Bob'),
            ],
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider<VideoRepliesCubit>.value(
                value: cubit,
                child: const VideoRepliesView(),
              ),
              routes: [
                GoRoute(
                  path: ':feed',
                  builder: (_, state) {
                    opened.add(state.extra);
                    return const Scaffold();
                  },
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
              ...profileOverrides(),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        // Still listed, so the creator can hide it, but it does not open.
        expect(find.text('Alice'), findsOneWidget);
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();
        expect(opened, isEmpty);

        // Nor does one the settings hide only after the list was drawn.
        hiddenBySettings.add(_reply(2).id);
        await tester.tap(find.text('Bob'));
        await tester.pumpAndSettle();
        expect(opened, isEmpty);
        hiddenBySettings.remove(_reply(2).id);

        // Nor does it play in the feed another reply opens.
        await tester.tap(find.text('Bob'));
        await tester.pumpAndSettle();
        expect(
          opened.single,
          isA<PooledFullscreenVideoFeedArgs>().having(
            (args) => (args.source as VideoListViewSource).videos.map(
              (video) => video.id,
            ),
            'videos',
            [_reply(2).id],
          ),
        );
      });

      testWidgets('reads the replies again after they failed to load', (
        tester,
      ) async {
        await pump(
          tester,
          const VideoRepliesState(status: VideoRepliesStatus.failure),
        );

        expect(find.text(l10n.videoStickerRepliesLoadFailed), findsOneWidget);
        await tester.tap(find.text(l10n.videoStickerRepliesRetry));

        verify(() => cubit.load()).called(1);
      });

      testWidgets('tells when a change could not be saved', (tester) async {
        final loaded = VideoRepliesState(
          status: VideoRepliesStatus.loaded,
          replies: [_reply(1)],
        );
        whenListen(
          cubit,
          Stream.value(
            loaded.copyWith(saveStatus: VideoRepliesSaveStatus.failed),
          ),
          initialState: loaded,
        );
        await pump(tester, loaded);
        await tester.pump();

        expect(find.text(l10n.videoStickerRepliesSaveFailed), findsOneWidget);
      });
    });
  });
}
