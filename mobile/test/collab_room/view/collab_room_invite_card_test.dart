import 'dart:ui' show Locale;

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/collab_room/view/collab_room_invite_card.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../helpers/test_provider_overrides.dart';
import 'collab_room_test_fixtures.dart';

class _MockCollabRoomService extends Mock implements CollabRoomService {}

void main() {
  group(CollabRoomInviteCard, () {
    late _MockCollabRoomService service;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() => registerFallbackValue(twoPersonRoom(owner: author)));

    setUp(() {
      service = _MockCollabRoomService();
    });

    Future<void> pump(
      WidgetTester tester,
      CollabRoom room, {
      required bool isSent,
    }) async {
      when(
        () => service.watchRoom(roomId),
      ).thenAnswer((_) => Stream.value(room));
      await tester.pumpWidget(
        testMaterialApp(
          home: CollabRoomInviteCard(roomId: roomId, isSent: isSent),
          additionalOverrides: [
            collabRoomServiceProvider.overrideWithValue(service),
          ],
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('join and decline for an open invite', (tester) async {
        await pump(tester, twoPersonRoom(owner: sam), isSent: false);

        expect(find.text(l10n.collabRoomInviteCardTitle), findsOneWidget);
        expect(find.text(l10n.collabRoomJoinButton), findsOneWidget);
        expect(find.text(l10n.commonNotNow), findsOneWidget);
      });

      testWidgets('open room for the invite the host sent', (tester) async {
        await pump(tester, twoPersonRoom(owner: author), isSent: true);

        expect(find.text(l10n.collabRoomOpenButton), findsOneWidget);
        expect(find.text(l10n.collabRoomJoinButton), findsNothing);
      });

      testWidgets('no action once the video is posted', (tester) async {
        await pump(
          tester,
          twoPersonRoom(
            owner: sam,
            phase: CollabRoomPhase.posted,
            samStatus: CollabRoomMemberStatus.joined,
          ),
          isSent: false,
        );

        expect(find.text(l10n.collabRoomPosted), findsOneWidget);
        expect(find.text(l10n.collabRoomOpenButton), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('declining tells the host', (tester) async {
        when(() => service.decline(any())).thenAnswer((_) async {});
        await pump(tester, twoPersonRoom(owner: sam), isSent: false);

        await tester.tap(find.text(l10n.commonNotNow));
        await tester.pump();

        verify(() => service.decline(any())).called(1);
      });
    });
  });
}
