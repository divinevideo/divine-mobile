import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_link/profile_link_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  UserProfile profile(String name, {String? website}) => UserProfile(
    pubkey: pubkey,
    nip05: '_@$name.divine.video',
    website: website,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'synthetic-profile',
  );

  test(
    'superseded verification cannot replace the current profile link',
    () async {
      final oldVerification = Completer<bool>();
      final newVerification = Completer<bool>();
      final cubit = ProfileLinkCubit(
        pubkey: pubkey,
        profile: profile('alice'),
        resolver: ProfileLinkResolver(
          verifyClaim: (_, claim) => claim == '_@alice.divine.video'
              ? oldVerification.future
              : newVerification.future,
          lookupUsername: (_) async => const DivineUsernameUnknown(),
        ),
      );
      addTearDown(cubit.close);
      final oldLoad = cubit.load(pubkey: pubkey, profile: profile('alice'));
      final newLoad = cubit.load(pubkey: pubkey, profile: profile('carol'));
      newVerification.complete(true);
      await newLoad;
      expect(cubit.state.link.url, 'https://carol.divine.video');
      oldVerification.complete(true);
      await oldLoad;
      expect(cubit.state.link.url, 'https://carol.divine.video');
    },
  );

  test('display and sharing reuse pending ownership verification', () async {
    final verification = Completer<bool>();
    var lookups = 0;
    final current = profile('alice');
    final cubit = ProfileLinkCubit(
      pubkey: pubkey,
      profile: current,
      resolver: ProfileLinkResolver(
        verifyClaim: (_, _) {
          lookups++;
          return verification.future;
        },
        lookupUsername: (_) async => const DivineUsernameUnknown(),
      ),
    );
    addTearDown(cubit.close);
    final first = cubit.load(pubkey: pubkey, profile: current);
    final second = cubit.load(pubkey: pubkey, profile: current);
    verification.complete(true);
    expect((await first).url, 'https://alice.divine.video');
    expect((await second).url, cubit.state.link.url);
    expect(lookups, 1);
  });

  test('a changed custom website is retained after re-resolution', () async {
    final cubit = ProfileLinkCubit(
      pubkey: pubkey,
      profile: null,
      resolver: ProfileLinkResolver(
        verifyClaim: (_, _) async => true,
        lookupUsername: (_) async => const DivineUsernameUnknown(),
      ),
    );
    addTearDown(cubit.close);
    await cubit.load(pubkey: pubkey, profile: profile('alice'));
    await cubit.load(
      pubkey: pubkey,
      profile: profile('alice', website: 'https://creator.example/shop'),
    );
    expect(cubit.state.link.website, 'https://creator.example/shop');
    expect(cubit.state.link.url, 'https://alice.divine.video');
  });

  test('closing during verification does not emit after disposal', () async {
    final verification = Completer<bool>();
    final cubit = ProfileLinkCubit(
      pubkey: pubkey,
      profile: null,
      resolver: ProfileLinkResolver(
        verifyClaim: (_, _) => verification.future,
        lookupUsername: (_) async => const DivineUsernameUnknown(),
      ),
    );
    final load = cubit.load(pubkey: pubkey, profile: profile('alice'));
    await cubit.close();
    verification.complete(true);
    await expectLater(load, completes);
  });
}
