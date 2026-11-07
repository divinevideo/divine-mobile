import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';

void main() {
  group('debug B2 host selection', () {
    test('routes originals onto the expected allowlisted build host', () {
      const expectedHost = String.fromEnvironment(
        'EXPECTED_B2_HOST',
        defaultValue: 'media-b2.divine.video',
      );
      const hash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final source = b2OriginalPlaybackUrl('https://media.divine.video/$hash');
      expect(source, 'https://$expectedHost/$hash');
      expect(isB2OriginalPlaybackSource(source!), isTrue);
      expect(
        b2OriginalPlaybackUrl('https://media.divine.video/$hash/720p.mp4'),
        isNull,
      );
    });
  });
}
