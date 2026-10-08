// ABOUTME: Widget tests for VideoOverlayActions' author line and caption block.
// ABOUTME: Covers description taps, caption text, and the block's spacing.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart' show AuthService;
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_reply_parent_link.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

// Offsets come from summing fractional line heights, so compare within a
// hair instead of for exact equality.
const _layoutTolerance = 0.01;

Finder _specialCheckmark() => find.byWidgetPredicate(
  (w) => w is DivineIcon && w.icon == DivineIconName.check,
);

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCollaboratorConfirmationRepository extends Mock
    implements CollaboratorConfirmationRepository {}

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockRepostsRepository mockRepostsRepository;
  late VideoEvent testVideo;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    mockRepostsRepository = _MockRepostsRepository();

    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());
    when(
      () => mockRepostsRepository.fetchEventReposters(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const <String>[]);

    testVideo = VideoEvent(
      id: 'video-overlay-actions-test-0123456789abcdef0123456789abcdef012345',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Tap this description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  group('interactions', () {
    testWidgets('opens metadata sheet when tapping description', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showVideoLoopsKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        testProviderScope(
          mockSharedPreferences: prefs,
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap this description'));
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(
        find.text(l10n.metadataLoopsLabel(testVideo.totalLoops)),
        findsOneWidget,
      );
      expect(find.text('Likes'), findsOneWidget);
    });
  });

  group('renders', () {
    Future<void> pumpOverlay(
      WidgetTester tester, {
      AuthService? authService,
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: authService,
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            ...overrides,
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows title and description for a non-classic video', (
      tester,
    ) async {
      await pumpOverlay(tester);

      expect(find.text('Test Video'), findsOneWidget);
      expect(find.text('Tap this description'), findsOneWidget);
    });

    testWidgets('shows the caption once for a classic Vine', (tester) async {
      testVideo = testVideo.copyWith(
        title: 'Same caption',
        content: 'Same caption',
        rawTags: const {'platform': 'vine'},
      );

      await pumpOverlay(tester);

      expect(find.text('Same caption'), findsOneWidget);
    });

    testWidgets('shows only the description when a classic Vine caption is '
        'followed by stats', (tester) async {
      testVideo = testVideo.copyWith(
        title: 'Same caption',
        content: 'Same caption\n\nOriginal stats: 3 loops - 2 likes',
        rawTags: const {'platform': 'vine'},
      );

      await pumpOverlay(tester);

      // Exact match: only a separate title row renders the bare caption.
      expect(find.text('Same caption'), findsNothing);
      // The overlay drops the blank line between caption and stats.
      expect(
        find.text('Same caption\nOriginal stats: 3 loops - 2 likes'),
        findsOneWidget,
      );
    });

    testWidgets('drops blank lines from the description', (tester) async {
      testVideo = testVideo.copyWith(
        content: 'First line\n\n   \nSecond line\n\nThird line',
      );

      await pumpOverlay(tester);

      expect(
        find.text('First line\nSecond line\nThird line'),
        findsOneWidget,
      );
    });

    testWidgets('caps the description at two lines', (tester) async {
      Future<double> descriptionHeight(String content) async {
        testVideo = testVideo.copyWith(content: content);
        await pumpOverlay(tester);
        return tester
            .getSize(find.bySemanticsIdentifier('video_description'))
            .height;
      }

      final oneLine = await descriptionHeight('First line');
      final twoLines = await descriptionHeight('First line\nSecond line');
      final threeLines = await descriptionHeight(
        'First line\nSecond line\nThird line',
      );

      // A second line makes the description taller; a third does not.
      expect(twoLines, greaterThan(oneLine));
      expect(threeLines, closeTo(twoLines, _layoutTolerance));
    });

    group('caption block', () {
      // The overlay column holding the author row and the caption. Its bottom
      // edge is where the caption block ends on screen.
      Finder captionBlock() => find
          .ancestor(
            of: find.bySemanticsIdentifier('video_description'),
            matching: find.byType(Column),
          )
          .first;

      double descriptionBottom(WidgetTester tester) => tester
          .getRect(find.bySemanticsIdentifier('video_description'))
          .bottom;

      const collaboratorPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      testWidgets('ends at the description when nothing renders below it', (
        tester,
      ) async {
        await pumpOverlay(tester);

        expect(
          tester.getRect(captionBlock()).bottom,
          closeTo(descriptionBottom(tester), _layoutTolerance),
        );
      });

      testWidgets(
        'keeps a 4 pt gap above the audio row and ends flush with it',
        (
          tester,
        ) async {
          const audioEventId =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          testVideo = testVideo.copyWith(audioEventId: audioEventId);

          // An unresolved reference still renders a display-only credit.
          await pumpOverlay(
            tester,
            overrides: [
              soundByIdProvider(audioEventId).overrideWith((ref) async => null),
            ],
          );

          final audioRow = tester.getRect(find.byType(AudioAttributionRow));
          expect(audioRow.height, greaterThan(0));
          expect(
            audioRow.top - descriptionBottom(tester),
            closeTo(4, _layoutTolerance),
          );
          expect(
            tester.getRect(captionBlock()).bottom,
            closeTo(audioRow.bottom, _layoutTolerance),
          );
        },
      );

      testWidgets('keeps a 4 pt gap above a visible collaborator row', (
        tester,
      ) async {
        // No confirmation repository in this scope, so the row falls back to
        // showing every tagged collaborator.
        testVideo = testVideo.copyWith(
          collaboratorPubkeys: const [collaboratorPubkey],
        );

        await pumpOverlay(tester);

        final rowTop = tester
            .getRect(find.bySemanticsIdentifier('collaborator_avatar_row'))
            .top;
        expect(
          rowTop - descriptionBottom(tester),
          closeTo(4, _layoutTolerance),
        );
      });

      // Pumps the overlay for a third-party viewer, with the collaborator's
      // acceptance resolved to [status].
      Future<void> pumpAsThirdPartyViewer(
        WidgetTester tester, {
        required CollaboratorStatus status,
      }) async {
        const viewerPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        testVideo = testVideo.copyWith(
          collaboratorPubkeys: const [collaboratorPubkey],
          addressableDTag: 'caption-block',
        );
        final repository = _MockCollaboratorConfirmationRepository();
        when(() => repository.release(any())).thenReturn(null);
        when(
          () => repository.watch(
            any(),
            creatorPubkey: any(named: 'creatorPubkey'),
            taggedPubkeys: any(named: 'taggedPubkeys'),
          ),
        ).thenAnswer(
          (_) => Stream.value(
            VideoCollaboratorStatus(
              videoAddress: testVideo.addressableId!,
              statusByPubkey: {collaboratorPubkey: status},
              isResolved: true,
            ),
          ),
        );

        await pumpOverlay(
          tester,
          authService: createMockAuthService(currentPublicKeyHex: viewerPubkey),
          overrides: [
            collaboratorConfirmationRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
      }

      testWidgets(
        'keeps a 4 pt gap above a collaborator row the viewer can see',
        (tester) async {
          await pumpAsThirdPartyViewer(
            tester,
            status: CollaboratorStatus.confirmed,
          );

          final rowTop = tester
              .getRect(find.bySemanticsIdentifier('collaborator_avatar_row'))
              .top;
          expect(
            rowTop - descriptionBottom(tester),
            closeTo(4, _layoutTolerance),
          );
        },
      );

      testWidgets('reserves no gap for collaborators the viewer cannot see', (
        tester,
      ) async {
        await pumpAsThirdPartyViewer(
          tester,
          status: CollaboratorStatus.pending,
        );

        // The row is mounted but shows the third-party viewer nothing.
        expect(find.byType(CollaboratorAvatarRow), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('collaborator_avatar_row'),
          findsNothing,
        );
        expect(
          tester.getRect(captionBlock()).bottom,
          closeTo(descriptionBottom(tester), _layoutTolerance),
        );
      });
    });

    testWidgets('hides inspired-by attribution from the player overlay', (
      tester,
    ) async {
      final npub = normalizeToNpub('d' * 64)!;
      testVideo = testVideo.copyWith(
        content: 'Visible caption\n\n${inspiredByAttributionLine(npub)}',
        inspiredByNpub: npub,
      );

      await pumpOverlay(tester);

      // Exact match: an unstripped line would lengthen the caption text.
      expect(find.text('Visible caption'), findsOneWidget);
    });

    testWidgets(
      'keeps collaborator and reply controls when attribution is the caption',
      (tester) async {
        final npub = normalizeToNpub('d' * 64)!;
        testVideo = VideoEvent(
          id: testVideo.id,
          pubkey: testVideo.pubkey,
          createdAt: testVideo.createdAt,
          content: inspiredByAttributionLine(npub),
          timestamp: testVideo.timestamp,
          videoUrl: testVideo.videoUrl,
          collaboratorPubkeys: const [
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          ],
          nostrEventTags: const [
            [
              'E',
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            ],
            ['K', '34236'],
          ],
          inspiredByNpub: npub,
        );

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              repostsRepositoryProvider.overrideWithValue(
                mockRepostsRepository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: BlocProvider<VideoInteractionsBloc>.value(
                  value: mockInteractionsBloc,
                  child: VideoOverlayActions(
                    video: testVideo,
                    isVisible: true,
                    isActive: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(testVideo.displayContent, isEmpty);
        expect(find.byType(CollaboratorAvatarRow), findsOneWidget);
        expect(find.byType(VideoReplyParentLink), findsOneWidget);
      },
    );

    testWidgets('paints a brand-green heart in the author name', (
      tester,
    ) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
              yield UserProfile(
                pubkey: pubkey,
                displayName: 'Alice $divineGreenHeart',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              );
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final heartFinder = find.byWidgetPredicate(
        (w) => w is DivineIcon && w.icon == DivineIconName.heartFill,
      );
      expect(heartFinder, findsOneWidget);
      expect(tester.widget<DivineIcon>(heartFinder).color, VineTheme.vineGreen);
    });

    testWidgets('author line uses localized plural loop label', (tester) async {
      // A large total resolves through the plural ICU form.
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            videoCardAuthorStatsProvider(testVideo.pubkey).overrideWith(
              (ref) => Stream.value(
                ProfileStats(pubkey: testVideo.pubkey, totalViews: 10000),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(
        find.textContaining(
          l10n.videoOverlayTotalLoops(
            StringUtils.formatCompactNumber(10000),
            10000,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('author line does not show checkmark for verified NIP-05', (
      tester,
    ) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
              yield UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                nip05: 'alice@example.com',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              );
            }),
            nip05VerificationProvider.overrideWith(
              (ref, pubkey) async => Nip05VerificationStatus.verified,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(_specialCheckmark(), findsNothing);
    });

    testWidgets('author line shows checkmark for a Divine team pubkey', (
      tester,
    ) async {
      testVideo = testVideo.copyWith(pubkey: kDivineTeamPubkeys.first);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
              yield UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                nip05: 'alice@example.com',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              );
            }),
            nip05VerificationProvider.overrideWith(
              (ref, pubkey) async => Nip05VerificationStatus.verified,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(_specialCheckmark(), findsOneWidget);
    });

    testWidgets(
      'does not render a dedicated captions button in the action rail',
      (tester) async {
        final subtitleVideo = testVideo.copyWith(
          textTrackRef: '39307:${testVideo.pubkey}:subtitles:${testVideo.id}',
        );

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              repostsRepositoryProvider.overrideWithValue(
                mockRepostsRepository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: BlocProvider<VideoInteractionsBloc>.value(
                  value: mockInteractionsBloc,
                  child: VideoOverlayActions(
                    video: subtitleVideo,
                    isVisible: true,
                    isActive: true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'cc_button',
          ),
          findsNothing,
        );
      },
    );
  });
}
