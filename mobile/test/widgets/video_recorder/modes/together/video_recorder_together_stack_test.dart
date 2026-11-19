import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/modes/together/video_recorder_together_stack.dart';

import '../../../../collab_room/view/collab_room_test_fixtures.dart';
import '../../../../helpers/test_provider_overrides.dart';

class _MockCollabRoomService extends Mock implements CollabRoomService {}

void main() {
  group(VideoRecorderTogetherStack, () {
    late _MockCollabRoomService service;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      service = _MockCollabRoomService();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const VideoRecorderTogetherStack(),
          additionalOverrides: [
            collabRoomServiceProvider.overrideWithValue(service),
          ],
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('the explainer and the invite button', (tester) async {
        when(service.watchRooms).thenAnswer((_) => Stream.value(const []));
        await pump(tester);

        expect(find.text(l10n.collabRoomLobbyTitle), findsOneWidget);
        expect(find.text(l10n.collabRoomLobbyBody), findsOneWidget);
        expect(find.text(l10n.collabRoomLobbyInvite), findsOneWidget);
        expect(find.text(l10n.collabRoomLobbyRooms), findsNothing);
      });

      testWidgets('the rooms the account is in', (tester) async {
        when(service.watchRooms).thenAnswer(
          (_) => Stream.value([
            twoPersonRoom(owner: author),
            twoPersonRoom(owner: sam),
          ]),
        );
        await pump(tester);

        expect(find.text(l10n.collabRoomLobbyRooms), findsOneWidget);
        expect(find.text(l10n.collabRoomTileHosting), findsOneWidget);
        expect(find.text(l10n.collabRoomTileGuest), findsOneWidget);
        expect(find.text(l10n.collabRoomPhaseLobby), findsNWidgets(2));
      });
    });
  });
}
