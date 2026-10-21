import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('buildProfileUrl', () {
    const testNpub =
        'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzqujme';

    test('returns subdomain URL for divine.video NIP-05', () {
      expect(
        buildProfileUrl('_@alice.divine.video', testNpub),
        equals('https://alice.divine.video'),
      );
    });

    test('returns subdomain URL for user@subdomain.divine.video NIP-05', () {
      expect(
        buildProfileUrl('user@bob.divine.video', testNpub),
        equals('https://bob.divine.video'),
      );
    });

    test('returns npub profile URL for non-divine.video NIP-05', () {
      expect(
        buildProfileUrl('alice@example.com', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is null', () {
      expect(
        buildProfileUrl(null, testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is empty', () {
      expect(
        buildProfileUrl('', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });
  });
}
