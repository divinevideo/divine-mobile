import 'dart:async';
import 'dart:ui' show Locale;

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart'
    show ListView, Navigator, NavigatorState, Scrollable, SizedBox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute, Scaffold;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show DmMessage;
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/view/collab_room_view.dart';
import 'package:openvine/collab_room/view/widgets/collab_room_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_controls.dart';

import '../../helpers/go_router.dart';
import '../../helpers/scroll.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockCollabRoomCubit extends MockCubit<CollabRoomState>
    implements CollabRoomCubit {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CollabRoom _room({
  required String owner,
  CollabRoomPhase phase = CollabRoomPhase.lobby,
  CollabRoomMemberStatus samStatus = CollabRoomMemberStatus.joined,
  String? layout,
  String? videoAddress,
}) => foldCollabRooms([
  DmMessage(
    id: '1' * 64,
    conversationId: DmRepository.computeConversationId([_author, _sam]),
    senderPubkey: _author,
    content: 'text',
    createdAt: 1,
    giftWrapId: '2' * 64,
    tags: collabRoomTags(
      roomId: '0' * 32,
      type: CollabRoomMessageType.invite,
      recipientPubkey: _sam,
      snapshot: CollabRoomSnapshot(
        revision: 0,
        phase: phase,
        layout: layout,
        videoAddress: videoAddress,
        members: [
          CollabRoomMember(
            pubkey: _author,
            status: CollabRoomMemberStatus.joined,
            cell: phase == CollabRoomPhase.lobby ? null : 0,
          ),
          CollabRoomMember(
            pubkey: _sam,
            status: samStatus,
            cell: phase == CollabRoomPhase.lobby ? null : 1,
          ),
        ],
      ),
    ),
  ),
], ownerPubkey: owner).single;

void main() {
  group(CollabRoomView, () {
    late _MockCollabRoomCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockCollabRoomCubit();
    });

    Finder roomList() => find.byType(Scrollable).first;

    Future<void> scrollTo(WidgetTester tester, String text) =>
        tester.scrollUntilVisible(
          find.text(text),
          200,
          scrollable: roomList(),
        );

    Future<void> pump(WidgetTester tester, CollabRoomState state) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<CollabRoomCubit>.value(
            value: cubit,
            child: const CollabRoomView(),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('a room this device does not know', (tester) async {
        await pump(
          tester,
          const CollabRoomState(status: CollabRoomStatus.missing),
        );
        expect(find.text(l10n.collabRoomMissing), findsOneWidget);
      });

      testWidgets('the host lobby with layouts and the start button', (
        tester,
      ) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _author),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );
        expect(find.text(l10n.collabRoomPickLayout), findsOneWidget);
        expect(find.text(l10n.collabRoomStartHint), findsOneWidget);
        await scrollTo(tester, l10n.collabRoomCancelButton);
        expect(find.text(l10n.collabRoomStartButton), findsOneWidget);
        expect(find.text(l10n.collabRoomCancelButton), findsOneWidget);
      });

      testWidgets('the layouts in a row that scrolls from edge to edge', (
        tester,
      ) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _author),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );
        final row = find.ancestor(
          of: find.byType(SplitScreenPresetTile).first,
          matching: find.byType(ListView),
        );
        final screen = tester.getRect(find.byType(CollabRoomView));

        expect(tester.getRect(row.first).left, screen.left);
        expect(tester.getRect(row.first).right, screen.right);
        // The first tile still lines up with the rest of the room.
        expect(
          tester.getRect(find.byType(SplitScreenPresetTile).first).left,
          screen.left + 16,
        );
      });

      testWidgets('an invite waiting for an answer', (tester) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _sam,
              samStatus: CollabRoomMemberStatus.invited,
            ),
          ),
        );
        await scrollTo(tester, l10n.commonNotNow);
        expect(find.text(l10n.collabRoomJoinButton), findsOneWidget);
        expect(find.text(l10n.commonNotNow), findsOneWidget);
        expect(find.text(l10n.collabRoomStartButton), findsNothing);
      });

      testWidgets('the camera button once filming started', (tester) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _sam,
              phase: CollabRoomPhase.recording,
              layout: 'sideBySide',
            ),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );
        expect(find.text(l10n.collabRoomFilmHint), findsOneWidget);
        await scrollTo(tester, l10n.collabRoomLeaveButton);
        expect(find.text(l10n.collabRoomFilmPartButton), findsOneWidget);
        expect(find.text(l10n.collabRoomLeaveButton), findsOneWidget);
        expect(find.text(l10n.collabRoomComposeButton), findsNothing);
      });

      testWidgets('a posted room with nothing left to do', (tester) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _sam,
              phase: CollabRoomPhase.posted,
              layout: 'sideBySide',
            ),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );
        expect(find.text(l10n.collabRoomPosted), findsOneWidget);
        expect(find.text(l10n.collabRoomFilmPartButton), findsNothing);
        await scrollTo(tester, l10n.listDone);
        expect(find.text(l10n.listDone), findsOneWidget);
      });
    });

    group('a posted room', () {
      final posted = CollabRoomState(
        status: CollabRoomStatus.ready,
        room: _room(
          owner: _sam,
          phase: CollabRoomPhase.posted,
          layout: 'sideBySide',
          videoAddress: '34236:$_author:take-one',
        ),
        layout: SplitScreenLayoutPreset.sideBySide,
      );

      testWidgets('plays the posted video', (tester) async {
        final router = MockGoRouter();
        when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
        when(() => cubit.state).thenReturn(posted);
        await tester.pumpWidget(
          testMaterialApp(
            home: MockGoRouterProvider(
              goRouter: router,
              child: BlocProvider<CollabRoomCubit>.value(
                value: cubit,
                child: const CollabRoomView(),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.bySemanticsLabel(l10n.videoPlayerPlayVideo));

        verify(
          () => router.push<Object?>(
            RoutePaths.videoDetailForId('take-one', author: _author),
          ),
        ).called(1);
      });

      testWidgets('shows no play button before the video is posted', (
        tester,
      ) async {
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _sam,
              phase: CollabRoomPhase.recording,
              layout: 'sideBySide',
            ),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );

        expect(find.bySemanticsLabel(l10n.videoPlayerPlayVideo), findsNothing);
      });

      testWidgets('Done lets the room go and closes it', (tester) async {
        when(() => cubit.state).thenReturn(posted);
        when(cubit.dismiss).thenAnswer((_) async {});
        await tester.pumpWidget(testMaterialApp(home: const SizedBox()));
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<CollabRoomCubit>.value(
                  value: cubit,
                  child: const CollabRoomView(),
                ),
              ),
            );
        await tester.pumpAndSettle();
        await scrollTo(tester, l10n.listDone);
        await tester.pump();

        await tester.tap(find.text(l10n.listDone));
        await tester.pumpAndSettle();

        verify(cubit.dismiss).called(1);
        expect(find.byType(CollabRoomView), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('joining asks the cubit to join', (tester) async {
        when(cubit.join).thenAnswer((_) async {});
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _sam,
              samStatus: CollabRoomMemberStatus.invited,
            ),
          ),
        );
        await scrollUntilTappable(
          tester,
          find.text(l10n.collabRoomJoinButton),
          200,
          scrollable: roomList(),
        );
        await tester.tap(find.text(l10n.collabRoomJoinButton));
        verify(cubit.join).called(1);
      });

      testWidgets('leaving asks first, then leaves', (tester) async {
        when(cubit.leave).thenAnswer((_) async {});
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _sam),
          ),
        );
        await scrollUntilTappable(
          tester,
          find.text(l10n.collabRoomLeaveButton),
          200,
          scrollable: roomList(),
        );
        await tester.tap(find.text(l10n.collabRoomLeaveButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.collabRoomLeaveConfirmTitle), findsOneWidget);
        verifyNever(cubit.leave);

        await tester.tap(find.text(l10n.collabRoomLeaveButton).last);
        await tester.pumpAndSettle();
        verify(cubit.leave).called(1);
      });

      testWidgets('the host asks someone who declined back in', (
        tester,
      ) async {
        when(() => cubit.reinvite(any())).thenAnswer((_) async {});
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(
              owner: _author,
              samStatus: CollabRoomMemberStatus.declined,
            ),
          ),
        );
        await scrollUntilTappable(
          tester,
          find.text(l10n.collabRoomInviteAgain),
          200,
          scrollable: roomList(),
        );
        await tester.tap(find.text(l10n.collabRoomInviteAgain));

        verify(() => cubit.reinvite(_sam)).called(1);
      });

      testWidgets('starting asks the cubit to start', (tester) async {
        when(cubit.start).thenAnswer((_) async {});
        await pump(
          tester,
          CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _author),
            layout: SplitScreenLayoutPreset.sideBySide,
          ),
        );
        await scrollUntilTappable(
          tester,
          find.text(l10n.collabRoomStartButton),
          200,
          scrollable: roomList(),
        );
        await tester.tap(find.text(l10n.collabRoomStartButton));
        verify(cubit.start).called(1);
      });

      testWidgets('a swap moves each person with their cell, not into a '
          'rebuilt one', (tester) async {
        final lobby = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(owner: _author),
          layout: SplitScreenLayoutPreset.sideBySide,
        );
        final swaps = StreamController<CollabRoomState>();
        addTearDown(swaps.close);
        whenListen(cubit, swaps.stream, initialState: lobby);
        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<CollabRoomCubit>.value(
              value: cubit,
              child: const CollabRoomView(),
            ),
          ),
        );
        await tester.pump();
        Finder avatarOf(String pubkey) => find.byWidgetPredicate(
          (widget) => widget is CollabRoomAvatar && widget.pubkey == pubkey,
        );
        final before = tester.element(avatarOf(_sam));
        final left = tester.getCenter(avatarOf(_sam)).dx;

        final swapped = lobby.copyWith(pendingSeats: [_sam, _author]);
        when(() => cubit.state).thenReturn(swapped);
        swaps.add(swapped);
        // One pump delivers the state, the next draws it.
        await tester.pump();
        await tester.pump();

        expect(tester.getCenter(avatarOf(_sam)).dx, lessThan(left));
        expect(tester.element(avatarOf(_sam)), same(before));
      });

      testWidgets('keeps what a cell shows when it is selected or changes '
          'shape', (tester) async {
        final lobby = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(owner: _author),
          layout: SplitScreenLayoutPreset.sideBySide,
        );
        final changes = StreamController<CollabRoomState>();
        addTearDown(changes.close);
        whenListen(cubit, changes.stream, initialState: lobby);
        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<CollabRoomCubit>.value(
              value: cubit,
              child: const CollabRoomView(),
            ),
          ),
        );
        await tester.pump();
        final avatar = find.byWidgetPredicate(
          (widget) => widget is CollabRoomAvatar && widget.pubkey == _sam,
        );
        final before = tester.element(avatar);

        Future<void> show(CollabRoomState state) async {
          when(() => cubit.state).thenReturn(state);
          changes.add(state);
          await tester.pump();
          await tester.pump();
        }

        // Rebuilt, a live camera in the cell would start over black.
        await show(lobby.copyWith(selectedSeat: 1));
        expect(tester.element(avatar), same(before));
        await show(
          lobby.copyWith(layout: SplitScreenLayoutPreset.circleBottomRight),
        );
        expect(tester.element(avatar), same(before));
      });

      for (final action in [
        CollabRoomAction.leave,
        CollabRoomAction.decline,
        CollabRoomAction.cancel,
      ]) {
        testWidgets('closes the room once ${action.name} went through', (
          tester,
        ) async {
          final ready = CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _sam),
            action: action,
            actionStatus: CollabRoomActionStatus.busy,
          );
          final changes = StreamController<CollabRoomState>();
          addTearDown(changes.close);
          whenListen(cubit, changes.stream, initialState: ready);
          await tester.pumpWidget(testMaterialApp(home: const SizedBox()));
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<CollabRoomCubit>.value(
                    value: cubit,
                    child: const CollabRoomView(),
                  ),
                ),
              );
          await tester.pumpAndSettle();
          expect(find.byType(CollabRoomView), findsOneWidget);

          final done = ready.copyWith(
            actionStatus: CollabRoomActionStatus.idle,
          );
          when(() => cubit.state).thenReturn(done);
          changes.add(done);
          await tester.pumpAndSettle();

          expect(find.byType(CollabRoomView), findsNothing);
        });
      }

      for (final (reason, ended) in [
        (
          'calls the room off',
          _room(owner: _sam, phase: CollabRoomPhase.cancelled),
        ),
        (
          'takes this account out',
          _room(
            owner: _sam,
            phase: CollabRoomPhase.recording,
            samStatus: CollabRoomMemberStatus.removed,
          ),
        ),
      ]) {
        testWidgets('closes for a member once the host $reason', (
          tester,
        ) async {
          final open = CollabRoomState(
            status: CollabRoomStatus.ready,
            room: _room(owner: _sam, phase: CollabRoomPhase.recording),
          );
          final changes = StreamController<CollabRoomState>();
          addTearDown(changes.close);
          whenListen(cubit, changes.stream, initialState: open);
          // A screen below with its own Scaffold, to show the snackbar on.
          await tester.pumpWidget(
            testMaterialApp(home: const Scaffold(body: SizedBox())),
          );
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<CollabRoomCubit>.value(
                    value: cubit,
                    child: const CollabRoomView(),
                  ),
                ),
              );
          await tester.pumpAndSettle();

          final closed = open.copyWith(room: ended);
          when(() => cubit.state).thenReturn(closed);
          changes.add(closed);
          await tester.pumpAndSettle();

          expect(find.byType(CollabRoomView), findsNothing);
          expect(
            find.text(
              ended.phase == CollabRoomPhase.cancelled
                  ? l10n.collabRoomCancelled
                  : l10n.collabRoomRemovedYou,
            ),
            findsOneWidget,
          );
        });
      }

      testWidgets('stays open on a room that had ended before', (
        tester,
      ) async {
        const loading = CollabRoomState();
        final changes = StreamController<CollabRoomState>();
        addTearDown(changes.close);
        whenListen(cubit, changes.stream, initialState: loading);
        await tester.pumpWidget(testMaterialApp(home: const SizedBox()));
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<CollabRoomCubit>.value(
                  value: cubit,
                  child: const CollabRoomView(),
                ),
              ),
            );
        // The loading spinner never settles: pump past the push instead.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final cancelled = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(owner: _sam, phase: CollabRoomPhase.cancelled),
        );
        when(() => cubit.state).thenReturn(cancelled);
        changes.add(cancelled);
        await tester.pumpAndSettle();

        expect(find.byType(CollabRoomView), findsOneWidget);
        expect(find.text(l10n.collabRoomCancelled), findsOneWidget);
      });

      testWidgets('a failed action shows a snackbar', (tester) async {
        final ready = CollabRoomState(
          status: CollabRoomStatus.ready,
          room: _room(owner: _author),
          layout: SplitScreenLayoutPreset.sideBySide,
        );
        whenListen(
          cubit,
          Stream.value(
            ready.copyWith(actionStatus: CollabRoomActionStatus.failed),
          ),
          initialState: ready,
        );
        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<CollabRoomCubit>.value(
              value: cubit,
              child: const CollabRoomView(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(l10n.collabRoomActionFailed), findsOneWidget);
      });
    });
  });
}
