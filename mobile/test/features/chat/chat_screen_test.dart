import 'package:bloc_test/bloc_test.dart';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

class _ChatCubit extends MockCubit<ChatState> implements ChatCubit {}

void main() {
  group(ChatScreen, () {
    for (final width in [390.0, 1400.0]) {
      for (final theme in [VineTheme.theme, VineTheme.lightTheme]) {
        testWidgets(
          'sender identity and readable layout at $width in ${theme.brightness}',
          (
            tester,
          ) async {
            const author =
                '3333333333333333333333333333333333333333333333333333333333333333';
            final cubit = _ChatCubit();
            when(() => cubit.state).thenReturn(const ChatState());
            when(cubit.visibleMessages).thenReturn([
              ChatMessage(
                id: '5555555555555555555555555555555555555555555555555555555555555555',
                channelId: 'general',
                author: author,
                body: 'Hello room',
                createdAt: 1,
              ),
            ]);
            whenListen(cubit, const Stream<ChatState>.empty());
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  fetchUserProfileProvider(author).overrideWith(
                    (ref) async => UserProfile(
                      pubkey: author,
                      displayName: 'Room member',
                      rawData: const {},
                      createdAt: DateTime(2026),
                      eventId: '6' * 64,
                    ),
                  ),
                  profileIdentityResolvingProvider(author)
                      .overrideWithValue(false),
                  profileVanishedProvider(author).overrideWith((ref) => false),
                ],
                child: MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: BlocProvider<ChatCubit>.value(
                    value: cubit,
                    child: const ChatScreen(),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(find.text('Room member'), findsOneWidget);
            expect(find.text('Hello room'), findsOneWidget);
            expect(find.text(author), findsNothing);
            expect(find.byType(UserAvatar), findsOneWidget);
            expect(
              tester.getSize(find.byType(TextField)).width,
              lessThanOrEqualTo(720),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    testWidgets('shows the selected room and no local-only join wizard', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      when(
        () => cubit.state,
      ).thenReturn(const ChatState(selectedChannelId: 'introductions'));
      when(cubit.visibleMessages).thenReturn([]);
      whenListen(cubit, const Stream<ChatState>.empty());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ChatCubit>.value(
            value: cubit,
            child: const ChatScreen(),
          ),
        ),
      );
      expect(find.text('#introductions'), findsNWidgets(2));
      expect(find.byType(Drawer), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).messagesPublicTestDisclosure,
        ),
        findsOneWidget,
      );
    });
    for (final key in [
      null,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
    ]) {
      for (final accepted in [false, true]) {
        testWidgets(
          'composer clears only when durably accepted: $accepted via $key',
          (
            tester,
          ) async {
            final cubit = _ChatCubit();
            when(() => cubit.state).thenReturn(const ChatState());
            when(cubit.visibleMessages).thenReturn([]);
            whenListen(cubit, const Stream<ChatState>.empty());
            when(
              () => cubit.send(
                communityId: any(named: 'communityId'),
                channelId: any(named: 'channelId'),
                author: any(named: 'author'),
                body: any(named: 'body'),
                nowMilliseconds: any(named: 'nowMilliseconds'),
              ),
            ).thenAnswer((_) async => accepted);
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BlocProvider<ChatCubit>.value(
                  value: cubit,
                  child: const ChatScreen(),
                ),
              ),
            );
            await tester.enterText(find.byType(TextField), 'keep this draft');
            await tester.pump();
            if (key == null) {
              await tester.tap(
                find.bySemanticsLabel(
                  lookupAppLocalizations(const Locale('en')).dmMessageSendLabel,
                ),
              );
            } else {
              await tester.sendKeyEvent(key);
            }
            await tester.pump();
            verify(
              () => cubit.send(
                communityId: any(named: 'communityId'),
                channelId: any(named: 'channelId'),
                author: any(named: 'author'),
                body: 'keep this draft',
                nowMilliseconds: any(named: 'nowMilliseconds'),
              ),
            ).called(1);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              accepted ? '' : 'keep this draft',
            );
          },
        );
      }
    }
    group('hardware keyboard composition', () {
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState());
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
        when(
          () => cubit.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).thenAnswer((_) async => false);
      });

      Future<TextEditingController> pumpComposer(WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'draft');
        return tester.widget<TextField>(find.byType(TextField)).controller!;
      }

      void expectNoSend() => verifyNever(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      );

      testWidgets(
        'Shift+Enter leaves newline entry to the platform without sending',
        (
          tester,
        ) async {
          final controller = await pumpComposer(tester);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          expect(handled, isFalse);
          // Text insertion comes from the platform text-input connection.
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'draft\n',
              selection: TextSelection.collapsed(offset: 6),
            ),
          );
          await tester.pump();
          expect(controller.text, 'draft\n');
          expectNoSend();
        },
      );

      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        testWidgets('${modifier.keyLabel} with Enter does not send', (
          tester,
        ) async {
          await pumpComposer(tester);
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(modifier);
          await tester.pump();
          expectNoSend();
        });
      }

      testWidgets('Enter does not send while an IME is composing', (
        tester,
      ) async {
        final controller = await pumpComposer(tester);
        controller.value = const TextEditingValue(
          text: 'draft',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expectNoSend();
      });

      testWidgets('holding Enter sends only once', (tester) async {
        await pumpComposer(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        verify(
          () => cubit.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: 'draft',
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).called(1);
      });

      testWidgets('Enter does not send a whitespace-only draft', (
        tester,
      ) async {
        final controller = await pumpComposer(tester);
        controller.text = '  ';
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expectNoSend();
      });

      for (final state in [
        const ChatState(sending: true),
        const ChatState(loading: true),
        const ChatState(loadFailed: true),
      ]) {
        testWidgets('Enter respects the composer access gate: $state', (
          tester,
        ) async {
          await pumpComposer(tester);
          // The state can change before BlocBuilder rebuilds the field.
          when(() => cubit.state).thenReturn(state);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expectNoSend();
        });
      }
    });
    testWidgets(
      'failed initial loading disables the composer and offers retry',
      (tester) async {
        final cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState(loadFailed: true));
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
        when(cubit.start).thenAnswer((_) async {});
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.tap(
          find.text(lookupAppLocalizations(const Locale('en')).commonRetry),
        );
        verify(cubit.start).called(1);
      },
    );

    group('undelivered message', () {
      const author =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const messageId =
          '5555555555555555555555555555555555555555555555555555555555555555';
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(cubit.visibleMessages).thenReturn([
          ChatMessage(
            id: messageId,
            channelId: 'general',
            author: author,
            body: 'Hello room',
            createdAt: 1,
          ),
        ]);
        whenListen(cubit, const Stream<ChatState>.empty());
      });

      Future<AppLocalizations> pumpRoom(
        WidgetTester tester,
        ChatState state,
      ) async {
        when(() => cubit.state).thenReturn(state);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(author)
                  .overrideWith((ref) async => null),
              profileIdentityResolvingProvider(author).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<ChatCubit>.value(
                value: cubit,
                child: const ChatScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        return lookupAppLocalizations(const Locale('en'));
      }

      testWidgets('is marked as failed and can be retried', (tester) async {
        when(() => cubit.retry(messageId)).thenAnswer((_) async {});
        final l10n = await pumpRoom(
          tester,
          const ChatState(pendingIds: [messageId]),
        );
        expect(find.text(l10n.dmStatusFailed), findsOneWidget);

        await tester.tap(find.text(l10n.dmSendFailedRetry));

        verify(() => cubit.retry(messageId)).called(1);
      });

      testWidgets('is not marked once it is delivered', (tester) async {
        final l10n = await pumpRoom(tester, const ChatState());
        expect(find.text('Hello room'), findsOneWidget);
        expect(find.text(l10n.dmStatusFailed), findsNothing);
        expect(find.text(l10n.dmSendFailedRetry), findsNothing);
      });

      testWidgets('is announced above the conversation', (tester) async {
        final l10n = await pumpRoom(
          tester,
          const ChatState(sendFailed: true, pendingIds: [messageId]),
        );
        expect(find.text(l10n.dmSendFailedMessage), findsOneWidget);
      });
    });

    group('composer', () {
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState());
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
      });

      testWidgets('stays clear of the home indicator and the screen edge', (
        tester,
      ) async {
        const homeIndicator = EdgeInsets.only(bottom: 34);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: homeIndicator,
                viewPadding: homeIndicator,
              ),
              child: child!,
            ),
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        final field = tester.getRect(find.byType(TextField));
        final screen = tester.getRect(find.byType(Scaffold));
        expect(field.bottom, lessThanOrEqualTo(screen.bottom - 34));
        expect(field.left, greaterThanOrEqualTo(16));
      });

      testWidgets('the message field is set up for multi-line messages', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, TextInputType.multiline);
        expect(field.textInputAction, TextInputAction.newline);
        expect(field.textCapitalization, TextCapitalization.sentences);
      });
    });
  });
}
