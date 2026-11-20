import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/creator_highlights/invite_friends_cubit.dart';

class _ObservedCubit extends InviteFriendsCubit {
  final errors = <Object>[];

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  group(InviteFriendsCubit, () {
    group('inviteShareText', () {
      test('puts the link on its own line after the message', () {
        expect(
          inviteShareText('  Hi there  ', 'https://example.com'),
          'Hi there\nhttps://example.com',
        );
      });

      test('shares only the link when the message is blank', () {
        expect(
          inviteShareText(' \n ', 'https://example.com'),
          'https://example.com',
        );
      });
    });

    group('share', () {
      test('sends the message and link, then reports it shared', () async {
        final cubit = InviteFriendsCubit();
        final sent = <String>[];
        await cubit.share('Join me!', 'https://example.com', (text) async {
          sent.add(text);
          return InviteShareOutcome.shared;
        });
        expect(sent, ['Join me!\nhttps://example.com']);
        expect(cubit.state.status, InviteShareStatus.shared);
        await cubit.close();
      });

      test('treats an unknown outcome as shared', () async {
        final cubit = InviteFriendsCubit();
        await cubit.share(
          'Hi',
          'https://example.com',
          (_) async => InviteShareOutcome.unknown,
        );
        expect(cubit.state.status, InviteShareStatus.shared);
        await cubit.close();
      });

      test(
        'a dismissed sheet returns to idle so it can be tried again',
        () async {
          final cubit = InviteFriendsCubit();
          await cubit.share(
            'Hi',
            'https://example.com',
            (_) async => InviteShareOutcome.dismissed,
          );
          expect(cubit.state.status, InviteShareStatus.idle);
          await cubit.close();
        },
      );

      test('a share that throws fails, reports, and can be retried', () async {
        final cubit = _ObservedCubit();
        final error = Exception('mail fallback failed');
        await cubit.share(
          'Hi',
          'https://example.com',
          (_) async => throw error,
        );
        expect(cubit.state.status, InviteShareStatus.failed);
        expect(cubit.errors, [same(error)]);

        var retried = false;
        await cubit.share('Hi', 'https://example.com', (_) async {
          retried = true;
          return InviteShareOutcome.shared;
        });
        expect(retried, isTrue);
        expect(cubit.state.status, InviteShareStatus.shared);
        await cubit.close();
      });

      test('a second share while the sheet is open is ignored', () async {
        final cubit = InviteFriendsCubit();
        final open = Completer<InviteShareOutcome>();
        var sends = 0;
        Future<InviteShareOutcome> send(String _) {
          sends++;
          return open.future;
        }

        final first = cubit.share('Hi', 'https://example.com', send);
        expect(cubit.state.status, InviteShareStatus.sharing);
        await cubit.share('Hi', 'https://example.com', send);
        expect(sends, 1);
        open.complete(InviteShareOutcome.dismissed);
        await first;
        await cubit.close();
      });

      test('closing while the sheet is open does not throw', () async {
        final cubit = InviteFriendsCubit();
        final open = Completer<InviteShareOutcome>();
        final sharing = cubit.share('Hi', 'https://example.com', (_) {
          return open.future;
        });
        await cubit.close();
        open.complete(InviteShareOutcome.shared);
        await expectLater(sharing, completes);
      });
    });
  });
}
