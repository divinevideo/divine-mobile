import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/screens/live/go_live_view.dart';
import 'package:openvine/screens/live/live_room_view.dart';
import 'package:openvine/screens/live/widgets/live_chat_panel.dart';
import 'package:openvine/screens/live/widgets/live_host_controls_sheet.dart';

import '../../helpers/test_provider_overrides.dart';

class _GoLiveCubit extends MockCubit<GoLiveState> implements GoLiveCubit {}

class _RoomBloc extends MockBloc<LiveRoomEvent, LiveRoomState>
    implements LiveRoomBloc {}

class _ChatBloc extends MockBloc<LiveChatEvent, LiveChatState>
    implements LiveChatBloc {}

const _room = LiveRoom(
  id: 'accessibility-room',
  hostPubkey:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  title: 'A room for everyone',
  summary: '',
  imageUrl: null,
  relays: [],
  visibility: LiveRoomVisibility.public,
);

const _ready = LiveRoomState(
  status: LiveRoomStatus.ready,
  room: _room,
  role: LiveRole.host,
  mediaState: LiveMediaState(status: LiveMediaConnectionStatus.connected),
);

Widget _scaled(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(2),
    ),
    child: child,
  ),
);

void main() {
  testWidgets('go live announces an asynchronous start failure', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final cubit = _GoLiveCubit();
      final states = StreamController<GoLiveState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: const GoLiveState());
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<GoLiveCubit>.value(
            value: cubit,
            child: const GoLiveView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      states.add(const GoLiveState(status: GoLiveStatus.submitting));
      await tester.pump();
      await tester.pump();
      final loading = tester.getSemantics(find.text('Start live now'));
      expect(loading.flagsCollection.isLiveRegion, isTrue);
      expect(loading.value, 'Loading');
      states.add(
        const GoLiveState(
          status: GoLiveStatus.failure,
          error: GoLiveError.startFailed,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Unable to start this room. Try again.'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final hostControls in [false, true]) {
    testWidgets(
      '${hostControls ? 'host controls' : 'room'} announces asynchronous errors',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final bloc = _RoomBloc();
          final chat = _ChatBloc();
          final states = StreamController<LiveRoomState>();
          addTearDown(states.close);
          whenListen(bloc, states.stream, initialState: _ready);
          whenListen(
            chat,
            const Stream<LiveChatState>.empty(),
            initialState: const LiveChatState(),
          );
          await tester.pumpWidget(
            testMaterialApp(
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<LiveRoomBloc>.value(value: bloc),
                  BlocProvider<LiveChatBloc>.value(value: chat),
                ],
                child: hostControls
                    ? const Scaffold(body: LiveHostControlsSheet())
                    : const LiveRoomView(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          states.add(_ready.copyWith(error: LiveRoomError.requestFailed));
          await tester.pumpAndSettle();
          expect(
            tester
                .getSemantics(
                  find.text('Unable to update this room. Try again.'),
                )
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('connection status updates are announced', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final room = _RoomBloc();
      final chat = _ChatBloc();
      final states = StreamController<LiveRoomState>();
      addTearDown(states.close);
      whenListen(room, states.stream, initialState: _ready);
      whenListen(
        chat,
        const Stream<LiveChatState>.empty(),
        initialState: const LiveChatState(),
      );
      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<LiveRoomBloc>.value(value: room),
              BlocProvider<LiveChatBloc>.value(value: chat),
            ],
            child: const LiveRoomView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Connected'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      states.add(
        _ready.copyWith(
          mediaState: const LiveMediaState(
            status: LiveMediaConnectionStatus.audioOnly,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Live audio only'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('chat announces an asynchronous send failure', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final room = _RoomBloc();
      final chat = _ChatBloc();
      final states = StreamController<LiveChatState>();
      addTearDown(states.close);
      whenListen(
        room,
        const Stream<LiveRoomState>.empty(),
        initialState: _ready,
      );
      whenListen(chat, states.stream, initialState: const LiveChatState());
      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<LiveRoomBloc>.value(value: room),
              BlocProvider<LiveChatBloc>.value(value: chat),
            ],
            child: const Scaffold(
              body: SizedBox(height: 400, child: LiveChatPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      states.add(const LiveChatState(error: LiveChatError.sendFailed));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Unable to send your message. Try again.'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final screen in ['go live', 'room', 'host controls']) {
    testWidgets('$screen supports double text size on a narrow screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final room = _RoomBloc();
      final chat = _ChatBloc();
      final goLive = _GoLiveCubit();
      whenListen(
        room,
        const Stream<LiveRoomState>.empty(),
        initialState: _ready,
      );
      whenListen(
        chat,
        const Stream<LiveChatState>.empty(),
        initialState: const LiveChatState(),
      );
      whenListen(
        goLive,
        const Stream<GoLiveState>.empty(),
        initialState: const GoLiveState(),
      );
      final view = switch (screen) {
        'go live' => const GoLiveView(),
        'room' => const LiveRoomView(),
        _ => const Scaffold(body: LiveHostControlsSheet()),
      };
      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<LiveRoomBloc>.value(value: room),
              BlocProvider<LiveChatBloc>.value(value: chat),
              BlocProvider<GoLiveCubit>.value(value: goLive),
            ],
            child: _scaled(view),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = find.text(switch (screen) {
        'go live' => 'Start live now',
        'room' => 'Host controls',
        _ => 'End session',
      });
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
