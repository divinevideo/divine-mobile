// ABOUTME: Pins the two independent source axes: hosting and provenance.
// ABOUTME: One shared predicate so feeds and route lookups cannot diverge.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_source_visibility_policy.dart';

import '../test_data/video_test_data.dart';

void main() {
  group('VideoSourceVisibilityPolicy.isHiddenBySourcePreferences', () {
    final divineHosted = createTestVideoEvent(
      id: 'divine',
      videoUrl: 'https://cdn.divine.video/abc.mp4',
    );
    final offHost = createTestVideoEvent(
      id: 'offhost',
      videoUrl: 'https://someone.blossom.band/abc',
    );

    bool hidden(
      VideoEvent video, {
      bool divineHostedOnly = false,
      bool verifiedOnly = false,
    }) => VideoSourceVisibilityPolicy.isHiddenBySourcePreferences(
      video,
      divineHostedOnly: divineHostedOnly,
      verifiedOnly: verifiedOnly,
    );

    test('hides nothing when both preferences are off', () {
      expect(hidden(offHost), isFalse);
      expect(hidden(divineHosted), isFalse);
    });

    test('hosting axis hides off-host media', () {
      expect(hidden(offHost, divineHostedOnly: true), isTrue);
      expect(hidden(divineHosted, divineHostedOnly: true), isFalse);
    });

    test('provenance axis hides media with no capture chain', () {
      // Divine-hosted but unverified: the hosting axis alone would let this
      // through, which is why the two axes are independent.
      expect(hidden(divineHosted, verifiedOnly: true), isTrue);
    });

    test('provenance axis lets through archive Vines funnelcake verifies', () {
      final verifiedVine = createTestVideoEvent(
        id: 'verified-vine',
        rawTags: const {'platform': 'vine'},
      ).copyWith(isVerifiedArchive: true);

      expect(hidden(verifiedVine, verifiedOnly: true), isFalse);
    });

    test('a self-applied platform=vine tag does not satisfy provenance', () {
      final selfTagged = createTestVideoEvent(
        id: 'self-tagged',
        rawTags: const {'platform': 'vine'},
      );

      expect(hidden(selfTagged, verifiedOnly: true), isTrue);
    });

    test('a platform=vine tag satisfies provenance while funnelcake cannot '
        'check the archive', () {
      final unchecked = createTestVideoEvent(
        id: 'unchecked-vine',
        rawTags: const {'platform': 'vine'},
      ).copyWith(isArchiveVerificationUnknown: true);

      expect(hidden(unchecked, verifiedOnly: true), isFalse);
    });

    test('axes are independent, not a single relaxed rule', () {
      // Off-host is hidden by hosting even though provenance is off...
      expect(hidden(offHost, divineHostedOnly: true), isTrue);
      // ...and Divine-hosted is hidden by provenance even though hosting
      // is satisfied. Neither axis can substitute for the other.
      expect(hidden(divineHosted, verifiedOnly: true), isTrue);
    });
  });
}
