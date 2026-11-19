import 'dart:ui' show Locale;

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/view/collab_room_call_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../helpers/test_provider_overrides.dart';
import 'collab_room_test_fixtures.dart';

class _MockCollabRoomCallCubit extends MockCubit<CollabRoomCallState>
    implements CollabRoomCallCubit {}

CollabRoom _room({
  required String owner,
  String? callKey,
  CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.joined,
  CollabRoomPhase phase = CollabRoomPhase.lobby,
}) => foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([author, sam]),
    senderPubkey: author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: roomId,
      type: CollabRoomMessageType.invite,
      recipientPubkey: sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: phase,
        callKey: callKey,
        members: [
          const CollabRoomMember(
            pubkey: author,
            status: CollabRoomMemberStatus.joined,
          ),
          CollabRoomMember(pubkey: sam, status: samStatus),
        ],
      ),
    ),
  ),
], ownerPubkey: owner).single;

void main() {
  group('collabRoomCallIsOpen', () {
    test('opens a call once someone else is in the room', () {
      final room = _room(owner: author, callKey: 'f' * 64);
      expect(collabRoomCallIsOpen(room), isTrue);
      expect(collabRoomCallOthers(room), {sam});
    });

    test('keeps the call closed without a key, a partner or an open room', () {
      expect(collabRoomCallIsOpen(_room(owner: author)), isFalse);
      expect(
        collabRoomCallIsOpen(
          _room(
            owner: author,
            callKey: 'f' * 64,
            samStatus: CollabRoomMemberStatus.invited,
          ),
        ),
        isFalse,
      );
      expect(
        collabRoomCallIsOpen(
          _room(
            owner: author,
            callKey: 'f' * 64,
            phase: CollabRoomPhase.posted,
          ),
        ),
        isFalse,
      );
      expect(
        collabRoomCallIsOpen(
          _room(
            owner: sam,
            callKey: 'f' * 64,
            samStatus: CollabRoomMemberStatus.invited,
          ),
        ),
        isFalse,
      );
    });
  });

  group(CollabRoomCallControls, () {
    late _MockCollabRoomCallCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockCollabRoomCallCubit();
    });

    Future<void> pump(WidgetTester tester, CollabRoomCallState state) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<CollabRoomCallCubit>.value(
            value: cubit,
            child: const CollabRoomCallControls(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('nothing outside a call', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(home: const CollabRoomCallControls()),
        );
        expect(find.bySemanticsLabel(l10n.collabRoomCallMute), findsNothing);
      });

      testWidgets('connecting with mute and camera buttons', (tester) async {
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.joining,
          ),
        );
        expect(find.text(l10n.collabRoomCallConnecting), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.collabRoomCallMute), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.collabRoomCallCameraOn),
          findsOneWidget,
        );
      });

      testWidgets('a microphone that could not be opened', (tester) async {
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.failed,
          ),
        );
        expect(find.text(l10n.collabRoomCallFailed), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('mutes and turns the camera on in a call', (tester) async {
        when(cubit.toggleMic).thenAnswer((_) async {});
        when(cubit.toggleCamera).thenAnswer((_) async {});
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.joined,
          ),
        );

        await tester.tap(find.bySemanticsLabel(l10n.collabRoomCallMute));
        await tester.tap(find.bySemanticsLabel(l10n.collabRoomCallCameraOn));

        verify(cubit.toggleMic).called(1);
        verify(cubit.toggleCamera).called(1);
      });
    });
  });
}
