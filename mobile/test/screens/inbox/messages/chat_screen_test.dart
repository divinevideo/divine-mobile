import 'package:bloc_test/bloc_test.dart';
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
  });
}
