// ABOUTME: Widget tests for CollaboratorInviteCard.
// ABOUTME: Regression tests for the visual redesign: foreground border paints
// ABOUTME: over content and the container clips video to rounded corners.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/inbox/conversation/widgets/collaborator_invite_card.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/test_provider_overrides.dart';

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _MockVideosRepository extends Mock implements VideosRepository {}

const _creatorPubkey =
    '1122334411223344112233441122334411223344112233441122334411223344';

const _testInvite = CollaboratorInvite(
  messageId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
  videoAddress: '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
  videoKind: 34236,
  creatorPubkey: _creatorPubkey,
  videoDTag: 'skate-loop',
  role: 'Collaborator',
  title: 'Skate loop',
);

void main() {
  late _MockCollaboratorInviteActionsCubit mockCubit;
  late _MockVideosRepository mockVideosRepository;
  late MockNostrClient mockNostrClient;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockCubit = _MockCollaboratorInviteActionsCubit();
    mockVideosRepository = _MockVideosRepository();
    mockNostrClient = createMockNostrService();

    when(() => mockCubit.state).thenReturn(
      const CollaboratorInviteActionsState(),
    );
    when(
      () => mockCubit.loadInvites(any()),
    ).thenReturn(null);
    when(
      () => mockVideosRepository.fetchVideoWithStatsForRouteId(
        any(),
        fallbackRouteIds: any(named: 'fallbackRouteIds'),
      ),
    ).thenAnswer((_) async => null);
  });

  Widget buildSubject({bool isSent = false}) {
    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(mockNostrClient),
        videosRepositoryProvider.overrideWithValue(mockVideosRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<CollaboratorInviteActionsCubit>.value(
            value: mockCubit,
            child: CollaboratorInviteCard(
              invite: _testInvite,
              isSent: isSent,
            ),
          ),
        ),
      ),
    );
  }

  group(CollaboratorInviteCard, () {
    group('card chrome', () {
      testWidgets(
        'clips content to rounded corners via Clip.antiAlias on the container',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(CollaboratorInviteCard),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.clipBehavior == Clip.antiAlias &&
                    w.decoration is BoxDecoration,
              ),
            ),
          );

          expect(container.clipBehavior, Clip.antiAlias);

          final decoration = container.decoration! as BoxDecoration;
          expect(
            decoration.borderRadius,
            BorderRadius.circular(16),
          );
        },
      );

      testWidgets(
        'foregroundDecoration has a border that paints over the video content',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          final container = tester.widget<Container>(
            find.descendant(
              of: find.byType(CollaboratorInviteCard),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.foregroundDecoration is BoxDecoration &&
                    (w.foregroundDecoration! as BoxDecoration).border != null,
              ),
            ),
          );

          final foreground = container.foregroundDecoration! as BoxDecoration;
          expect(foreground.border, isNotNull);
          expect(
            foreground.borderRadius,
            BorderRadius.circular(16),
          );
        },
      );

      testWidgets(
        'sent card aligns to end of row',
        (tester) async {
          await tester.pumpWidget(buildSubject(isSent: true));
          await tester.pump();

          final align = tester.widget<Align>(
            find.descendant(
              of: find.byType(CollaboratorInviteCard),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Align && w.alignment == AlignmentDirectional.centerEnd,
              ),
            ),
          );

          expect(align.alignment, AlignmentDirectional.centerEnd);
        },
      );

      testWidgets(
        'received card aligns to start of row',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          final align = tester.widget<Align>(
            find.descendant(
              of: find.byType(CollaboratorInviteCard),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Align &&
                    w.alignment == AlignmentDirectional.centerStart,
              ),
            ),
          );

          expect(align.alignment, AlignmentDirectional.centerStart);
        },
      );
    });
  });
}
