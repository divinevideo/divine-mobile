import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';

class _ChatCubit extends MockCubit<ChatState> implements ChatCubit {}

void main() {
  group(ChatScreen, () {
    testWidgets('shows the selected room and no local-only join wizard', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      when(() => cubit.state)
          .thenReturn(const ChatState(selectedChannelId: 'introductions'));
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
      expect(find.text('#introductions'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en'))
              .messagesPublicTestDisclosure,
        ),
        findsOneWidget,
      );
    });
    for (final accepted in [false, true]) {
      testWidgets('composer clears only when durably accepted: $accepted', (
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
        await tester.tap(find.byType(DivineIconButton).last);
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          accepted ? '' : 'keep this draft',
        );
      });
    }
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
