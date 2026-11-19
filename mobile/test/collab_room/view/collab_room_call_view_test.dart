import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';
import 'package:openvine/collab_room/call/collab_room_call_providers.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
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

      testWidgets('joins again from a call that failed', (tester) async {
        when(cubit.join).thenAnswer((_) async {});
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.failed,
          ),
        );

        await tester.tap(find.bySemanticsLabel(l10n.collabRoomCallJoin));

        verify(cubit.join).called(1);
      });
    });
  });

  group(CollabRoomEditorCallButton, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const part = CollabRoomPartContext(
      roomId: roomId,
      cellAspectRatio: 1,
      me: author,
      callKey: _callKey,
    );

    testWidgets('joins and leaves the room call while editing a part', (
      tester,
    ) async {
      final call = _FakeCall();
      final cubit = CollabRoomCallCubit(
        me: author,
        callKey: _callKey,
        others: const {sam},
        createCall: ({required me, required others, required callKey}) => call,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            collabRoomLiveProvider.overrideWith(
              (ref, id) =>
                  Stream.value(_room(owner: author, callKey: _callKey)),
            ),
            collabRoomCallProvider.overrideWith((ref, id) => cubit),
          ],
          home: const _WithPart(part: part),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.collabRoomCallJoin));
      await tester.pump();
      expect(call.log, ['start']);
      // Joined, but nobody heard yet: the wait shows.
      expect(find.text(l10n.collabRoomCallConnecting), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

      call.controller.add(
        const CollabRoomCallSnapshot(
          peers: {sam: CollabRoomCallPeer(pubkey: sam, connected: true)},
        ),
      );
      await tester.pump();
      expect(find.text(l10n.collabRoomCallLeave), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);

      await tester.tap(find.text(l10n.collabRoomCallLeave));
      // Cancelling a stream subscription completes in the real event loop.
      await tester.runAsync(pumpEventQueue);
      // One pump hears the call end, the next draws it.
      await tester.pump();
      await tester.pump();
      expect(call.log, ['start', 'stop']);
      expect(find.text(l10n.collabRoomCallJoin), findsOneWidget);
    });

    testWidgets('leaves while still connecting', (tester) async {
      final call = _FakeCall();
      final cubit = CollabRoomCallCubit(
        me: author,
        callKey: _callKey,
        others: const {sam},
        createCall: ({required me, required others, required callKey}) => call,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            collabRoomLiveProvider.overrideWith(
              (ref, id) =>
                  Stream.value(_room(owner: author, callKey: _callKey)),
            ),
            collabRoomCallProvider.overrideWith((ref, id) => cubit),
          ],
          home: const _WithPart(part: part),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.collabRoomCallJoin));
      await tester.pump();

      await tester.tap(find.text(l10n.collabRoomCallConnecting));
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      await tester.pump();

      expect(call.log, ['start', 'stop']);
      expect(find.text(l10n.collabRoomCallJoin), findsOneWidget);
    });

    testWidgets('shows nothing once the part is handed in', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const _WithPart(
            part: CollabRoomPartContext(
              roomId: roomId,
              cellAspectRatio: 1,
              me: author,
              callKey: _callKey,
              finished: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.collabRoomCallJoin), findsNothing);
    });
  });
}

const _callKey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

/// Sets [part] as the camera flow's part, then shows the editor's button.
class _WithPart extends ConsumerStatefulWidget {
  const _WithPart({required this.part});

  final CollabRoomPartContext part;

  @override
  ConsumerState<_WithPart> createState() => _WithPartState();
}

class _WithPartState extends ConsumerState<_WithPart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(collabRoomPartProvider.notifier).set(widget.part),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: CollabRoomEditorCallButton());
}

class _FakeCall implements CollabRoomCall {
  final controller = StreamController<CollabRoomCallSnapshot>.broadcast();
  final log = <String>[];

  @override
  Stream<CollabRoomCallSnapshot> get changes => controller.stream;

  @override
  Future<void> start() async => log.add('start');

  @override
  Future<void> stop() async => log.add('stop');

  @override
  Future<void> setMicOn(bool on) async {}

  @override
  Future<void> setCameraOn(bool on) async {}

  @override
  void updateOthers(Set<String> others) {}

  @override
  Future<void> shareLobby({
    required String? layout,
    required List<String> seats,
    required int revision,
  }) async {}
}
