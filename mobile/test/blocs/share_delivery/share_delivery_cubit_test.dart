import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/services/video_sharing_service.dart';

void main() {
  late String owner;
  late Map<String, StreamController<DmDeliveryState>> streams;
  late ShareDeliveryCubit cubit;
  ShareDeliveryRecipient peer(String id) =>
      (pubkey: id, name: id, outcome: ShareResult.queued(id, 'chat-$id'));

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

  testWidgets(
    'offline and held remain distinct at 20 s; a failed send can recover',
    (tester) async {
      cubit.track(
        ownerPubkey: 'a',
        recipients: [peer('first'), peer('second')],
      );
      streams['second']!.add(DmDeliveryState.held);
      await tester.pump(const Duration(seconds: 20));
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
    },
  );

  test(
    'the latest share owns feedback and one queued recipient owns View chat',
    () {
      cubit.track(ownerPubkey: 'a', recipients: [peer('old')]);
      cubit.track(
        ownerPubkey: 'a',
        recipients: [
          peer('new'),
          (
            name: 'refused',
            pubkey: 'other',
            outcome: const ShareResult.failure('blocked'),
          ),
        ],
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
}
