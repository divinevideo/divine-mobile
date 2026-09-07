import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

ProfileFeedCubit _stubbedProfileFeedCubit() {
  final cubit = _MockProfileFeedCubit();
  whenListen(
    cubit,
    const Stream<ProfileFeedState>.empty(),
    initialState: const ProfileFeedState(status: ProfileFeedStatus.ready),
  );
  return cubit;
}

const _ownPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

DivineVideoDraft _createTestDraft({String title = 'Test Draft'}) {
  return DivineVideoDraft.create(
    clips: [
      DivineVideoClip(
        id: 'clip-1',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2025, 12, 13),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      ),
    ],
    title: title,
    description: 'Test description',
    hashtags: {},
    selectedApproach: 'camera',
  );
}

List<model.VideoEvent> _createTestVideos({
  required String pubkey,
  int count = 2,
}) {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
  return List.generate(
    count,
    (i) => model.VideoEvent(
      id: 'video-$i',
      pubkey: pubkey,
      createdAt: nowUnix - i,
      content: 'Video $i',
      timestamp: now.subtract(Duration(seconds: i)),
      title: 'Video $i',
      videoUrl: 'https://example.com/v$i.mp4',
      thumbnailUrl: 'https://example.com/thumb$i.jpg',
    ),
  );
}

