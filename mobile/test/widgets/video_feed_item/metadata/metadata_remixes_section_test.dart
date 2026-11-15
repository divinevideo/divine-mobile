// ABOUTME: Tests for the info sheet's Remixes section: when it hides, the
// ABOUTME: remixes it lists, and opening one after closing the sheet.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_remixes_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_remixes_cubit.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoRemixesCubit extends MockCubit<VideoRemixesState>
    implements VideoRemixesCubit {}

const _creatorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _remixerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _remixId =
    '2222222222222222222222222222222222222222222222222222222222222222';

VideoEvent _source({String? dTag = 'source-d'}) => VideoEvent(
  id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  pubkey: _creatorPubkey,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  addressableDTag: dTag,
);

VideoEvent _remix({String id = _remixId, String authorName = 'Remixer'}) =>
    VideoEvent(
      id: id,
      pubkey: _remixerPubkey,
      createdAt: 1700000100,
      content: 'My take',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000),
      authorName: authorName,
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(MetadataRemixesSection, () {
    late _MockVideoRemixesCubit cubit;

    setUp(() {
      cubit = _MockVideoRemixesCubit();
    });

    Widget buildSubject(VideoEvent video, {VideoRemixesCubit? remixes}) =>
        testMaterialApp(
          home: Scaffold(
            body: remixes == null
                ? MetadataRemixesSection(video: video)
                : BlocProvider<VideoRemixesCubit>.value(
                    value: remixes,
                    child: MetadataRemixesSection(video: video),
                  ),
          ),
        );

    group('renders', () {
      testWidgets('nothing for a video with no address', (tester) async {
        when(() => cubit.state).thenReturn(
          VideoRemixesState(remixes: [_remix()], isLoading: false),
        );

        await tester.pumpWidget(
          buildSubject(_source(dTag: null), remixes: cubit),
        );

        expect(_source(dTag: null).addressableId, isNull);
        expect(find.text(l10n.metadataRemixesLabel), findsNothing);
        expect(find.text('Remixer'), findsNothing);
      });

      testWidgets('nothing when no video uses a clip of it', (tester) async {
        when(
          () => cubit.state,
        ).thenReturn(const VideoRemixesState(isLoading: false));

        await tester.pumpWidget(buildSubject(_source(), remixes: cubit));

        expect(find.text(l10n.metadataRemixesLabel), findsNothing);
      });

      testWidgets('nothing while the remixes are read', (tester) async {
        when(() => cubit.state).thenReturn(const VideoRemixesState());

        await tester.pumpWidget(buildSubject(_source(), remixes: cubit));

        expect(find.text(l10n.metadataRemixesLabel), findsNothing);
      });

      testWidgets('nothing without a remixes cubit', (tester) async {
        await tester.pumpWidget(buildSubject(_source()));

        expect(find.text(l10n.metadataRemixesLabel), findsNothing);
      });

      testWidgets('a row for each remix', (tester) async {
        when(() => cubit.state).thenReturn(
          VideoRemixesState(
            remixes: [
              _remix(),
              _remix(
                id: '3333333333333333333333333333333333333333333333333333333333333333',
                authorName: 'Second remixer',
              ),
            ],
            isLoading: false,
          ),
        );

        await tester.pumpWidget(buildSubject(_source(), remixes: cubit));

        expect(find.text(l10n.metadataRemixesLabel), findsOneWidget);
        expect(find.text('Remixer'), findsOneWidget);
        expect(find.text('Second remixer'), findsOneWidget);
        expect(find.text('My take'), findsNWidgets(2));
      });
    });

    group('navigation', () {
      testWidgets('closes the sheet, then opens the tapped remix', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          VideoRemixesState(remixes: [_remix()], isLoading: false),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: BlocProvider<VideoRemixesCubit>.value(
                          value: cubit,
                          child: MetadataRemixesSection(video: _source()),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open sheet'),
                ),
              ),
            ),
            GoRoute(
              path: VideoDetailScreen.path,
              builder: (_, state) =>
                  Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remixer'));
        await tester.pumpAndSettle();

        expect(find.text('Opened $_remixId'), findsOneWidget);
        expect(find.byType(MetadataRemixesSection), findsNothing);
        expect(find.text('open sheet', skipOffstage: false), findsOneWidget);
      });
    });
  });
}
