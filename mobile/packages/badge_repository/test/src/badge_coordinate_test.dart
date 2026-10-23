import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(BadgeCoordinate, () {
    group('parse', () {
      test('reads a well-formed badge coordinate', () {
        final coordinate = BadgeCoordinate.parse(
          '${EventKind.badgeDefinition}:${_pubkey(1)}:scene-stealer',
        );

        expect(coordinate?.pubkey, _pubkey(1));
        expect(coordinate?.identifier, 'scene-stealer');
      });

      test('keeps colons inside the identifier', () {
        final coordinate = BadgeCoordinate.parse(
          '${EventKind.badgeDefinition}:${_pubkey(1)}:season:1',
        );

        expect(coordinate?.identifier, 'season:1');
      });

      test('rejects a coordinate with too few parts', () {
        expect(
          BadgeCoordinate.parse('${EventKind.badgeDefinition}:${_pubkey(1)}'),
          isNull,
        );
      });

      test('rejects a non-numeric kind', () {
        expect(BadgeCoordinate.parse('badge:${_pubkey(1)}:x'), isNull);
      });

      test('rejects a kind that is not a badge definition', () {
        expect(BadgeCoordinate.parse('30023:${_pubkey(1)}:x'), isNull);
      });

      test('rejects a malformed pubkey', () {
        expect(
          BadgeCoordinate.parse('${EventKind.badgeDefinition}:not-hex:x'),
          isNull,
        );
      });

      test('rejects an empty identifier', () {
        expect(
          BadgeCoordinate.parse(
            '${EventKind.badgeDefinition}:${_pubkey(1)}:',
          ),
          isNull,
        );
      });
    });

    group('fromNaddr', () {
      test('decodes an naddr that addresses a badge definition', () {
        final encoded = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        ).toNaddr();

        final decoded = BadgeCoordinate.fromNaddr(encoded);

        expect(decoded?.pubkey, _pubkey(1));
        expect(decoded?.identifier, 'scene-stealer');
      });

      test('accepts a nostr: scheme prefix', () {
        final encoded = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        ).toNaddr();

        expect(
          BadgeCoordinate.fromNaddr('nostr:$encoded')?.identifier,
          'scene-stealer',
        );
      });

      test('round-trips the relay hints it was given', () {
        final encoded = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        ).toNaddr(relays: const ['wss://relay.divine.video']);

        expect(
          NIP19Tlv.decodeNaddr(encoded)?.relays,
          const ['wss://relay.divine.video'],
        );
        expect(BadgeCoordinate.fromNaddr(encoded)?.identifier, 'scene-stealer');
      });

      test('rejects a reference that is not an naddr', () {
        expect(BadgeCoordinate.fromNaddr('note1abc'), isNull);
      });

      test('rejects an naddr that does not decode', () {
        expect(BadgeCoordinate.fromNaddr('naddr1notbech32'), isNull);
      });

      test('rejects an naddr addressing another kind', () {
        final encoded = NIP19Tlv.encodeNaddr(
          Naddr(id: 'article', author: _pubkey(1), kind: 30023),
        );

        expect(BadgeCoordinate.fromNaddr(encoded), isNull);
      });

      test('rejects an naddr whose author is not a full pubkey', () {
        final encoded = NIP19Tlv.encodeNaddr(
          Naddr(
            id: 'scene-stealer',
            author: 'abcd',
            kind: EventKind.badgeDefinition,
          ),
        );

        expect(BadgeCoordinate.fromNaddr(encoded), isNull);
      });

      test('rejects an naddr with an empty identifier', () {
        final encoded = NIP19Tlv.encodeNaddr(
          Naddr(
            id: '',
            author: _pubkey(1),
            kind: EventKind.badgeDefinition,
          ),
        );

        expect(BadgeCoordinate.fromNaddr(encoded), isNull);
      });
    });

    group('tryParse', () {
      test('accepts an naddr reference', () {
        final encoded = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        ).toNaddr();

        expect(
          BadgeCoordinate.tryParse(' $encoded ')?.identifier,
          'scene-stealer',
        );
      });

      test('accepts a raw coordinate', () {
        expect(
          BadgeCoordinate.tryParse(
            '${EventKind.badgeDefinition}:${_pubkey(1)}:scene-stealer',
          )?.identifier,
          'scene-stealer',
        );
      });

      test('rejects anything else', () {
        expect(BadgeCoordinate.tryParse('   '), isNull);
      });
    });

    test('value renders the a-tag form', () {
      expect(
        BadgeCoordinate(pubkey: _pubkey(1), identifier: 'x').value,
        '${EventKind.badgeDefinition}:${_pubkey(1)}:x',
      );
    });

    test('toString renders the a-tag form', () {
      expect(
        BadgeCoordinate(pubkey: _pubkey(1), identifier: 'x').toString(),
        '${EventKind.badgeDefinition}:${_pubkey(1)}:x',
      );
    });

    test('compares by pubkey and identifier', () {
      final coordinate = BadgeCoordinate(pubkey: _pubkey(1), identifier: 'x');

      expect(
        coordinate,
        BadgeCoordinate(pubkey: _pubkey(1), identifier: 'x'),
      );
      expect(
        coordinate.hashCode,
        BadgeCoordinate(pubkey: _pubkey(1), identifier: 'x').hashCode,
      );
      expect(
        coordinate,
        isNot(BadgeCoordinate(pubkey: _pubkey(2), identifier: 'x')),
      );
      expect(
        coordinate,
        isNot(BadgeCoordinate(pubkey: _pubkey(1), identifier: 'y')),
      );
      expect(coordinate, isNot('not a coordinate'));
    });
  });

  group('isBadgePubkey', () {
    test('accepts a 64-character lowercase hex key', () {
      expect(isBadgePubkey(_pubkey(1)), isTrue);
    });

    test('rejects a short or non-hex value', () {
      expect(isBadgePubkey('abc'), isFalse);
      expect(isBadgePubkey('Z' * 64), isFalse);
    });
  });

  group('deriveBadgeIdentifier', () {
    test('slugifies a display name', () {
      expect(deriveBadgeIdentifier('  Scene Stealer!  '), 'scene-stealer');
    });

    test('collapses runs of separators and trims edge dashes', () {
      expect(
        deriveBadgeIdentifier('--Loop___of the  Week--'),
        'loop-of-the-week',
      );
    });

    test('returns empty for a name without alphanumerics', () {
      expect(deriveBadgeIdentifier('***'), isEmpty);
    });
  });

  group('badgeRecipientPubkey', () {
    test('passes a hex key through', () {
      expect(badgeRecipientPubkey(' ${_pubkey(1)} '), _pubkey(1));
    });

    test('decodes an npub', () {
      expect(badgeRecipientPubkey(Nip19.encodePubKey(_pubkey(1))), _pubkey(1));
    });

    test('decodes an npub behind a nostr: scheme', () {
      expect(
        badgeRecipientPubkey('nostr:${Nip19.encodePubKey(_pubkey(1))}'),
        _pubkey(1),
      );
    });

    test('decodes an nprofile', () {
      final nprofile = NIP19Tlv.encodeNprofile(Nprofile(pubkey: _pubkey(1)));

      expect(badgeRecipientPubkey(nprofile), _pubkey(1));
    });

    test('rejects an nprofile that does not decode', () {
      expect(badgeRecipientPubkey('nprofile1notbech32'), isNull);
    });

    test('rejects an nprofile carrying a partial key', () {
      final nprofile = NIP19Tlv.encodeNprofile(Nprofile(pubkey: 'abcd'));

      expect(badgeRecipientPubkey(nprofile), isNull);
    });

    test('rejects an nprofile whose relay entry is malformed', () {
      // The pubkey entry for _pubkey(1), then the relay entry [1, 1, 0xff],
      // whose one byte is not valid UTF-8.
      const nprofile =
          'nprofile1qqsqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
          'qegpq8ls0az230';

      expect(badgeRecipientPubkey(nprofile), isNull);
    });

    test('rejects an npub that does not decode', () {
      expect(badgeRecipientPubkey('npub1notbech32'), isNull);
    });

    test('rejects free text', () {
      expect(badgeRecipientPubkey('alice@divine.video'), isNull);
    });
  });

  group('parseBadgeRecipients', () {
    test('splits on whitespace, commas, and semicolons', () {
      final input = [
        _pubkey(1),
        Nip19.encodePubKey(_pubkey(2)),
        _pubkey(3),
      ].join(', ');

      expect(parseBadgeRecipients('$input;\n${_pubkey(4)}'), [
        _pubkey(1),
        _pubkey(2),
        _pubkey(3),
        _pubkey(4),
      ]);
    });

    test('deduplicates keys reached through different encodings', () {
      expect(
        parseBadgeRecipients('${_pubkey(1)} ${Nip19.encodePubKey(_pubkey(1))}'),
        [_pubkey(1)],
      );
    });

    test('drops tokens that are not keys', () {
      expect(parseBadgeRecipients('hello, ${_pubkey(1)}, world'), [_pubkey(1)]);
    });

    test('returns empty for a blank field', () {
      expect(parseBadgeRecipients('   '), isEmpty);
    });
  });
}

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
