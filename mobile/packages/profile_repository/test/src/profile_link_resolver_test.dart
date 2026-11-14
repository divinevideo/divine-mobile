import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherKey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final npub = Nip19.encodePubKey(pubkey);
  final fallback = 'https://divine.video/profile/$npub';

  UserProfile profile({String? nip05, String? website}) => UserProfile(
    pubkey: pubkey,
    nip05: nip05,
    website: website,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'synthetic-profile',
  );

  group('ProfileLink equality', () {
    test(
      'link equality tracks the URL, owned username, and custom website',
      () {
        const link = ProfileLink(
          url: 'https://alice.divine.video',
          username: 'alice',
          website: 'https://creator.example/shop',
        );
        expect(
          link,
          const ProfileLink(
            url: 'https://alice.divine.video',
            username: 'alice',
            website: 'https://creator.example/shop',
          ),
        );
        expect(
          link,
          isNot(
            const ProfileLink(
              url: 'https://alice.divine.video',
              username: 'alice',
              website: 'https://creator.example/other',
            ),
          ),
        );
      },
    );
  });

  group('resolve', () {
    test(
      'metadata from another account cannot supply its username or website',
      () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async =>
              throw StateError('unexpected verification'),
          lookupUsername: (_) async => throw StateError('unexpected lookup'),
        );
        final link = await resolver.resolve(
          pubkey: otherKey,
          profile: profile(
            nip05: '_@alice.divine.video',
            website: 'https://creator.example/shop',
          ),
        );
        expect(
          link.url,
          'https://divine.video/profile/${Nip19.encodePubKey(otherKey)}',
        );
        expect(link.username, isNull);
        expect(link.website, isNull);
      },
    );

    for (final claim in [
      '_@alice.divine.video',
      'alice@divine.video',
      'alice@openvine.co',
    ]) {
      test(
        'verifies the raw claim $claim before choosing its domain',
        () async {
          final resolver = ProfileLinkResolver(
            verifyClaim: (key, raw) async {
              expect(key, pubkey);
              expect(raw, claim);
              return true;
            },
            lookupUsername: (_) async => throw StateError('unexpected lookup'),
          );
          final link = await resolver.resolve(
            pubkey: pubkey,
            profile: profile(nip05: claim),
          );
          expect(link.url, 'https://alice.divine.video');
          expect(link.username, 'alice');
        },
      );
    }

    test(
      'unverified claims and lookup errors retain a working fallback',
      () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async => false,
          lookupUsername: (_) async => throw StateError('offline'),
        );
        expect(
          (await resolver.resolve(
            pubkey: pubkey,
            profile: profile(nip05: '_@alice.divine.video'),
          )).url,
          fallback,
        );
        expect(
          (await resolver.resolve(pubkey: pubkey, profile: null)).url,
          fallback,
        );
      },
    );

    test(
      'recovers the canonical owned username when metadata is missing',
      () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async =>
              throw StateError('unexpected verification'),
          lookupUsername: (key) async {
            expect(key, pubkey);
            return const DivineUsernameFound(name: 'Alice', canonical: 'alice');
          },
        );
        expect(
          (await resolver.resolve(pubkey: pubkey, profile: null)).url,
          'https://alice.divine.video',
        );
      },
    );

    for (final result in [
      const DivineUsernameNotFound(),
      const DivineUsernameUnknown(),
      const DivineUsernameFound(name: 'bad', canonical: 'bad/path'),
    ]) {
      test('missing or unusable ownership returns npub for $result', () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async => false,
          lookupUsername: (_) async => result,
        );
        expect(
          (await resolver.resolve(pubkey: pubkey, profile: null)).url,
          fallback,
        );
      });
    }

    test(
      'external identifiers do not trigger a Divine username lookup',
      () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async =>
              throw StateError('unexpected verification'),
          lookupUsername: (_) async => throw StateError('unexpected lookup'),
        );
        expect(
          (await resolver.resolve(
            pubkey: pubkey,
            profile: profile(nip05: 'alice@example.com'),
          )).url,
          fallback,
        );
      },
    );

    for (final website in [
      'https://divine.video/profile/$pubkey',
      'https://www.divine.video/profile/$npub/',
      'divine.video/profile/$pubkey',
    ]) {
      test('replaces only the matching self-link $website', () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async => true,
          lookupUsername: (_) async => const DivineUsernameNotFound(),
        );
        final link = await resolver.resolve(
          pubkey: pubkey,
          profile: profile(nip05: '_@alice.divine.video', website: website),
        );
        expect(link.website, 'https://alice.divine.video');
      });
    }

    for (final website in [
      'https://creator.example/shop',
      'https://divine.video/profile/$otherKey',
      'https://divine.video/profile/$pubkey?tab=likes',
      'https://divine.video/profile/$pubkey#videos',
      'https://divine.video/profile/$pubkey/3',
      'https://other.example/profile/$pubkey',
      'https://divine.video:8443/profile/$pubkey',
      'https://user@divine.video/profile/$pubkey',
    ]) {
      test('preserves custom website $website', () async {
        final resolver = ProfileLinkResolver(
          verifyClaim: (_, _) async => true,
          lookupUsername: (_) async => const DivineUsernameNotFound(),
        );
        final link = await resolver.resolve(
          pubkey: pubkey,
          profile: profile(nip05: '_@alice.divine.video', website: website),
        );
        expect(link.website, website);
      });
    }
  });
}
