import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/services/video_sharing_service.dart';

void main() {
  late String owner;
  late Map<String, StreamController<DmDeliveryState>> streams;
  late ShareDeliveryCubit cubit;
  ShareDeliveryRecipient peer(String id) =>
      (pubkey: id, name: id, outcome: ShareResult.queued(id, 'chat-$id'));
  ShareDeliveryRecipient refused(String name) => (
    name: name,
    pubkey: name,
    outcome: const ShareResult.failure(ShareRefusal.blocked),
  );

  setUp(() {
    owner = 'a';
    streams = {};
    cubit = ShareDeliveryCubit(
      currentOwner: () => owner,
      watchDelivery: ({required ownerPubkey, required rumorId}) =>
          (streams[rumorId] = StreamController.broadcast(sync: true)).stream,
    );
  });
  tearDown(() async {
    await cubit.close();
    await Future.wait(streams.values.map((s) => s.close()));
  });

  group(ShareDeliveryCubit, () {
    group('track', () {
      test(
        'offline and held remain distinct at 20 s; a failed send can recover',
        () {
          fakeAsync((async) {
            cubit.track(
              ownerPubkey: 'a',
              recipients: [peer('first'), peer('second')],
            );
            streams['second']!.add(DmDeliveryState.held);
            async.elapse(
              ShareDeliveryCubit.overdueAfter - const Duration(milliseconds: 1),
            );
            expect(cubit.state!.overdue, isFalse);
            async.elapse(const Duration(milliseconds: 1));
            expect(cubit.state!.overdue, isTrue);
            expect(cubit.state!.states, {
              'first': DmDeliveryState.queued,
              'second': DmDeliveryState.held,
            });
            streams['second']!.add(DmDeliveryState.failed);
            expect(cubit.state!.states['second'], DmDeliveryState.failed);
            streams['second']!.add(DmDeliveryState.accepted);
            streams['first']!.add(DmDeliveryState.accepted);
            expect(
              cubit.state!.states.values,
              everyElement(DmDeliveryState.accepted),
            );
            expect(streams.values.any((s) => s.hasListener), isFalse);
          });
        },
      );

      test('emits nothing at the overdue limit once nothing is pending', () {
        fakeAsync((async) {
          cubit.track(ownerPubkey: owner, recipients: [peer('first')]);
          async.elapse(const Duration(seconds: 1));
          streams['first']!.add(DmDeliveryState.failed);
          final afterFailure = cubit.state;
          expect(afterFailure!.states['first'], DmDeliveryState.failed);
          async.elapse(ShareDeliveryCubit.overdueAfter);
          expect(cubit.state, same(afterFailure));
        });
      });

      test('a recipient queued again after failing still becomes overdue', () {
        fakeAsync((async) {
          cubit.track(ownerPubkey: owner, recipients: [peer('first')]);
          streams['first']!.add(DmDeliveryState.failed);
          async.elapse(const Duration(seconds: 1));
          streams['first']!.add(DmDeliveryState.queued);
          async.elapse(
            ShareDeliveryCubit.overdueAfter - const Duration(milliseconds: 1),
          );
          expect(cubit.state!.overdue, isFalse);
          async.elapse(const Duration(milliseconds: 1));
          expect(cubit.state!.overdue, isTrue);
          expect(cubit.state!.states['first'], DmDeliveryState.queued);
        });
      });

      final failure = Exception('delivery query failed');
      blocTest<ShareDeliveryCubit, ShareDeliveryFeedback?>(
        'reports a delivery stream error and marks that recipient failed',
        build: () => ShareDeliveryCubit(
          currentOwner: () => owner,
          watchDelivery: ({required ownerPubkey, required rumorId}) =>
              Stream.error(failure),
        ),
        act: (cubit) =>
            cubit.track(ownerPubkey: owner, recipients: [peer('first')]),
        expect: () => [
          isA<ShareDeliveryFeedback>().having((f) => f.states, 'states', {
            'first': DmDeliveryState.queued,
          }),
          isA<ShareDeliveryFeedback>().having((f) => f.states, 'states', {
            'first': DmDeliveryState.failed,
          }),
        ],
        errors: () => [same(failure)],
      );

      test('a share with nothing to confirm leaves current feedback live', () {
        cubit.track(ownerPubkey: owner, recipients: [peer('first')]);
        cubit.track(ownerPubkey: owner, recipients: [refused('blocked')]);
        streams['first']!.add(DmDeliveryState.accepted);
        expect(cubit.state!.states, {'first': DmDeliveryState.accepted});
      });

      test('feedback keeps the recipients the share was tracked with', () {
        final recipients = [peer('first')];
        cubit.track(ownerPubkey: owner, recipients: recipients);
        recipients.add(peer('late'));
        streams['first']!.add(DmDeliveryState.accepted);
        expect(cubit.state!.recipients.map((r) => r.name), ['first']);
      });

      test(
        'the latest share owns feedback and one queued recipient owns View chat',
        () {
          cubit.track(ownerPubkey: 'a', recipients: [peer('old')]);
          cubit.track(
            ownerPubkey: 'a',
            recipients: [peer('new'), refused('refused')],
          );
          expect(streams['old']!.hasListener, isFalse);
          streams['old']!.add(DmDeliveryState.accepted);
          expect(cubit.state!.chat!.outcome.conversationId, 'chat-new');
          expect(cubit.state!.states['new'], DmDeliveryState.queued);
          expect(cubit.state!.recipients.last.name, 'refused');
          owner = 'b';
          streams['new']!.add(DmDeliveryState.accepted);
          expect(cubit.state, isNull);
          expect(streams['new']!.hasListener, isFalse);
          cubit.track(ownerPubkey: 'a', recipients: [peer('stale')]);
          expect(streams.containsKey('stale'), isFalse);
        },
      );
    });
  });
}
