import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group(PendingProfileSave, () {
    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    test('round-trips all fields through encode/decode', () {
      const payload = PendingProfileSave(
        pubkey: pubkey,
        displayName: 'Alice',
        about: 'bio',
        website: 'https://alice.example',
        username: 'alice',
        clearNip05: true,
        picture: 'https://cdn/pic.png',
        banner: '#112233',
        monetizationLinks: [
          MonetizationLink(
            provider: MonetizationLinkProvider.venmo,
            category: MonetizationLinkCategory.tip,
            url: 'https://venmo.com/alice',
            enabled: true,
          ),
        ],
        allowVideoReuse: false,
      );

      final decoded = PendingProfileSave.decode(payload.encode());

      expect(decoded.pubkey, pubkey);
      expect(decoded.displayName, 'Alice');
      expect(decoded.about, 'bio');
      expect(decoded.website, 'https://alice.example');
      expect(decoded.username, 'alice');
      expect(decoded.clearNip05, isTrue);
      expect(decoded.picture, 'https://cdn/pic.png');
      expect(decoded.banner, '#112233');
      expect(decoded.monetizationLinks, hasLength(1));
      expect(decoded.monetizationLinks!.first.url, 'https://venmo.com/alice');
      expect(decoded.allowVideoReuse, isFalse);
    });

    test('omits null optionals and defaults clearNip05/monetizationLinks', () {
      const payload = PendingProfileSave(pubkey: pubkey, displayName: 'Bob');
      final json = payload.toJson();

      expect(json.containsKey('about'), isFalse);
      expect(json.containsKey('username'), isFalse);
      expect(json.containsKey('monetizationLinks'), isFalse);
      expect(json.containsKey('allowVideoReuse'), isFalse);
      expect(json['clearNip05'], isFalse);

      final decoded = PendingProfileSave.decode(payload.encode());
      expect(decoded.about, isNull);
      expect(decoded.username, isNull);
      expect(decoded.clearNip05, isFalse);
      expect(decoded.monetizationLinks, isNull);
      expect(decoded.allowVideoReuse, isNull);
    });

    group('requiresClaim', () {
      test('is true when a non-blank username is set', () {
        expect(
          const PendingProfileSave(
            pubkey: pubkey,
            displayName: 'x',
            username: 'alice',
          ).requiresClaim,
          isTrue,
        );
      });

      test('is false for null or blank username', () {
        expect(
          const PendingProfileSave(
            pubkey: pubkey,
            displayName: 'x',
          ).requiresClaim,
          isFalse,
        );
        expect(
          const PendingProfileSave(
            pubkey: pubkey,
            displayName: 'x',
            username: '   ',
          ).requiresClaim,
          isFalse,
        );
      });
    });
  });
}
