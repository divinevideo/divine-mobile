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

void main() {
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
            fetchUserProfileProvider(author).overrideWith((ref) async => null),
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
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      messages = [message(1), message(2), message(3)];
      changes.add(null);
      await tester.pumpAndSettle();
      expect(read, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
}
