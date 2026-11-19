// ABOUTME: Tests the comments panel cubit and that comments open in the
// ABOUTME: panel instead of the sheet where a feed publishes one

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/screens/comments/comments_panel_scope.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('comments panel', () {
    late VideoEvent first;
    late VideoEvent second;

    setUp(() {
      first = TestHelpers.createVideoEvent(id: 'a' * 64);
      second = TestHelpers.createVideoEvent(id: 'b' * 64);
    });

    group(CommentsPanelCubit, () {
      late CommentsPanelCubit cubit;

      setUp(() => cubit = CommentsPanelCubit());
      tearDown(() => cubit.close());

      group('open', () {
        test('shows the request', () {
          unawaited(cubit.open(CommentsPanelRequest(video: first)));

          expect(cubit.state?.video, same(first));
        });

        test('completes the previous request when another opens', () async {
          var completed = false;
          unawaited(
            cubit
                .open(CommentsPanelRequest(video: first))
                .then((_) => completed = true),
          );

          unawaited(cubit.open(CommentsPanelRequest(video: second)));
          await pumpEventQueue();

          expect(completed, isTrue);
          expect(cubit.state?.video, same(second));
        });
      });

      group('dismiss', () {
        test('clears the request and completes its future', () async {
          var completed = false;
          unawaited(
            cubit
                .open(CommentsPanelRequest(video: first))
                .then((_) => completed = true),
          );

          cubit.dismiss();
          await pumpEventQueue();

          expect(cubit.state, isNull);
          expect(completed, isTrue);
        });
      });

      group('closeUnlessShowing', () {
        test('keeps the panel open on its own video', () {
          unawaited(cubit.open(CommentsPanelRequest(video: first)));
          cubit.closeUnlessShowing(first.id);

          expect(cubit.state?.video, same(first));
        });

        test('closes the panel when another video becomes active', () {
          unawaited(cubit.open(CommentsPanelRequest(video: first)));
          cubit.closeUnlessShowing(second.id);

          expect(cubit.state, isNull);
        });
      });
    });

    group('CommentsScreen.show', () {
      testWidgets('opens in the panel a feed above publishes', (tester) async {
        final cubit = CommentsPanelCubit();
        addTearDown(cubit.close);
        late BuildContext callerContext;
        await tester.pumpWidget(
          CommentsPanelScope(
            cubit: cubit,
            child: Builder(
              builder: (context) {
                callerContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final shown = CommentsScreen.show(
          callerContext,
          first,
          initialCommentCount: 3,
        );

        expect(cubit.state?.video, same(first));
        expect(cubit.state?.initialCommentCount, equals(3));

        cubit.dismiss();
        await expectLater(shown, completes);
      });
    });
  });
}
