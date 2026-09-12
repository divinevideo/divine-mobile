// ABOUTME: Tests for MoreActionButton widget
// ABOUTME: Verifies the button renders correctly with proper semantics

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/actions/more_action_button.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  late VideoEvent testVideo;
  late VideoInteractionsBloc mockBloc;
  late RepostsRepository mockRepostsRepository;

  setUp(() {
    mockBloc = _MockVideoInteractionsBloc();
    when(() => mockBloc.state).thenReturn(const VideoInteractionsState());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    mockRepostsRepository = _MockRepostsRepository();
    when(
      () => mockRepostsRepository.fetchEventReposters(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    testVideo = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  group(MoreActionButton, () {
    testWidgets('renders info icon with About caption', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          ],
          home: BlocProvider<VideoInteractionsBloc>.value(
            value: mockBloc,
            child: Scaffold(body: MoreActionButton(video: testVideo)),
          ),
        ),
      );

      expect(find.byType(MoreActionButton), findsOneWidget);

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.info),
        isTrue,
        reason: 'Should render the info DivineIcon',
      );
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          ],
          home: BlocProvider<VideoInteractionsBloc>.value(
            value: mockBloc,
            child: Scaffold(body: MoreActionButton(video: testVideo)),
          ),
        ),
      );

      final semanticsFinder = find.bySemanticsLabel('More options');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('calls onInteracted before opening metadata', (tester) async {
      var interacted = false;

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          ],
          home: BlocProvider<VideoInteractionsBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: MoreActionButton(
                video: testVideo,
                onInteracted: () => interacted = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(interacted, isTrue);
    });
  });
}
