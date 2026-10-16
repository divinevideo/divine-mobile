// ABOUTME: Tests that each verifier rejection code maps to its own error, and
// ABOUTME: that anything unrecognised still lands on the generic rejection.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/blocs/verify/verify_rejection.dart';

void main() {
  group('verifyErrorForCode', () {
    test('gives each known Discord reason its own error', () {
      expect(
        verifyErrorForCode('discord_dm_link'),
        VerifyConnectError.discordDmLink,
      );
      expect(
        verifyErrorForCode('discord_channel_link'),
        VerifyConnectError.discordChannelLink,
      );
      expect(
        verifyErrorForCode('discord_message_not_found'),
        VerifyConnectError.discordMessageNotFound,
      );
      expect(
        verifyErrorForCode('discord_bot_no_access'),
        VerifyConnectError.discordBotNoAccess,
      );
      expect(
        verifyErrorForCode('discord_author_mismatch'),
        VerifyConnectError.discordAuthorMismatch,
      );
      expect(
        verifyErrorForCode('discord_message_content_unavailable'),
        VerifyConnectError.discordContentUnavailable,
      );
      expect(
        verifyErrorForCode('discord_npub_not_in_message'),
        VerifyConnectError.proofMissingNpub,
      );
    });

    test('falls back when the verifier sends no code', () {
      // Every deployment older than the codes, and every platform that has not
      // adopted them, answers without one.
      expect(verifyErrorForCode(null), VerifyConnectError.proofRejected);
    });

    test('falls back for a code this build has never heard of', () {
      // The service owns the vocabulary and can add to it at any time. A build
      // that met a new value with anything but its generic copy would show the
      // user nothing at all.
      expect(
        verifyErrorForCode('discord_some_future_reason'),
        VerifyConnectError.proofRejected,
      );
    });

    test('falls back for the codes deliberately left unmapped', () {
      // These are real codes with no copy of their own: the invite refusal is
      // already covered by the form's own explainer, and the rest describe a
      // service-side condition the user cannot act on.
      for (final code in const [
        'discord_invite_refused',
        'discord_not_configured',
        'discord_invalid_proof_format',
        'discord_api_error',
      ]) {
        expect(
          verifyErrorForCode(code),
          VerifyConnectError.proofRejected,
          reason: '$code should fall back',
        );
      }
    });
  });
}
