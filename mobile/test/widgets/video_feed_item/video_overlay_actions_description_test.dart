// ABOUTME: Regression test for tapping descriptions in VideoOverlayActions.
// ABOUTME: Verifies the inline description opens the metadata sheet.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Finder _specialCheckmark() => find.byWidgetPredicate(
  (w) => w is DivineIcon && w.icon == DivineIconName.check,
);

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockAuthService extends Mock implements AuthService {}

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
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    testWidgets('author line uses localized singular loop label for 1', (
      tester,
    ) async {
      testVideo = testVideo.copyWith(originalLoops: 1);

      // A count of 1 is far below the public floor, so only the creator is ever
      // shown it — the singular form is unreachable for anyone else.
      final authStateController = StreamController<AuthState>.broadcast();
      addTearDown(authStateController.close);
      final mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testVideo.pubkey);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      // The creator's line now carries the post date too, so match within it.
      expect(
        find.textContaining(
          l10n.videoFeedLoopCountLine(StringUtils.formatCompactNumber(1), 1),
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
