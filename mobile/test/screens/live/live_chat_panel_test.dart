import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/live/widgets/live_chat_panel.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRoomBloc extends MockBloc<LiveRoomEvent, LiveRoomState>
    implements LiveRoomBloc {}

class _MockLiveChatBloc extends MockBloc<LiveChatEvent, LiveChatState>
    implements LiveChatBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveChatPanel', () {
    const room = LiveRoom(
      id: 'room-123',
      hostPubkey: 'host-pubkey',
      title: 'Signal from the stage',
      summary: 'A live room for creators and the people following along.',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final session = LiveSession(
      id: 'session-123',
      roomId: room.id,
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 8),
      endedAt: null,
      speakerPubkeys: const <String>['host-pubkey'],
      audienceCount: 64,
    );
    const sessionAddress = '30313:host-pubkey:session-123';

    UserProfile createTestProfile({
      required String pubkey,
      required String displayName,
      String? picture,
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        picture: picture,
        rawData: const {},
        createdAt: DateTime.utc(2026, 4, 6, 8),
        eventId: 'profile-$pubkey',
      );
    }

    testWidgets('renders avatar and cached display name for messages', (
      tester,
    ) async {
      const authorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final profile = createTestProfile(
        pubkey: authorPubkey,
        displayName: 'Alice Stage',
        picture: 'https://example.com/avatar.png',
      );
      final message = LiveChatMessage(
        id: 'chat-1',
        sessionAddress: sessionAddress,
        pubkey: authorPubkey,
        content: 'This room is live.',
        createdAt: DateTime.utc(2026, 4, 6, 8, 1),
      );
      final roomBloc = _MockLiveRoomBloc();
      final chatBloc = _MockLiveChatBloc();
      final roomState = LiveRoomState(
        status: LiveRoomStatus.ready,
        room: room,
        session: session,
        role: LiveRole.audience,
      );
      final chatState = LiveChatState(
        status: LiveChatStatus.ready,
        sessionAddress: sessionAddress,
        messages: <LiveChatMessage>[message],
      );

      when(() => roomBloc.state).thenReturn(roomState);
      whenListen(
        roomBloc,
        Stream<LiveRoomState>.value(roomState),
        initialState: roomState,
      );
      when(() => chatBloc.state).thenReturn(chatState);
      whenListen(
        chatBloc,
        Stream<LiveChatState>.value(chatState),
        initialState: chatState,
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockNip05VerificationService: createMockNip05VerificationService(),
          additionalOverrides: [
            userProfileReactiveProvider(authorPubkey).overrideWith(
              (ref) => Stream.value(profile),
            ),
          ],
          home: Scaffold(
            body: BlocProvider<LiveRoomBloc>.value(
              value: roomBloc,
              child: BlocProvider<LiveChatBloc>.value(
                value: chatBloc,
                child: const SizedBox(
                  height: 360,
                  child: LiveChatPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.text('Alice Stage'), findsOneWidget);
      expect(find.text('This room is live.'), findsOneWidget);
      expect(find.text(authorPubkey), findsNothing);
    });

    testWidgets('switching sessions replaces stale chat messages', (
      tester,
    ) async {
      const authorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final profile = createTestProfile(
        pubkey: authorPubkey,
        displayName: 'Alice Stage',
      );
      const sessionOneAddress = '30313:host-pubkey:session-123';
      const sessionTwoAddress = '30313:host-pubkey:session-456';
      final messageOne = LiveChatMessage(
        id: 'chat-1',
        sessionAddress: sessionOneAddress,
        pubkey: authorPubkey,
        content: 'First session message.',
        createdAt: DateTime.utc(2026, 4, 6, 8, 1),
      );
      final messageTwo = LiveChatMessage(
        id: 'chat-2',
        sessionAddress: sessionTwoAddress,
        pubkey: authorPubkey,
        content: 'Second session message.',
        createdAt: DateTime.utc(2026, 4, 6, 8, 2),
      );
      final roomBloc = _MockLiveRoomBloc();
      final chatBloc = _MockLiveChatBloc();
      final roomState = LiveRoomState(
        status: LiveRoomStatus.ready,
        room: room,
        session: session,
        role: LiveRole.audience,
      );
      final chatState = LiveChatState(
        status: LiveChatStatus.ready,
        sessionAddress: sessionTwoAddress,
        messages: <LiveChatMessage>[messageOne, messageTwo],
      );

      when(() => roomBloc.state).thenReturn(roomState);
      whenListen(
        roomBloc,
        Stream<LiveRoomState>.value(roomState),
        initialState: roomState,
      );
      when(() => chatBloc.state).thenReturn(chatState);
      whenListen(
        chatBloc,
        Stream<LiveChatState>.value(chatState),
        initialState: chatState,
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockNip05VerificationService: createMockNip05VerificationService(),
          additionalOverrides: [
            userProfileReactiveProvider(authorPubkey).overrideWith(
              (ref) => Stream.value(profile),
            ),
          ],
          home: Scaffold(
            body: BlocProvider<LiveRoomBloc>.value(
              value: roomBloc,
              child: BlocProvider<LiveChatBloc>.value(
                value: chatBloc,
                child: const SizedBox(
                  height: 360,
                  child: LiveChatPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First session message.'), findsNothing);
      expect(find.text('Second session message.'), findsOneWidget);
      expect(find.byType(UserAvatar), findsOneWidget);
    });
  });
}
