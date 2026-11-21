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
import 'package:openvine/widgets/video_editor/video_editor_toolbar_chip.dart';

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

      testWidgets('only mute and camera in a call: leaving the room leaves '
          'it', (tester) async {
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.joined,
          ),
        );
        expect(find.byType(DivineIconButton), findsNWidgets(2));
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
        // Announced, since nothing on screen moves when it happens.
        expect(
          tester.getSemantics(find.text(l10n.collabRoomCallFailed)),
          isSemantics(label: l10n.collabRoomCallFailed, isLiveRegion: true),
        );
      });

      testWidgets('others that could not be reached', (tester) async {
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.unreachable,
          ),
        );
        expect(find.text(l10n.collabRoomCallUnreachable), findsOneWidget);
        expect(find.text(l10n.collabRoomCallFailed), findsNothing);
        expect(
          tester.getSemantics(find.text(l10n.collabRoomCallUnreachable)),
          isSemantics(
            label: l10n.collabRoomCallUnreachable,
            isLiveRegion: true,
          ),
        );
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
        when(cubit.comeBack).thenAnswer((_) async {});
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.failed,
          ),
        );

        await tester.tap(find.bySemanticsLabel(l10n.collabRoomCallJoin));

        verify(cubit.comeBack).called(1);
      });

      testWidgets('joins again once the others could not be reached', (
        tester,
      ) async {
        when(cubit.comeBack).thenAnswer((_) async {});
        await pump(
          tester,
          const CollabRoomCallState(
            others: {sam},
            status: CollabRoomCallStatus.unreachable,
          ),
        );

        await tester.tap(find.bySemanticsLabel(l10n.collabRoomCallJoin));

        verify(cubit.comeBack).called(1);
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

    Future<CollabRoomCallCubit> pumpEditor(
      WidgetTester tester,
      _FakeCall call,
    ) async {
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
      // One frame sets the part, the next hears the room and draws the chip;
      // its spinner never settles.
      await tester.pump();
      await tester.pump();
      await tester.pump();
      return cubit;
    }

    testWidgets('mutes and unmutes the room call while editing a part', (
      tester,
    ) async {
      final call = _FakeCall();
      final cubit = await pumpEditor(tester, call);
      // The call comes back on its own as the editor opens: no join button.
      expect(find.text(l10n.collabRoomCallJoin), findsNothing);
      expect(find.text(l10n.collabRoomCallConnecting), findsOneWidget);

      await tester.runAsync(cubit.comeBack);
      await tester.pump();
      expect(call.log, ['start']);
      // Joined, but nobody heard yet: the wait shows.
      expect(find.text(l10n.collabRoomCallConnecting), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      // Connecting finishes on its own; a tap changes nothing.
      await tester.tap(find.text(l10n.collabRoomCallConnecting));
      await tester.pump();
      expect(call.log, ['start']);

      // The call was joined in the real event loop, which delivers its news.
      await tester.runAsync(() async {
        call.controller.add(
          const CollabRoomCallSnapshot(
            peers: {sam: CollabRoomCallPeer(pubkey: sam, connected: true)},
          ),
        );
        await pumpEventQueue();
      });
      await tester.pump();
      expect(find.text(l10n.collabRoomCallMute), findsOneWidget);
      expect(find.byType(DivineCircularProgressIndicator), findsNothing);

      await tester.tap(find.text(l10n.collabRoomCallMute));
      await tester.pump();
      expect(call.log, ['start', 'mic false']);

      await tester.runAsync(() async {
        call.controller.add(
          const CollabRoomCallSnapshot(
            micOn: false,
            peers: {sam: CollabRoomCallPeer(pubkey: sam, connected: true)},
          ),
        );
        await pumpEventQueue();
      });
      await tester.pump();
      await tester.tap(find.text(l10n.collabRoomCallUnmute));
      await tester.pump();
      expect(call.log, ['start', 'mic false', 'mic true']);
      await tester.runAsync(cubit.close);
    });

    testWidgets('tries again after the call failed', (tester) async {
      final call = _FakeCall()
        ..startError = const CollabRoomCallException('no relay took it');
      final cubit = await pumpEditor(tester, call);
      // Hanging up cancels a stream subscription, which completes in the
      // real event loop.
      await tester.runAsync(cubit.comeBack);
      await tester.pump();
      expect(find.text(l10n.collabRoomCallJoin), findsOneWidget);

      call.startError = null;
      await tester.tap(find.text(l10n.collabRoomCallJoin));
      await tester.runAsync(pumpEventQueue);
      await tester.pump();

      expect(call.log, ['start', 'stop', 'start']);
      expect(find.text(l10n.collabRoomCallConnecting), findsOneWidget);
      await tester.runAsync(cubit.close);
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

      expect(find.byType(VideoEditorToolbarChip), findsNothing);
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
  Object? startError;

  @override
  Stream<CollabRoomCallSnapshot> get changes => controller.stream;

  @override
  Future<void> start() async {
    log.add('start');
    final error = startError;
    if (error != null) throw error;
  }

  @override
  Future<void> stop() async => log.add('stop');

  @override
  Future<void> setMicOn(bool on) async => log.add('mic $on');

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
