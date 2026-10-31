// ABOUTME: Tests the page where a creator manages their video replies: pinning
// ABOUTME: and hiding one, and what shows while they load or fail to.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_replies/video_replies_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_replies/video_replies_screen.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoRepliesCubit extends MockCubit<VideoRepliesState>
    implements VideoRepliesCubit {}

VideoEvent _reply(int n, {String? name}) => VideoEvent(
  id: '$n'.padLeft(64, '0'),
  pubkey: '$n'.padLeft(64, 'f'),
  createdAt: 1778120201 + n,
  content: '',
  timestamp: DateTime.utc(2026),
  authorName: name,
);

void main() {
  group(VideoRepliesView, () {
    late _MockVideoRepliesCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockVideoRepliesCubit();
      when(() => cubit.pinToggled(any())).thenAnswer((_) async {});
      when(() => cubit.hideToggled(any())).thenAnswer((_) async {});
      when(() => cubit.load()).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, VideoRepliesState state) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VideoRepliesCubit>.value(
              value: cubit,
              child: const VideoRepliesView(),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('each reply, which one is pinned and which hidden', (
        tester,
      ) async {
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [
              _reply(1, name: 'Alice'),
              _reply(2, name: 'Bob'),
            ],
            curation: RepliesCuration(
              pinnedId: _reply(1).id,
              hiddenIds: {_reply(2).id},
            ),
          ),
        );

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesPinned), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesHidden), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesUnpin), findsOneWidget);
        expect(find.text(l10n.videoStickerRepliesShow), findsOneWidget);
      });

      testWidgets('that there are none yet', (tester) async {
        await pump(
          tester,
          const VideoRepliesState(status: VideoRepliesStatus.loaded),
        );

        expect(find.text(l10n.videoStickerRepliesEmpty), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('pins and hides a reply', (tester) async {
        await pump(
          tester,
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [_reply(1, name: 'Alice')],
          ),
        );

        await tester.tap(find.text(l10n.videoStickerRepliesPin));
        await tester.tap(find.text(l10n.videoStickerRepliesHide));

        verify(() => cubit.pinToggled(_reply(1).id)).called(1);
        verify(() => cubit.hideToggled(_reply(1).id)).called(1);
      });

      testWidgets('reads the replies again after they failed to load', (
        tester,
      ) async {
        await pump(
          tester,
          const VideoRepliesState(status: VideoRepliesStatus.failure),
        );

        expect(find.text(l10n.videoStickerRepliesLoadFailed), findsOneWidget);
        await tester.tap(find.text(l10n.videoStickerRepliesRetry));

        verify(() => cubit.load()).called(1);
      });

      testWidgets('tells when a change could not be saved', (tester) async {
        final loaded = VideoRepliesState(
          status: VideoRepliesStatus.loaded,
          replies: [_reply(1)],
        );
        whenListen(
          cubit,
          Stream.value(
            loaded.copyWith(saveStatus: VideoRepliesSaveStatus.failed),
          ),
          initialState: loaded,
        );
        await pump(tester, loaded);
        await tester.pump();

        expect(find.text(l10n.videoStickerRepliesSaveFailed), findsOneWidget);
      });
    });
  });
}
