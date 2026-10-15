import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_requests/sound_ready_actions_cubit.dart';

void main() {
  test(
    'account switch during permission check prevents use and save',
    () async {
      for (final save in [false, true]) {
        var current = true;
        var acted = false;
        final pending = Completer<AudioEvent?>();
        final cubit = SoundReadyActionsCubit(
          resolveSound: () => pending.future,
          isCurrentAccount: () => current,
        );
        final action = save
            ? cubit.save((_) async {
                acted = true;
              })
            : cubit.use((_) async {
                acted = true;
              });
        current = false;
        pending.complete(
          AudioEvent(id: 'a' * 64, pubkey: 'b' * 64, createdAt: 1),
        );
        await action;
        expect(acted, isFalse);
        await cubit.close();
      }
    },
  );
  test(
    'revoked sound never runs the library effect and reports unavailable',
    () async {
      var saved = false;
      final cubit = SoundReadyActionsCubit(
        resolveSound: () async => null,
        isCurrentAccount: () => true,
      );
      await cubit.save((_) async {
        saved = true;
      });
      expect(saved, isFalse);
      expect(cubit.state, SoundReadyActionStatus.failed);
      await cubit.close();
    },
  );
}