void main() {
  group(ProfileVideosGrid, () {
    late _MockAuthService mockAuth;
    late _MockBackgroundPublishBloc mockBloc;
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockAuth = _MockAuthService();
      mockBloc = _MockBackgroundPublishBloc();
      mockDmRepository = _MockDmRepository();
      when(() => mockBloc.state).thenReturn(const BackgroundPublishState());
      debugProfileVideosGridBuildCount = 0;
    });

    Widget buildSubject({
      required String userIdHex,
      List<model.VideoEvent> videos = const [],
      bool isLoading = false,
      List<PendingCollaboratorInviteGroup> pendingInviteGroups = const [],
      Locale? locale,
      List<Override> additionalOverrides = const [],
    }) {
      final profileFeedCubit = _stubbedProfileFeedCubit();
      return testProviderScope(
        additionalOverrides: [
          ...additionalOverrides,
          collaboratorInviteRecoveryRepositoryProvider.overrideWithValue(
            mockDmRepository,
          ),
          pendingCollaboratorInviteGroupsProvider.overrideWith(
            (ref) => Stream.value(pendingInviteGroups),
          ),
        ],
        mockAuthService: mockAuth,
        child: BlocProvider<BackgroundPublishBloc>.value(
          value: mockBloc,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<ProfileFeedCubit>.value(
                value: profileFeedCubit,
                child: ProfileVideosGrid(
                  videos: videos,
                  userIdHex: userIdHex,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('empty state when no videos and not own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildSubject(userIdHex: _otherPubkey));

        expect(find.text(l10n.profileNoVideosTitle), findsOneWidget);
        expect(find.text(l10n.profileNoVideosOtherSubtitle), findsOneWidget);
      });

      testWidgets('empty state with own profile message when own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildSubject(userIdHex: _ownPubkey));

        expect(find.text(l10n.profileNoVideosTitle), findsOneWidget);
        expect(find.text(l10n.profileNoVideosOwnSubtitle), findsOneWidget);
      });

      testWidgets('skeleton grid when isLoading is true and no videos', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, isLoading: true),
        );

        expect(find.byType(ProfileVideosGridSkeleton), findsOneWidget);
      });

      testWidgets('video grid when videos are provided', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _otherPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _otherPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
      });

      testWidgets(
        'tapping a published tile passes seed videos and tapped identity',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey, count: 4);
          Object? capturedExtra;
          final profileFeedCubit = _stubbedProfileFeedCubit();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => testProviderScope(
                  mockAuthService: mockAuth,
                  child: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockBloc,
                    child: Scaffold(
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: profileFeedCubit,
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _ownPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: PooledFullscreenVideoFeedScreen.path,
                builder: (context, state) {
                  capturedExtra = state.extra;
                  return const SizedBox.shrink();
                },
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );

          await tester.tap(find.bySemanticsLabel('Video thumbnail 3'));
          await tester.pumpAndSettle();

          final args = capturedExtra as ProfilePooledFullscreenVideoFeedArgs?;
          expect(args, isNotNull);
          expect(args!.initialIndex, 2);
          expect(args.initialVideoId, videos[2].id);
          expect(args.initialStableId, videos[2].stableId);
          expect(args.seedVideos, videos);
        },
      );

      testWidgets(
        'active upload placeholder does not offset published tap target',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final draft = _createTestDraft();
          when(() => mockBloc.state).thenReturn(
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0.5),
              ],
            ),
          );

          final videos = _createTestVideos(pubkey: _ownPubkey, count: 4);
          Object? capturedExtra;
          final profileFeedCubit = _stubbedProfileFeedCubit();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => testProviderScope(
                  mockAuthService: mockAuth,
                  child: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockBloc,
                    child: Scaffold(
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: profileFeedCubit,
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _ownPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: PooledFullscreenVideoFeedScreen.path,
                builder: (context, state) {
                  capturedExtra = state.extra;
                  return const SizedBox.shrink();
                },
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );

          expect(find.byType(PartialCircleSpinner), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('Video thumbnail 3'));
          await tester.pumpAndSettle();

          final args = capturedExtra as ProfilePooledFullscreenVideoFeedArgs?;
          expect(args, isNotNull);
          expect(args!.initialIndex, 1);
          expect(args.initialVideoId, videos[1].id);
          expect(args.initialStableId, videos[1].stableId);
          expect(args.seedVideos, videos);
        },
      );

      testWidgets(
        'long-pressing an own video tile shows edit and delete actions',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            buildSubject(userIdHex: _ownPubkey, videos: videos),
          );

          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoGridEditVideo), findsOneWidget);
          expect(find.text(l10n.videoGridDeleteVideo), findsOneWidget);
        },
      );

      testWidgets(
        'long-pressing a non-owned tile on own profile shows no actions',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _otherPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final profileFeedCubit = _stubbedProfileFeedCubit();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => testProviderScope(
                  mockAuthService: mockAuth,
                  child: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockBloc,
                    child: Scaffold(
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: profileFeedCubit,
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _ownPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: PooledFullscreenVideoFeedScreen.path,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );

          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoGridEditVideo), findsNothing);
          expect(find.text(l10n.videoGridDeleteVideo), findsNothing);
        },
      );

      testWidgets('own video tile exposes long-press semantics', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _ownPubkey);
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        final node = tester.getSemantics(
          find.bySemanticsLabel('Video thumbnail 1'),
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );

        handle.dispose();
      });

      testWidgets(
        "long-pressing a tile on another user's profile shows no actions",
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _otherPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final profileFeedCubit = _stubbedProfileFeedCubit();
          // Without a long-press handler the gesture falls through to the
          // tap navigation, so the harness needs the fullscreen route.
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => testProviderScope(
                  mockAuthService: mockAuth,
                  child: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockBloc,
                    child: Scaffold(
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: profileFeedCubit,
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _otherPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: PooledFullscreenVideoFeedScreen.path,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );

          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();

          expect(find.text(l10n.videoGridEditVideo), findsNothing);
          expect(find.text(l10n.videoGridDeleteVideo), findsNothing);
        },
      );

      testWidgets(
        'tapping Edit Video in the actions sheet opens the metadata editor',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          String? capturedVideoId;
          final profileFeedCubit = _stubbedProfileFeedCubit();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => testProviderScope(
                  mockAuthService: mockAuth,
                  child: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockBloc,
                    child: Scaffold(
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: profileFeedCubit,
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _ownPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '${VideoMetadataEditScreen.path}/:videoId',
                builder: (context, state) {
                  capturedVideoId = state.pathParameters['videoId'];
                  return const SizedBox.shrink();
                },
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );

          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoGridEditVideo));
          await tester.pumpAndSettle();

          expect(capturedVideoId, videos[0].id);
        },
      );

      testWidgets(
        'tapping Delete Video in the actions sheet asks for confirmation',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            buildSubject(userIdHex: _ownPubkey, videos: videos),
          );

          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoGridDeleteVideo));
          await tester.pumpAndSettle();

          expect(find.text(l10n.shareMenuDeleteConfirmation), findsOneWidget);

          await tester.tap(find.text(l10n.shareMenuCancel));
          await tester.pumpAndSettle();

          expect(find.text(l10n.shareMenuDeleteConfirmation), findsNothing);
        },
      );

      testWidgets(
        'delete stays disabled with a spinner while work is pending',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final deletionService = _MockContentDeletionService();
          final enforcementRepository = _MockEnforcementRepository();
          final relayCompleter = Completer<DeleteResult>();
          when(
            () => deletionService.quickDelete(
              video: videos.first,
              reason: DeleteReason.personalChoice,
            ),
          ).thenAnswer((_) => relayCompleter.future);

          await tester.pumpWidget(
            buildSubject(
              userIdHex: _ownPubkey,
              videos: videos,
              additionalOverrides: [
                contentDeletionServiceProvider.overrideWith(
                  (ref) async => deletionService,
                ),
                creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
                  enforcementRepository,
                ),
              ],
            ),
          );
          await tester.longPress(find.bySemanticsLabel('Video thumbnail 1'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoGridDeleteVideo));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          final editTile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(l10n.videoGridEditVideo),
              matching: find.byType(ListTile),
            ),
          );
          expect(editTile.enabled, isFalse);
          final deleteTile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(l10n.videoGridDeleteVideo),
              matching: find.byType(ListTile),
            ),
          );
          expect(deleteTile.enabled, isFalse);

          relayCompleter.complete(
            DeleteResult.failure('rejected', DeleteFailureKind.relayRejected),
          );
          await tester.pumpAndSettle();

          final recoveredEditTile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(l10n.videoGridEditVideo),
              matching: find.byType(ListTile),
            ),
          );
          final recoveredDeleteTile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(l10n.videoGridDeleteVideo),
              matching: find.byType(ListTile),
            ),
          );
          expect(recoveredEditTile.enabled, isTrue);
          expect(recoveredDeleteTile.enabled, isTrue);

          verify(
            () => deletionService.quickDelete(
              video: videos.first,
              reason: DeleteReason.personalChoice,
            ),
          ).called(1);
        },
      );

      testWidgets('shows persistent pending invite banner on own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final pendingInviteGroups = [
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownPubkey,
            videoAddress: '34236:$_ownPubkey:video-1',
            title: 'Beach post',
            invites: [
              PendingCollaboratorInvite(
                rumorId: 'rumor-1',
                collaboratorPubkey: _otherPubkey,
                creatorPubkey: _ownPubkey,
                videoAddress: '34236:$_ownPubkey:video-1',
                recipientWrapStatus: OutgoingWrapStatus.failed,
                selfWrapStatus: OutgoingWrapStatus.failed,
                retryCount: 1,
                queuedAt: DateTime.utc(2026, 5, 22, 13),
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _ownPubkey,
            videos: videos,
            pendingInviteGroups: pendingInviteGroups,
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.profileCollaboratorInvitePendingHeadline(1)),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.profileCollaboratorInvitePendingDetailWithTitle('Beach post'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(l10n.profileCollaboratorInviteRetryAction),
          findsOneWidget,
        );
      });

      testWidgets('does not show pending invite banner on another profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _otherPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final pendingInviteGroups = [
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownPubkey,
            videoAddress: '34236:$_ownPubkey:video-1',
            invites: [
              PendingCollaboratorInvite(
                rumorId: 'rumor-1',
                collaboratorPubkey: _otherPubkey,
                creatorPubkey: _ownPubkey,
                videoAddress: '34236:$_ownPubkey:video-1',
                recipientWrapStatus: OutgoingWrapStatus.failed,
                selfWrapStatus: OutgoingWrapStatus.failed,
                retryCount: 1,
                queuedAt: DateTime.utc(2026, 5, 22, 13),
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _otherPubkey,
            videos: videos,
            pendingInviteGroups: pendingInviteGroups,
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.profileCollaboratorInvitePendingHeadline(1)),
          findsNothing,
        );
      });

      testWidgets('pending invite banner copy is localized by locale', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final pendingInviteGroups = [
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownPubkey,
            videoAddress: '34236:$_ownPubkey:video-1',
            invites: [
              PendingCollaboratorInvite(
                rumorId: 'rumor-1',
                collaboratorPubkey: _otherPubkey,
                creatorPubkey: _ownPubkey,
                videoAddress: '34236:$_ownPubkey:video-1',
                recipientWrapStatus: OutgoingWrapStatus.failed,
                selfWrapStatus: OutgoingWrapStatus.failed,
                retryCount: 1,
                queuedAt: DateTime.utc(2026, 5, 22, 13),
              ),
            ],
          ),
        ];
        final en = lookupAppLocalizations(const Locale('en'));
        final de = lookupAppLocalizations(const Locale('de'));

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _ownPubkey,
            videos: _createTestVideos(pubkey: _ownPubkey),
            pendingInviteGroups: pendingInviteGroups,
            locale: const Locale('de'),
          ),
        );
        await tester.pump();

        expect(
          find.text(de.profileCollaboratorInvitePendingHeadline(1)),
          findsOneWidget,
        );
        expect(
          Localizations.localeOf(
            tester.element(find.byType(ProfileVideosGrid)),
          ),
          const Locale('de'),
        );
        expect(de.localeName, isNot(equals(en.localeName)));
      });

      testWidgets('retry banner action uses queue-backed recovery', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        when(
          () => mockDmRepository.retryPendingCollaboratorInvites(any()),
        ).thenAnswer(
          (_) async => const CollaboratorInviteRetrySummary(
            attemptedCount: 1,
            successCount: 1,
            failureCount: 0,
          ),
        );
        final pendingInviteGroups = [
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownPubkey,
            videoAddress: '34236:$_ownPubkey:video-1',
            invites: [
              PendingCollaboratorInvite(
                rumorId: 'rumor-1',
                collaboratorPubkey: _otherPubkey,
                creatorPubkey: _ownPubkey,
                videoAddress: '34236:$_ownPubkey:video-1',
                recipientWrapStatus: OutgoingWrapStatus.failed,
                selfWrapStatus: OutgoingWrapStatus.failed,
                retryCount: 1,
                queuedAt: DateTime.utc(2026, 5, 22, 13),
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _ownPubkey,
            videos: _createTestVideos(pubkey: _ownPubkey),
            pendingInviteGroups: pendingInviteGroups,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.profileCollaboratorInviteRetryAction));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockDmRepository.retryPendingCollaboratorInvites(
            any(
              that: predicate<Iterable<PendingCollaboratorInvite>>(
                (invites) =>
                    invites.length == 1 &&
                    invites.single.rumorId == 'rumor-1' &&
                    invites.single.collaboratorPubkey == _otherPubkey,
              ),
            ),
          ),
        ).called(1);
        expect(
          find.text(l10n.profileCollaboratorInviteRetryResult(0)),
          findsOneWidget,
        );
      });

      testWidgets('retry banner surfaces a blocked message when a '
          'collaborator cannot receive invites', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        when(
          () => mockDmRepository.retryPendingCollaboratorInvites(any()),
        ).thenAnswer(
          (_) async => const CollaboratorInviteRetrySummary(
            attemptedCount: 1,
            successCount: 0,
            failureCount: 0,
            blockedCount: 1,
          ),
        );
        final pendingInviteGroups = [
          PendingCollaboratorInviteGroup(
            creatorPubkey: _ownPubkey,
            videoAddress: '34236:$_ownPubkey:video-1',
            invites: [
              PendingCollaboratorInvite(
                rumorId: 'rumor-1',
                collaboratorPubkey: _otherPubkey,
                creatorPubkey: _ownPubkey,
                videoAddress: '34236:$_ownPubkey:video-1',
                recipientWrapStatus: OutgoingWrapStatus.failed,
                selfWrapStatus: OutgoingWrapStatus.failed,
                retryCount: 1,
                queuedAt: DateTime.utc(2026, 5, 22, 13),
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            userIdHex: _ownPubkey,
            videos: _createTestVideos(pubkey: _ownPubkey),
            pendingInviteGroups: pendingInviteGroups,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.profileCollaboratorInviteRetryAction));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text(l10n.profileCollaboratorInviteBlockedResult(1)),
          findsOneWidget,
        );
        // A blocked-only batch must not read as "all invites sent".
        expect(
          find.text(l10n.profileCollaboratorInviteRetryResult(0)),
          findsNothing,
        );
      });
    });

    group('background uploads', () {
      testWidgets('shows uploading tile when viewing own profile '
          'with active background upload', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(PartialCircleSpinner), findsOneWidget);
      });

      testWidgets('does not show uploading tile when viewing '
          "another user's profile with active background upload", (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _otherPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _otherPubkey, videos: videos),
        );

        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(PartialCircleSpinner), findsNothing);
      });

      testWidgets('does not show completed uploads on own profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: draft,
                result: const PublishSuccess(),
                progress: 1,
              ),
            ],
          ),
        );

        final videos = _createTestVideos(pubkey: _ownPubkey);

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        expect(find.byType(PartialCircleSpinner), findsNothing);
      });
    });

    group('de-duplication', () {
      testWidgets('filters relay video matching active upload title '
          'on own profile', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        // Active upload with title "Test Draft"
        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        // Relay delivers a video with the same title (recent timestamp)
        final now = DateTime.now();
        final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
        final videos = [
          model.VideoEvent(
            id: 'relay-duplicate',
            pubkey: _ownPubkey,
            createdAt: nowUnix,
            content: '',
            timestamp: now,
            title: 'Test Draft',
            videoUrl: 'https://example.com/v0.mp4',
            thumbnailUrl: 'https://example.com/thumb0.jpg',
          ),
          model.VideoEvent(
            id: 'relay-other',
            pubkey: _ownPubkey,
            createdAt: nowUnix - 1,
            content: '',
            timestamp: now.subtract(const Duration(seconds: 1)),
            title: 'Other Video',
            videoUrl: 'https://example.com/v1.mp4',
            thumbnailUrl: 'https://example.com/thumb1.jpg',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        // 1 upload spinner + 1 published video tile (duplicate filtered)
        expect(find.byType(PartialCircleSpinner), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Video thumbnail')),
          findsOneWidget,
        );
      });

      testWidgets('does not filter videos older than 5 minutes', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft(title: 'Old Video');
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.3),
            ],
          ),
        );

        // Video with matching title but created 10 minutes ago
        final now = DateTime.now();
        final oldTimestamp = now.subtract(const Duration(minutes: 10));
        final oldUnix = oldTimestamp.millisecondsSinceEpoch ~/ 1000;
        final videos = [
          model.VideoEvent(
            id: 'old-video',
            pubkey: _ownPubkey,
            createdAt: oldUnix,
            content: '',
            timestamp: oldTimestamp,
            title: 'Old Video',
            videoUrl: 'https://example.com/v0.mp4',
            thumbnailUrl: 'https://example.com/thumb0.jpg',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(userIdHex: _ownPubkey, videos: videos),
        );

        // Upload spinner + the old video tile (not filtered)
        expect(find.byType(PartialCircleSpinner), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Video thumbnail')),
          findsOneWidget,
        );
      });

      testWidgets('does not filter videos on another user profile', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        // Active upload with matching title
        final draft = _createTestDraft();
        when(() => mockBloc.state).thenReturn(
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
        );

        final now = DateTime.now();
        final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
        final videos = [
          model.VideoEvent(
            id: 'other-user-video',
            pubkey: _otherPubkey,
            createdAt: nowUnix,
            content: '',
            timestamp: now,
            title: 'Test Draft',
            videoUrl: 'https://example.com/v0.mp4',
            thumbnailUrl: 'https://example.com/thumb0.jpg',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(userIdHex: _otherPubkey, videos: videos),
        );

        // No spinner (other user) and video tile is present (no filtering)
        expect(find.byType(PartialCircleSpinner), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Video thumbnail')),
          findsOneWidget,
        );
      });
    });

    group('loading-vs-empty regression guard (#4164)', () {
      // The screens (`profile_screen_router.dart`, `other_profile_screen.dart`)
      // are responsible for threading `state.isInitialLoad` into the
      // `isLoading` parameter so the cold-start fetch window does not
      // surface as a misleading "No videos" empty state. These tests pin
      // the widget-side contract that drives the screens' wiring choice.
      testWidgets(
        'shows skeleton grid — not empty state — when isLoading is true '
        'and videos is empty',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

          await tester.pumpWidget(
            buildSubject(userIdHex: _ownPubkey, isLoading: true),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.byType(ProfileVideosGridSkeleton), findsOneWidget);
          expect(find.text(l10n.profileNoVideosTitle), findsNothing);
        },
      );

      testWidgets(
        'shows empty state — not loading state — when isLoading is false '
        'and videos is empty (preserves the genuine "user has nothing '
        'posted" path)',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

          await tester.pumpWidget(buildSubject(userIdHex: _ownPubkey));

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileNoVideosTitle), findsOneWidget);
          expect(find.byType(ProfileVideosGridSkeleton), findsNothing);
        },
      );
    });

    group('rebuild optimization (#3605)', () {
      // These tests pin the `context.select` contract that keeps the grid
      // from rebuilding on every `BackgroundPublishBloc` progress tick.
      //
      // The optimization hinges on [ActiveUploadsView]'s equality semantics:
      // two states that differ only in `BackgroundUpload.progress` must
      // produce equal projections so `context.select` suppresses the
      // consumer rebuild. A regression to identity-based list equality
      // would fail the first test below.

      test('ActiveUploadsView.fromState compares equal across progress-only '
          'state changes', () {
        final draft = _createTestDraft();
        final state1 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.1),
          ],
        );
        final state2 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.9),
          ],
        );

        expect(
          ActiveUploadsView.fromState(state1),
          equals(ActiveUploadsView.fromState(state2)),
        );
      });

      test('ActiveUploadsView.fromState compares unequal when an upload '
          'is added', () {
        final draftA = _createTestDraft(title: 'A');
        final draftB = _createTestDraft(title: 'B');
        final state1 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftA, result: null, progress: 0.5),
          ],
        );
        final state2 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftA, result: null, progress: 0.5),
            BackgroundUpload(draft: draftB, result: null, progress: 0.5),
          ],
        );

        expect(
          ActiveUploadsView.fromState(state1),
          isNot(equals(ActiveUploadsView.fromState(state2))),
        );
      });

      test('ActiveUploadsView.fromState compares unequal when a draft title '
          'changes', () {
        final draftA = _createTestDraft(title: 'Old title');
        final draftB = _createTestDraft(title: 'New title');
        final state1 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftA, result: null, progress: 0.5),
          ],
        );
        final state2 = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftB, result: null, progress: 0.5),
          ],
        );

        expect(
          ActiveUploadsView.fromState(state1),
          isNot(equals(ActiveUploadsView.fromState(state2))),
        );
      });

      test(
        'ActiveUploadsView.fromState excludes uploads with a non-null result',
        () {
          final draft = _createTestDraft();
          final state = BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: draft,
                result: const PublishSuccess(),
                progress: 1,
              ),
            ],
          );

          expect(ActiveUploadsView.fromState(state).uploads, isEmpty);
        },
      );

      testWidgets('progress-only state emission does not rebuild the grid '
          'while the per-tile spinner still receives the update', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draft = _createTestDraft();
        final initial = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.1),
          ],
        );
        final tick = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.9),
          ],
        );

        // Use an externally-driven broadcast stream so we can pump the
        // initial Riverpod async (profileFeedProvider transitions from
        // AsyncLoading → AsyncData and triggers an orthogonal rebuild
        // via `ref.watch`) to a steady state before measuring the
        // bloc-tick's incremental rebuild count.
        final controller = StreamController<BackgroundPublishState>.broadcast();
        addTearDown(controller.close);
        whenListen(mockBloc, controller.stream, initialState: initial);

        await tester.pumpWidget(buildSubject(userIdHex: _ownPubkey));
        // Settle initial async (Riverpod's profileFeedProvider, post-
        // frame callbacks, etc.) — anything not caused by our tick.
        await tester.pump();
        final baselineBuildCount = debugProfileVideosGridBuildCount;

        // Now emit the progress-only update.
        controller.add(tick);
        await tester.pump();
        // PartialCircleSpinner.animateTo runs over 200ms — settle the
        // implicit animation so we read the post-tick value.
        await tester.pump(const Duration(milliseconds: 250));

        // (a) Grid did NOT rebuild as a result of the progress-only
        // emission. A regression to identity-based list equality on
        // the selector would tick this counter higher.
        expect(debugProfileVideosGridBuildCount, equals(baselineBuildCount));

        // (b) Per-tile spinner DID receive the updated progress —
        // the tile's own context.select<...double>(...) projects to
        // a primitive whose equality compares cleanly.
        final spinner = tester.widget<PartialCircleSpinner>(
          find.byType(PartialCircleSpinner),
        );
        expect(spinner.progress, closeTo(0.9, 1e-9));
      });

      testWidgets('shape-change state emission does rebuild the grid '
          '(contrast for the rebuild-count counter)', (tester) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);

        final draftA = _createTestDraft(title: 'A');
        final draftB = _createTestDraft(title: 'B');
        final initial = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftA, result: null, progress: 0.5),
          ],
        );
        final shapeChange = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draftA, result: null, progress: 0.5),
            BackgroundUpload(draft: draftB, result: null, progress: 0.5),
          ],
        );

        final controller = StreamController<BackgroundPublishState>.broadcast();
        addTearDown(controller.close);
        whenListen(mockBloc, controller.stream, initialState: initial);

        await tester.pumpWidget(buildSubject(userIdHex: _ownPubkey));
        await tester.pump();
        final baselineBuildCount = debugProfileVideosGridBuildCount;

        controller.add(shapeChange);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Shape changed (a new upload appeared) → grid must rebuild
        // so the new tile is added to the SliverGrid.
        expect(
          debugProfileVideosGridBuildCount,
          greaterThan(baselineBuildCount),
        );
        expect(find.byType(PartialCircleSpinner), findsNWidgets(2));
      });
    });

    group('scroll coordination with NestedScrollView', () {
      testWidgets(
        'uses PrimaryScrollController from NestedScrollView ancestor',
        (tester) async {
          when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
          final videos = _createTestVideos(pubkey: _ownPubkey, count: 6);

          await tester.pumpWidget(
            testProviderScope(
              mockAuthService: mockAuth,
              child: BlocProvider<BackgroundPublishBloc>.value(
                value: mockBloc,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        const SliverToBoxAdapter(child: SizedBox(height: 200)),
                      ],
                      body: BlocProvider<ProfileFeedCubit>.value(
                        value: _stubbedProfileFeedCubit(),
                        child: ProfileVideosGrid(
                          videos: videos,
                          userIdHex: _ownPubkey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProfileVideosGrid), findsOneWidget);
          expect(find.byType(SliverGrid), findsOneWidget);

          final customScrollView = tester.widget<CustomScrollView>(
            find.byType(CustomScrollView).last,
          );
          expect(customScrollView.controller, isNull);
        },
      );

      testWidgets('header scrolls away when scrolling inside the grid', (
        tester,
      ) async {
        when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownPubkey);
        final videos = _createTestVideos(pubkey: _ownPubkey, count: 30);

        await tester.pumpWidget(
          testProviderScope(
            mockAuthService: mockAuth,
            child: BlocProvider<BackgroundPublishBloc>.value(
              value: mockBloc,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 200,
                          child: ColoredBox(
                            color: Colors.red,
                            child: Center(child: Text('Header')),
                          ),
                        ),
                      ),
                    ],
                    body: BlocProvider<ProfileFeedCubit>.value(
                      value: _stubbedProfileFeedCubit(),
                      child: ProfileVideosGrid(
                        videos: videos,
                        userIdHex: _ownPubkey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Header'), findsOneWidget);

        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        // Header should have scrolled off screen (clipped from tree)
        expect(find.text('Header'), findsNothing);
      });
    });
  });
}
