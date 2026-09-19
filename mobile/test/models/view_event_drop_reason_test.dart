// ABOUTME: Tests the reportability policy for kind-22236 view-event drops.
// ABOUTME: Structural drops must alarm; expected skips must stay silent.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/view_event_drop_reason.dart';

void main() {
  group(ViewEventDropReason, () {
    test('expected skips are not structural', () {
      expect(ViewEventDropReason.notAuthenticated.isStructural, isFalse);
      expect(ViewEventDropReason.nonAddressableVideoKind.isStructural, isFalse);
      expect(ViewEventDropReason.relayRejected.isStructural, isFalse);
    });

    test('a signer that is still warming up is not structural', () {
      // Identity known is not signer ready: a Keycast identity with no local
      // key is authenticated before it can sign, so this drop resolves itself
      // and must not reach Crashlytics as an invariant (#7505).
      expect(ViewEventDropReason.signerNotReady.isStructural, isFalse);
    });

    test('a ready signer that produced no event is not structural', () {
      // A null from the signer factory is an invariant the factory already
      // reported, a remote signer's network failure, or a declined NIP-55
      // prompt. Filing it here re-reported every queued row on every retry
      // sweep and became the top non-fatal on both platforms (#9340).
      expect(ViewEventDropReason.signingFailed.isStructural, isFalse);
    });

    test('failures to build a publishable event are structural', () {
      expect(ViewEventDropReason.missingAddressableDTag.isStructural, isTrue);
      expect(ViewEventDropReason.unexpectedError.isStructural, isTrue);
    });

    test('an inverted watch range is structural, not an expected skip', () {
      expect(ViewEventDropReason.invalidWatchRange.isStructural, isTrue);
    });
  });

  group(ViewEventInvariantException, () {
    test('names the reason without leaking viewer identity', () {
      const exception = ViewEventInvariantException(
        ViewEventDropReason.missingAddressableDTag,
      );

      expect(exception.toString(), contains('missingAddressableDTag'));
      expect(exception.toString(), isNot(contains('npub1')));
      expect(exception.toString(), isNot(contains('nsec1')));
    });
  });
}
