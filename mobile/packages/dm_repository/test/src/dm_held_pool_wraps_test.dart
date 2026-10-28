// ABOUTME: Unit tests for the held-wrap record a DM reaction, removal or
// ABOUTME: retraction row keeps (#10012): how it is read back, and which
// ABOUTME: attempt counts as held by the fallback pool.

import 'dart:convert';

import 'package:dm_repository/src/dm_held_pool_wraps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

const _recipient =
    'a6cc4a5f36b7a9f6400303ebf7cd2e4d895fe3e133c29d35f69d6568d86a04b5';
const _wrapId =
    '9f0c3e1b7a5d2c4e6f8a0b1c3d5e7f9a1b3c5d7e9f0a2b4c6d8e0f1a3b5c7d9e';
const _rumorId =
    '4e7d1c9b3a5f8e2d6c0b4a9f3e7d1c5b9a3f7e1d5c9b3a7f1e5d9c3b7a1f5e9d';

void main() {
  group('decodeHeldPoolWraps', () {
    test('reads each recipient and the wrap held for them', () {
      expect(decodeHeldPoolWraps(jsonEncode({_recipient: _wrapId})), {
        _recipient: _wrapId,
      });
    });

    test('reads no record as no held wraps', () {
      expect(decodeHeldPoolWraps(null), isEmpty);
    });

    test('reads a record that is not JSON as no held wraps', () {
      expect(decodeHeldPoolWraps('not json'), isEmpty);
    });

    test('reads a record that is not an object as no held wraps', () {
      expect(decodeHeldPoolWraps(jsonEncode([_recipient, _wrapId])), isEmpty);
    });

    test('drops an entry whose wrap id is not a string', () {
      expect(
        decodeHeldPoolWraps(jsonEncode({_recipient: _wrapId, 'other': 7})),
        {_recipient: _wrapId},
      );
    });
  });

  group('heldPoolWrapOf', () {
    final confirmed = NIP17SendResult.success(
      rumorEventId: _rumorId,
      messageEventId: _wrapId,
      recipientPubkey: _recipient,
    );
    const held = NIP17SendResult.failure(
      'Recipient DM inbox unreadable; published to the fallback pool',
      retryablePending: true,
    );

    test('is the confirmed wrap when the attempt was held', () {
      expect(heldPoolWrapOf(confirmed, held), _wrapId);
    });

    test('is null when the confirmed attempt was delivery', () {
      expect(heldPoolWrapOf(confirmed, confirmed), isNull);
    });

    test('is null when no relay confirmed the wrap', () {
      expect(heldPoolWrapOf(held, held), isNull);
    });
  });
}
