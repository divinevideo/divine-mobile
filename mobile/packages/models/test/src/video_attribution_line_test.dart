// ABOUTME: Pins the inspired-by attribution line to its parser so the
// ABOUTME: publish-side writer and the display-side stripper cannot drift.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  final npub = Nip19.encodePubKey('d' * 64);

  group('inspiredByAttributionLine', () {
    test('round-trips through the attribution pattern', () {
      final line = inspiredByAttributionLine(npub);

      final match = inspiredByAttributionPattern.firstMatch(line);
      expect(match, isNotNull);
      expect(match!.group(1), equals(npub));
    });

    test('strips back to the caption when appended after a blank line', () {
      final content = 'a caption\n\n${inspiredByAttributionLine(npub)}';

      expect(stripInspiredByAttribution(content), equals('a caption'));
    });

    test('strips to nothing when it is the whole content', () {
      expect(
        stripInspiredByAttribution(inspiredByAttributionLine(npub)),
        isEmpty,
      );
    });
  });
}
