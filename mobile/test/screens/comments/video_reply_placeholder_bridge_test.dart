// ABOUTME: Tests the bridge that surfaces an in-flight video reply as a
// ABOUTME: pending row on its destination comments sheet (#5862). Covers
// ABOUTME: seeding from an already-running upload, root targeting, removal on
// ABOUTME: completion, and no re-insert after the relay echo lands.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/screens/comments/comments_screen.dart';

class _MockListBloc extends MockBloc<CommentsListEvent, CommentsListState>
    implements CommentsListBloc {}

class _MockPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

String _hex(String suffix) {
  final hexSuffix = suffix.codeUnits
      .map((c) => c.toRadixString(16).padLeft(2, '0'))
      .join();
  return hexSuffix.padLeft(64, '0');
}

final String _rootEventId = _hex('root');
final String _rootAuthor = _hex('rootauthor');
final String _me = _hex('me');
const _rootCoordinate = '34236:$_rootCoordinateAuthor:vid1';
const _rootCoordinateAuthor =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

DivineVideoDraft _replyDraft({
  required String id,
  required String rootEventId,
  String? rootAddressableId,
  String description = 'nice one',
}) => DivineVideoDraft.create(
  id: id,
  clips: const [],
  title: 'reply',
  description: description,
  hashtags: const {},
  selectedApproach: 'native',
  videoReplyContext: VideoReplyContext(
    rootEventId: rootEventId,
    rootEventKind: 34236,
    rootAuthorPubkey: _rootAuthor,
    rootAddressableId: rootAddressableId,
  ),
);

