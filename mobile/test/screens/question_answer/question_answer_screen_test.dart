// ABOUTME: Tests the page where a viewer answers a question sticker: the send
// ABOUTME: button waits for an answer, and what became of it is told.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/question_answer_target.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/question_answer/question_answer_screen.dart';

class _MockQuestionAnswerCubit extends MockCubit<QuestionAnswerState>
    implements QuestionAnswerCubit {}

final String _creator = '1'.padLeft(64, '0');

void main() {
  group(QuestionAnswerView, () {
    late _MockQuestionAnswerCubit cubit;
    final target = QuestionAnswerTarget(
      creatorPubkey: _creator,
      question: 'Ask me anything',
      videoDTag: 'video-d',
    );
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockQuestionAnswerCubit();
      when(() => cubit.state).thenReturn(const QuestionAnswerState());
      when(() => cubit.submit(any())).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/answer',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('feed')),
            routes: [
              GoRoute(
                path: 'answer',
                builder: (_, _) => BlocProvider<QuestionAnswerCubit>.value(
                  value: cubit,
                  child: QuestionAnswerView(target: target),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileReactiveProvider(_creator).overrideWith((ref) async* {
              yield UserProfile(
                pubkey: _creator,
                displayName: 'Alice',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'event',
              );
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('the question and who reads the answer', (tester) async {
        await pump(tester);

        expect(find.text('Ask me anything'), findsOneWidget);
        expect(
          find.text(l10n.videoStickerQuestionAnswerPrivacyNote('Alice')),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('sends nothing until there is an answer', (tester) async {
        await pump(tester);

        await tester.tap(find.text(l10n.videoStickerQuestionAnswerSend));
        verifyNever(() => cubit.submit(any()));

        await tester.enterText(find.byType(TextField), 'Pizza');
        await tester.pump();
        await tester.tap(find.text(l10n.videoStickerQuestionAnswerSend));

        verify(() => cubit.submit('Pizza')).called(1);
      });

      testWidgets('tells the answer went out and goes back', (tester) async {
        whenListen(
          cubit,
          Stream.value(
            const QuestionAnswerState(status: QuestionAnswerStatus.sent),
          ),
          initialState: const QuestionAnswerState(),
        );
        await pump(tester);
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoStickerQuestionAnswerSent), findsOneWidget);
        expect(find.text('feed'), findsOneWidget);
      });

      testWidgets('tells when the answer did not go through', (tester) async {
        whenListen(
          cubit,
          Stream.value(
            const QuestionAnswerState(status: QuestionAnswerStatus.failed),
          ),
          initialState: const QuestionAnswerState(),
        );
        await pump(tester);
        await tester.pump();

        expect(
          find.text(l10n.videoStickerQuestionAnswerFailed),
          findsOneWidget,
        );
        expect(find.byType(QuestionAnswerView), findsOneWidget);
      });
    });
  });
}
