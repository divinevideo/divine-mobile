// ABOUTME: Tests the NostrConnectFailureReason -> localized-string mapping.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('resolveNostrConnectFailureMessage', () {
    test('maps every reason to a non-empty localized message', () {
      for (final reason in NostrConnectFailureReason.values) {
        final message = resolveNostrConnectFailureMessage(en, reason);
        expect(message, isNotEmpty, reason: '$reason produced an empty string');
      }
    });

    test('maps error-branch reasons to their dedicated keys', () {
      expect(
        resolveNostrConnectFailureMessage(
          en,
          NostrConnectFailureReason.startFailed,
        ),
        equals(en.authNostrConnectStartFailed),
      );
      expect(
        resolveNostrConnectFailureMessage(
          en,
          NostrConnectFailureReason.noExpectedSecret,
        ),
        equals(en.authNostrConnectInvalidSession),
      );
      expect(
        resolveNostrConnectFailureMessage(
          en,
          NostrConnectFailureReason.postConnectFailed,
        ),
        equals(en.authNostrConnectSetupFailed),
      );
    });

    test('falls back to the generic unknown-error copy for null', () {
      expect(
        resolveNostrConnectFailureMessage(en, null),
        equals(en.authUnknownError),
      );
    });

    test(
      'timedOut/cancelled fall back to the generic copy (rendered via their '
      'own NostrConnectState branches, not this resolver)',
      () {
        expect(
          resolveNostrConnectFailureMessage(
            en,
            NostrConnectFailureReason.timedOut,
          ),
          equals(en.authUnknownError),
        );
        expect(
          resolveNostrConnectFailureMessage(
            en,
            NostrConnectFailureReason.cancelled,
          ),
          equals(en.authUnknownError),
        );
      },
    );

    test('new keys are localized, not left as English fallback (de)', () {
      final de = lookupAppLocalizations(const Locale('de'));
      // The #3761 keys are now translated in every locale, so German must
      // not resolve to the English source.
      expect(
        de.authNostrConnectSetupFailed,
        isNot(equals(en.authNostrConnectSetupFailed)),
      );
    });
  });
}
