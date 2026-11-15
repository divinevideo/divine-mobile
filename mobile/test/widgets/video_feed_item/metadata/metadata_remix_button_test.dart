// ABOUTME: Tests for the info sheet's "Remix this video" button.
// ABOUTME: Covers who sees it, when it holds off, and the web app nudge.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_remix_button.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/test_provider_overrides.dart';
import '../../../helpers/url_launcher_test_double.dart';

class _MockVideoContentActionsBloc
    extends MockBloc<VideoContentActionsEvent, VideoContentActionsState>
    implements VideoContentActionsBloc {}

class _MockOwnerVideoActionsCubit extends MockCubit<OwnerVideoActionsState>
    implements OwnerVideoActionsCubit {}

const _videoId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _creatorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

VideoEvent _video({
  Map<String, String> rawTags = const {},
  List<List<String>> tags = const [],
}) {
  return VideoEvent(
    id: _videoId,
    pubkey: _creatorPubkey,
    createdAt: 1757385263,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://example.com/video.mp4',
    rawTags: rawTags,
    nostrEventTags: tags,
  );
}

final VideoEvent _classicVine = _video(rawTags: const {'platform': 'vine'});

final VideoEvent _declinedReuse = _video(
  tags: const [
    ['allow_video_reuse', 'false'],
  ],
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final remixButton = find.widgetWithText(DivineButton, l10n.remixThisVideo);

  late _MockVideoContentActionsBloc contentActions;

  setUpAll(() {
    registerFallbackValue(const VideoContentRemixRequested());
  });

  setUp(() {
    contentActions = _MockVideoContentActionsBloc();
    when(
      () => contentActions.state,
    ).thenReturn(const VideoContentActionsState());
  });

  _MockOwnerVideoActionsCubit ownerCubit({bool isDeleting = false}) {
    final cubit = _MockOwnerVideoActionsCubit();
    when(() => cubit.state).thenReturn(const OwnerVideoActionsState());
    when(() => cubit.isDeleteInProgress(any())).thenReturn(isDeleting);
    return cubit;
  }

  Widget buildSubject({
    required VideoEvent video,
    OwnerVideoActionsCubit? owner,
    bool isWeb = false,
  }) {
    return testMaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<VideoContentActionsBloc>.value(value: contentActions),
            if (owner != null)
              BlocProvider<OwnerVideoActionsCubit>.value(value: owner),
          ],
          child: MetadataRemixButton(
            video: video,
            isOwnVideo: owner != null,
            isWeb: isWeb,
          ),
        ),
      ),
    );
  }

  group(MetadataRemixButton, () {
    group('renders', () {
      testWidgets('the remix label on a classic Vine', (tester) async {
        await tester.pumpWidget(buildSubject(video: _classicVine));

        expect(remixButton, findsOneWidget);
      });

      testWidgets('on another creator video that carries no reuse tag', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(video: _video()));

        expect(remixButton, findsOneWidget);
      });

      testWidgets('nothing for another creator who declines reuse', (
        tester,
      ) async {
        expect(_declinedReuse.allowVideoReuse, isFalse);
        await tester.pumpWidget(buildSubject(video: _declinedReuse));

        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('on the viewer own video even when its tag declines reuse', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: _declinedReuse, owner: ownerCubit()),
        );

        expect(remixButton, findsOneWidget);
      });

      testWidgets('nothing when no content actions bloc is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: MetadataRemixButton(video: _classicVine)),
          ),
        );

        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('a spinner while the remix is being prepared', (
        tester,
      ) async {
        when(
          () => contentActions.state,
        ).thenReturn(const VideoContentActionsState(isPreparingRemix: true));
        await tester.pumpWidget(buildSubject(video: _classicVine));

        expect(
          find.descendant(
            of: remixButton,
            matching: find.byType(DivineCircularProgressIndicator),
          ),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping it asks the bloc for a remix', (tester) async {
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(remixButton);
        await tester.pump();

        verify(
          () => contentActions.add(const VideoContentRemixRequested()),
        ).called(1);
      });

      testWidgets('ignores taps while the remix is being prepared', (
        tester,
      ) async {
        when(
          () => contentActions.state,
        ).thenReturn(const VideoContentActionsState(isPreparingRemix: true));
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(remixButton);
        await tester.pump();

        verifyNever(() => contentActions.add(any()));
      });

      testWidgets('ignores taps while a save is in flight', (tester) async {
        when(
          () => contentActions.state,
        ).thenReturn(const VideoContentActionsState(isSaving: true));
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(remixButton);
        await tester.pump();

        verifyNever(() => contentActions.add(any()));
      });

      testWidgets('ignores taps while the video is being deleted', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(video: _video(), owner: ownerCubit(isDeleting: true)),
        );

        await tester.tap(remixButton);
        await tester.pump();

        verifyNever(() => contentActions.add(any()));
      });
    });

    group('on the web', () {
      const openSheetLabel = 'open sheet';
      late UrlLauncherPlatform originalLauncher;
      late UrlLauncherTestDouble launcher;

      setUp(() {
        originalLauncher = UrlLauncherPlatform.instance;
        launcher = UrlLauncherTestDouble();
        UrlLauncherPlatform.instance = launcher;
      });

      tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

      // Pushes the button on its own route, standing in for the sheet, so the
      // nudge has a route to close and an opener to report on.
      Future<void> openSheet(WidgetTester tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: BlocProvider<VideoContentActionsBloc>.value(
                          value: contentActions,
                          child: MetadataRemixButton(
                            video: _classicVine,
                            isWeb: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text(openSheetLabel),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(openSheetLabel));
        await tester.pumpAndSettle();
      }

      testWidgets('closes the sheet and points to the app instead', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.tap(remixButton);
        await tester.pumpAndSettle();

        expect(remixButton, findsNothing);
        expect(find.text(openSheetLabel), findsOneWidget);
        expect(find.text(l10n.remixWebAppNudge), findsOneWidget);
        expect(find.text(l10n.remixWebGetTheApp), findsOneWidget);
        verifyNever(() => contentActions.add(any()));
      });

      testWidgets('Get the app opens the download page in the browser', (
        tester,
      ) async {
        await openSheet(tester);
        await tester.tap(remixButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.remixWebGetTheApp));
        await tester.pumpAndSettle();

        final launched = launcher.launched.single;
        expect(launched.url, AppConstants.downloadUrl);
        expect(launched.useExternalApplication, isTrue);
      });
    });
  });
}
