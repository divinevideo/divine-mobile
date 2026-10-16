// ABOUTME: Tests the Nostr-identifier classifier and resolver behind search.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/nostr_search_query.dart';

void main() {
  // Full-length synthetic ids. The bech32 forms are produced by the SDK's own
  // encoders, so these exercise the same decode path the app uses at runtime.
  const hexId =
      'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
  const authorHex =
      '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
  const dTag = 'ip1dd9tAlmw';
  const coordinate = '34236:$authorHex:$dTag';
  const nonVideoCoordinate = '30023:$authorHex:$dTag';

  final npub = NostrKeyUtils.encodePubKey(authorHex);
  final nprofile = NIP19Tlv.encodeNprofile(Nprofile(pubkey: authorHex));
  final note1 = Nip19.encodeNoteId(hexId);
  // Produced by `nak encode nevent`/`naddr`, pinning the real wire format a
  // shared link carries rather than our own encoder.
  const nevent =
      'nevent1qqsvyx8dnn5emv7zzm98cu8h52y68kjklc9ehg2f9vchnkmnernr5ngvsmkn3';
  const naddrVideo =
      'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
      'eqyt7crqpa2zfh72sxpqqqzzmcqtynsu';
  const naddrNonVideo =
      'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
      'eqyt7crqpa2zfh72sxpqqqp65wdhulxv';

  group('resolveNostrSearchTarget', () {
    test('returns null for empty and whitespace queries', () {
      expect(resolveNostrSearchTarget(''), isNull);
      expect(resolveNostrSearchTarget('   '), isNull);
    });

    test('classifies an npub as a profile target', () {
      final target = resolveNostrSearchTarget(npub);

      expect(target, isA<NostrProfileTarget>());
      expect((target! as NostrProfileTarget).hexPubkey, equals(authorHex));
    });

    test('classifies an nprofile as a profile target', () {
      final target = resolveNostrSearchTarget(nprofile);

      expect(target, isA<NostrProfileTarget>());
      expect((target! as NostrProfileTarget).hexPubkey, equals(authorHex));
    });

    test('classifies a bare hex value as ambiguous and lowercases it', () {
      final target = resolveNostrSearchTarget(hexId.toUpperCase());

      expect(target, isA<NostrAmbiguousTarget>());
      expect((target! as NostrAmbiguousTarget).hex, equals(hexId));
    });

    test(
      'classifies note1, nevent1 and a video-kind naddr as video targets',
      () {
        for (final query in [note1, nevent, naddrVideo]) {
          final target = resolveNostrSearchTarget(query);

          expect(target, isA<NostrVideoTarget>(), reason: query);
          expect((target! as NostrVideoTarget).routeId, equals(query));
        }
      },
    );

    test('classifies a video-kind coordinate as a video target', () {
      final target = resolveNostrSearchTarget(coordinate);

      expect(target, isA<NostrVideoTarget>());
      expect((target! as NostrVideoTarget).routeId, equals(coordinate));
    });

    test('rejects a non-video naddr and a non-video coordinate', () {
      expect(resolveNostrSearchTarget(naddrNonVideo), isNull);
      expect(resolveNostrSearchTarget(nonVideoCoordinate), isNull);
    });

    test('rejects partial identifiers so typing never half-resolves', () {
      expect(resolveNostrSearchTarget(npub.substring(0, 12)), isNull);
      expect(resolveNostrSearchTarget(hexId.substring(0, 63)), isNull);
    });

    test('rejects video-kind coordinates whose pubkey is not a full key', () {
      // AId.fromString accepts any middle part, so text that reads like a
      // time of day, or a coordinate still being typed, must not open a video.
      expect(resolveNostrSearchTarget('21:30:00'), isNull);
      expect(resolveNostrSearchTarget('22:15:00 sunset'), isNull);
      expect(resolveNostrSearchTarget('34236:81acbb70:'), isNull);
      expect(resolveNostrSearchTarget('34236:me:$dTag'), isNull);
    });

    test('rejects ordinary text and first-party stable ids', () {
      expect(resolveNostrSearchTarget('cats'), isNull);
      expect(resolveNostrSearchTarget('notebook-clip-42'), isNull);
    });
  });

  group('NostrIdSearchResolver', () {
    NostrIdSearchResolver resolver({
      required Future<bool> Function(String) profileExists,
      required Future<bool> Function(String) videoExists,
    }) {
      return NostrIdSearchResolver(
        profileExists: profileExists,
        videoExists: videoExists,
      );
    }

    Future<bool> neverCalled(String _) async {
      fail('lookup should not run for an unambiguous identifier');
    }

    test('opens a profile for npub without any lookup', () async {
      final action = await resolver(
        profileExists: neverCalled,
        videoExists: neverCalled,
      ).resolve(npub);

      expect(action, isA<OpenProfileAction>());
      expect((action! as OpenProfileAction).npub, equals(npub));
    });

    test('opens a video for note1 without any lookup', () async {
      final action = await resolver(
        profileExists: neverCalled,
        videoExists: neverCalled,
      ).resolve(note1);

      expect(action, isA<OpenVideoAction>());
      expect((action! as OpenVideoAction).routeId, equals(note1));
    });

    test('opens the video when a bare hex names an event', () async {
      final action = await resolver(
        profileExists: (_) async => false,
        videoExists: (routeId) async => routeId == hexId,
      ).resolve(hexId);

      expect(action, isA<OpenVideoAction>());
      expect((action! as OpenVideoAction).routeId, equals(hexId));
    });

    test('opens the profile when a bare hex names only a pubkey', () async {
      final action = await resolver(
        profileExists: (pubkey) async => pubkey == hexId,
        videoExists: (_) async => false,
      ).resolve(hexId);

      expect(action, isA<OpenProfileAction>());
      expect(
        (action! as OpenProfileAction).npub,
        equals(NostrKeyUtils.encodePubKey(hexId)),
      );
    });

    test(
      'opens a found video without waiting for the profile lookup',
      () async {
        // A pasted event id is the common case, and the profile lookup for it
        // can only miss after REST, relays and indexers have all answered.
        final profileLookup = Completer<bool>();
        var resolved = false;
        final pending = resolver(
          profileExists: (_) => profileLookup.future,
          videoExists: (routeId) async => routeId == hexId,
        ).resolve(hexId).whenComplete(() => resolved = true);

        await pumpEventQueue();
        expect(resolved, isTrue);

        profileLookup.complete(false);
        expect(await pending, isA<OpenVideoAction>());
      },
    );

    test('prefers the video when a bare hex somehow names both', () async {
      final action = await resolver(
        profileExists: (_) async => true,
        videoExists: (_) async => true,
      ).resolve(hexId);

      expect(action, isA<OpenVideoAction>());
    });

    test('returns null when a bare hex names neither', () async {
      final action = await resolver(
        profileExists: (_) async => false,
        videoExists: (_) async => false,
      ).resolve(hexId);

      expect(action, isNull);
    });

    test('treats a throwing lookup as a miss', () async {
      final action = await resolver(
        profileExists: (_) async => throw Exception('offline'),
        videoExists: (_) async => false,
      ).resolve(hexId);

      expect(action, isNull);
    });

    test('returns null for ordinary text without any lookup', () async {
      final action = await resolver(
        profileExists: neverCalled,
        videoExists: neverCalled,
      ).resolve('cats');

      expect(action, isNull);
    });
  });
}
