// ABOUTME: Widget tests for the video card's date-and-count meta line.
// ABOUTME: Pins that small public counts stay hidden from strangers.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

const _authorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _strangerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
// 2014-04-22T12:00Z — midday keeps the calendar day stable across
// runner timezones.
const _vineEraCreatedAt = 1398168000;

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockAuthService extends Mock implements AuthService {}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

VideoEvent _video({
  String pubkey = _authorPubkey,
  int? originalLoops,
  Map<String, String> rawTags = const {},
  int? createdAt,
}) {
  final at = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'video-card-meta-line-test-0123456789abcdef0123456789abcdef0123',
    pubkey: pubkey,
    createdAt: at,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockRepostsRepository mockRepostsRepository;
  late _MockAuthService mockAuthService;
  late StreamController<AuthState> authStateController;

  setUp(() {
    authStateController = StreamController<AuthState>.broadcast();
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    mockRepostsRepository = _MockRepostsRepository();
    mockAuthService = _MockAuthService();

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
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_strangerPubkey);
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  Future<void> pump(
    WidgetTester tester, {
    required VideoEvent video,
    bool viewerIsAuthor = false,
  }) async {
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(
      viewerIsAuthor ? _authorPubkey : _strangerPubkey,
    );

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
                video: video,
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

  String loopLine(WidgetTester tester, int count) => _l10n(
    tester,
  ).videoFeedLoopCountLine(StringUtils.formatCompactNumber(count), count);

  group('video card meta line', () {
    testWidgets('shows OG Beta Tester for a non-team roster member', (
      tester,
    ) async {
      final pubkey = ogBetaTesterPubkeys.firstWhere(
        (candidate) => !kDivineTeamPubkeys.contains(candidate),
      );
      await pump(tester, video: _video(pubkey: pubkey));

      expect(find.byType(SpecialProfileCheckmark), findsNothing);
      expect(find.byType(OgBetaBadge), findsOneWidget);
    });

    testWidgets('hides a small count from a stranger', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
      );

      expect(find.text(loopLine(tester, 7)), findsNothing);
    });

    testWidgets('shows a large count to a stranger', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
      );

      expect(find.textContaining(loopLine(tester, 50000)), findsOneWidget);
    });

    testWidgets('shows the creator their own small count', (tester) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        viewerIsAuthor: true,
      );

      expect(find.textContaining(loopLine(tester, 7)), findsOneWidget);
    });

    testWidgets('shows a classic Vine date alongside its archival count', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(
          originalLoops: 2100000,
          createdAt: _vineEraCreatedAt,
          rawTags: {
            'platform': 'vine',
            'published_at': '$_vineEraCreatedAt',
            'views': '340',
          },
        ),
      );

      // Archival figure only: live diVine views must not inflate it.
      expect(find.textContaining(loopLine(tester, 2100000)), findsOneWidget);
      // The year is the point — it is what makes the clip read as an artifact
      // rather than as something posted this spring. The exact calendar day is
      // timezone-dependent and is pinned in localized_time_formatter_test.
      expect(find.textContaining('2014'), findsOneWidget);
    });

    testWidgets('reveals the creator their count after they sign in', (
      tester,
    ) async {
      // authServiceProvider hands back a stable singleton, so without watching
      // currentAuthStateProvider this card would stay stuck on the signed-out
      // reading and keep hiding its owner's count.
      when(
        () => mockAuthService.authState,
      ).thenReturn(AuthState.unauthenticated);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
      );

      expect(find.textContaining(loopLine(tester, 7)), findsNothing);

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(_authorPubkey);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      authStateController.add(AuthState.authenticated);
      await tester.pumpAndSettle();

      expect(find.textContaining(loopLine(tester, 7)), findsOneWidget);
    });

    testWidgets('shows a relative date on a fresh post', (tester) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
      );

      expect(find.textContaining(_l10n(tester).timeVerboseNow), findsOneWidget);
    });
  });
}
