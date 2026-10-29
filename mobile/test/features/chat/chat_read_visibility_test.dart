import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';

class _Repository extends Mock implements ConcordRepository {}

const _author =
    '2222222222222222222222222222222222222222222222222222222222222222';

ChatMessage _message(int i, {String? threadRootId}) => ChatMessage(
  id: i.toRadixString(16).padLeft(64, '0'),
  channelId: 'general',
  author: _author,
  body: 'Message $i',
  createdAt: i,
  threadRootId: threadRootId,
);

/// A mocked room: [show] replaces its timeline, and [read] collects every id
/// the screen acknowledges.
class _Room {
  _Room() {
    when(() => repository.changes).thenAnswer((_) => _changes.stream);
    when(() => repository.pendingIds).thenReturn([]);
    when(
      () => repository.timeline(now: any(named: 'now')),
    ).thenAnswer((_) => FoldedThread(_messages, {}));
    cubit = ChatCubit(
      repository,
      initialize: () async {},
      onRead: (snapshot) async => read.addAll(snapshot.map((m) => m.id)),
    );
  }

  final repository = _Repository();
  final _changes = StreamController<void>.broadcast();
  final read = <String>[];
  late final ChatCubit cubit;
  var _messages = <ChatMessage>[];

  void show(List<ChatMessage> messages) {
    _messages = messages;
    _changes.add(null);
  }

  Future<void> close() async {
    await cubit.close();
    await _changes.close();
  }
}

Widget _app(_Room room, {Widget Function(Widget screen)? wrap}) {
  final screen = BlocProvider.value(
    value: room.cubit,
    child: const ChatScreen(),
  );
  return ProviderScope(
    overrides: [
      fetchUserProfileProvider(_author).overrideWith((ref) async => null),
      profileIdentityResolvingProvider(_author).overrideWithValue(false),
      profileVanishedProvider(_author).overrideWith((ref) => false),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: wrap?.call(screen) ?? screen,
    ),
  );
}

void main() {
  group('ChatScreen interactions', () {
    testWidgets(
      'acknowledges rendered messages only while the room is visible and resumed',
      (tester) async {
        const author =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final repo = _Repository();
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        var messages = <ChatMessage>[];
        final read = <String>[];
        when(() => repo.changes).thenAnswer((_) => changes.stream);
        when(() => repo.pendingIds).thenReturn([]);
        when(() => repo.timeline(now: any(named: 'now')))
            .thenAnswer((_) => FoldedThread(messages, {}));
        final cubit = ChatCubit(
          repo,
          initialize: () async {},
          onRead: (snapshot) async {
            read.addAll(snapshot.map((m) => m.id));
          },
        );
        addTearDown(cubit.close);
        await cubit.start();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(author)
                  .overrideWith((ref) async => null),
              profileIdentityResolvingProvider(author).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider.value(value: cubit, child: const ChatScreen()),
            ),
          ),
        );
        ChatMessage message(int i) => ChatMessage(
          id: i.toRadixString(16).padLeft(64, '0'),
          channelId: 'general',
          author: author,
          body: 'Message $i',
          createdAt: i,
        );
        messages = [message(1)];
        changes.add(null);
        await tester.pumpAndSettle();
        expect(read, contains(message(1).id));
        read.clear();
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        );
        await tester.pumpAndSettle();
        messages = [message(1), message(2)];
        changes.add(null);
        await tester.pumpAndSettle();
        expect(read, isEmpty);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(read, contains(message(2).id));
        read.clear();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        messages = [message(1), message(2), message(3)];
        changes.add(null);
        await tester.pumpAndSettle();
        expect(read, isEmpty);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        messages = [message(1), message(2), message(3), message(4)];
        cubit.refresh(now: 4);
        await tester.pumpAndSettle();
        expect(read, contains(message(3).id));
        expect(read, contains(message(4).id));
        messages = List.generate(40, (index) => message(index + 1));
        cubit.refresh(now: 40);
        await tester.pumpAndSettle();
        read.clear();
        final controller = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        controller.jumpTo(200);
        await tester.pump();
        messages = [...messages, message(41)];
        cubit.refresh(now: 41);
        await tester.pumpAndSettle();
        expect(read, isEmpty);
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(read, contains(message(41).id));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('acknowledges nothing while a dialog covers the room', (
      tester,
    ) async {
      final room = _Room();
      addTearDown(room.close);
      await room.cubit.start();
      await tester.pumpWidget(_app(room));
      room.show([_message(1)]);
      await tester.pumpAndSettle();
      expect(room.read, contains(_message(1).id));
      room.read.clear();
      final dialog = showDialog<void>(
        context: tester.element(find.byType(ChatScreen)),
        builder: (_) => const Text('Covered'),
      );
      await tester.pumpAndSettle();
      room.show([_message(1), _message(2)]);
      await tester.pumpAndSettle();
      expect(room.read, isEmpty);
      Navigator.of(tester.element(find.text('Covered'))).pop();
      await dialog;
      await tester.pumpAndSettle();
      expect(room.read, contains(_message(2).id));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('acknowledges nothing while a thread is open', (tester) async {
      final room = _Room();
      addTearDown(room.close);
      await room.cubit.start();
      await tester.pumpWidget(_app(room));
      final root = _message(1);
      room.show([root]);
      await tester.pumpAndSettle();
      expect(room.read, contains(root.id));
      room.read.clear();
      room.cubit.openThread(root.id);
      await tester.pumpAndSettle();
      room.show([root, _message(2, threadRootId: root.id)]);
      await tester.pumpAndSettle();
      expect(room.read, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('acknowledges nothing while the room sits in a hidden tab', (
      tester,
    ) async {
      final room = _Room();
      addTearDown(room.close);
      await room.cubit.start();
      final ticking = ValueNotifier(true);
      addTearDown(ticking.dispose);
      await tester.pumpWidget(
        _app(
          room,
          wrap: (screen) => ValueListenableBuilder<bool>(
            valueListenable: ticking,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: screen,
          ),
        ),
      );
      room.show([_message(1)]);
      await tester.pumpAndSettle();
      expect(room.read, contains(_message(1).id));
      room.read.clear();
      ticking.value = false;
      await tester.pumpAndSettle();
      room.show([_message(1), _message(2)]);
      await tester.pumpAndSettle();
      expect(room.read, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('acknowledges what arrived in the background on resume', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final room = _Room();
      addTearDown(room.close);
      await room.cubit.start();
      await tester.pumpWidget(_app(room));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      room.show([_message(1)]);
      await tester.pumpAndSettle();
      expect(room.read, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(room.read, contains(_message(1).id));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