BackgroundPublishState _publishing(List<DivineVideoDraft> drafts) =>
    BackgroundPublishState(
      uploads: [
        for (final draft in drafts)
          BackgroundUpload(draft: draft, result: null, progress: 0.4),
      ],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(
      OptimisticCommentInserted(
        Comment(
          id: 'x',
          content: '',
          authorPubkey: _me,
          createdAt: DateTime.now(),
          rootEventId: _rootEventId,
          rootAuthorPubkey: _rootAuthor,
        ),
      ),
    );
    registerFallbackValue(const OptimisticCommentRolledBack('x'));
  });

  group(VideoReplyPlaceholderBridge, () {
    late _MockListBloc list;
    late _MockPublishBloc publish;

    setUp(() {
      list = _MockListBloc();
      publish = _MockPublishBloc();
      when(() => list.state).thenReturn(
        CommentsListState(
          rootEventId: _rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: _rootAuthor,
          rootAddressableId: _rootCoordinate,
        ),
      );
    });

    Future<void> pumpBridge(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentsListBloc>.value(value: list),
                BlocProvider<BackgroundPublishBloc>.value(value: publish),
              ],
              child: VideoReplyPlaceholderBridge(
                currentUserPubkey: _me,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    List<OptimisticCommentInserted> insertsOn(_MockListBloc bloc) => verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<OptimisticCommentInserted>().toList();

    void expectNoInserts(_MockListBloc bloc) => verifyNever(
      () => bloc.add(any(that: isA<OptimisticCommentInserted>())),
    );

    testWidgets(
      'seeds a placeholder from an upload already in flight at mount',
      (tester) async {
        // The sheet mounts *after* the publish starts, so a change-only
        // listener would never fire — this is the real-world path.
        final state = _publishing([
          _replyDraft(id: 'draft-1', rootEventId: _rootEventId),
        ]);
        whenListen(
          publish,
          const Stream<BackgroundPublishState>.empty(),
          initialState: state,
        );

        await pumpBridge(tester);

        final inserts = insertsOn(list);
        expect(inserts, hasLength(1));
        expect(inserts.single.placeholder.id, pendingVideoReplyId('draft-1'));
        expect(inserts.single.placeholder.authorPubkey, _me);
        expect(inserts.single.placeholder.content, 'nice one');
      },
    );

    testWidgets('inserts nothing for an upload targeting a different video', (
      tester,
    ) async {
      whenListen(
        publish,
        const Stream<BackgroundPublishState>.empty(),
        initialState: _publishing([
          _replyDraft(id: 'draft-other', rootEventId: _hex('otherroot')),
        ]),
      );

      await pumpBridge(tester);

      expectNoInserts(list);
    });

    testWidgets('matches on the addressable coordinate when ids differ', (
      tester,
    ) async {
      whenListen(
        publish,
        const Stream<BackgroundPublishState>.empty(),
        initialState: _publishing([
          _replyDraft(
            id: 'draft-coord',
            rootEventId: _hex('supersededid'),
            rootAddressableId: _rootCoordinate,
          ),
        ]),
      );

      await pumpBridge(tester);

      expect(insertsOn(list), hasLength(1));
    });

    testWidgets('ignores a plain video publish that is not a reply', (
      tester,
    ) async {
      final plain = DivineVideoDraft.create(
        id: 'draft-plain',
        clips: const [],
        title: 'just a video',
        description: '',
        hashtags: const {},
        selectedApproach: 'native',
      );
      whenListen(
        publish,
        const Stream<BackgroundPublishState>.empty(),
        initialState: _publishing([plain]),
      );

      await pumpBridge(tester);

      expectNoInserts(list);
    });

    testWidgets('rolls the placeholder back when the upload vanishes', (
      tester,
    ) async {
      final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
      whenListen(
        publish,
        Stream.fromIterable([
          _publishing([draft]),
          const BackgroundPublishState(),
        ]),
        initialState: _publishing([draft]),
      );

      await pumpBridge(tester);
      await tester.pump();

      final rollbacks = verify(
        () => list.add(captureAny()),
      ).captured.whereType<OptimisticCommentRolledBack>().toList();
      expect(rollbacks, hasLength(1));
      expect(rollbacks.single.placeholderId, pendingVideoReplyId('draft-1'));
    });

    test('grace window is pinned to 10 seconds', () {
      // This test ensures that videoReplyRelayEchoGrace is exactly
      // Duration(seconds: 10). The grace window is a product decision
      // to hold relay echo swaps for relay confirmation before rolling
      // the placeholder back. If this value changes, the decision should
      // be intentional and documented in the PR.
      expect(videoReplyRelayEchoGrace, equals(const Duration(seconds: 10)));
    });

    testWidgets(
      'keeps placeholder before grace window expires (boundary: -1ms)',
      (tester) async {
        final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
        whenListen(
          publish,
          Stream.fromIterable([
            _publishing([draft]),
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: 'draft-1')],
            ),
          ]),
          initialState: _publishing([draft]),
        );

        await pumpBridge(tester);
        await tester.pump();
        // Pump just before the grace window expires
        await tester.pump(
          videoReplyRelayEchoGrace - const Duration(milliseconds: 1),
        );

        final events = verify(() => list.add(captureAny())).captured;
        expect(events.whereType<OptimisticCommentInserted>(), hasLength(1));
        expect(
          events.whereType<OptimisticCommentRolledBack>(),
          isEmpty,
          reason: 'placeholder should be kept before grace window expires',
        );
      },
    );

    testWidgets(
      'rolls placeholder back when grace window expires (boundary: +1ms)',
      (tester) async {
        final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
        whenListen(
          publish,
          Stream.fromIterable([
            _publishing([draft]),
            const BackgroundPublishState(
              recentlyPublished: [PublishedVideo(draftId: 'draft-1')],
            ),
          ]),
          initialState: _publishing([draft]),
        );

        await pumpBridge(tester);
        await tester.pump();
        // Pump just past the grace window expiration
        await tester.pump(
          videoReplyRelayEchoGrace + const Duration(milliseconds: 1),
        );

        final rollbacks = verify(
          () => list.add(captureAny()),
        ).captured.whereType<OptimisticCommentRolledBack>().toList();
        expect(
          rollbacks,
          hasLength(1),
          reason: 'placeholder should roll back after grace window expires',
        );
        expect(rollbacks.single.placeholderId, pendingVideoReplyId('draft-1'));
      },
    );

    testWidgets('keeps a successful publish placeholder for relay echo swap', (
      tester,
    ) async {
      final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
      whenListen(
        publish,
        Stream.fromIterable([
          _publishing([draft]),
          const BackgroundPublishState(
            recentlyPublished: [PublishedVideo(draftId: 'draft-1')],
          ),
        ]),
        initialState: _publishing([draft]),
      );

      await pumpBridge(tester);
      await tester.pump();

      final events = verify(() => list.add(captureAny())).captured;
      expect(events.whereType<OptimisticCommentInserted>(), hasLength(1));
      expect(events.whereType<OptimisticCommentRolledBack>(), isEmpty);
    });

    testWidgets('rolls a successful publish back after the echo grace window', (
      tester,
    ) async {
      final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
      whenListen(
        publish,
        Stream.fromIterable([
          _publishing([draft]),
          const BackgroundPublishState(
            recentlyPublished: [PublishedVideo(draftId: 'draft-1')],
          ),
        ]),
        initialState: _publishing([draft]),
      );

      await pumpBridge(tester);
      await tester.pump();
      await tester.pump(videoReplyRelayEchoGrace);

      final rollbacks = verify(
        () => list.add(captureAny()),
      ).captured.whereType<OptimisticCommentRolledBack>().toList();
      expect(rollbacks, hasLength(1));
      expect(rollbacks.single.placeholderId, pendingVideoReplyId('draft-1'));
    });

    testWidgets(
      'does not re-insert after the relay echo replaced the placeholder',
      (tester) async {
        // The echo swaps the placeholder out while the upload is still
        // registered. A purely store-diffing sync would see the row missing
        // and add it straight back, producing a duplicate.
        final draft = _replyDraft(id: 'draft-1', rootEventId: _rootEventId);
        whenListen(
          publish,
          Stream.fromIterable([
            _publishing([draft]),
            _publishing([draft]),
          ]),
          initialState: _publishing([draft]),
        );

        await pumpBridge(tester);
        await tester.pump();
        await tester.pump();

        expect(insertsOn(list), hasLength(1));
      },
    );
  });
}
