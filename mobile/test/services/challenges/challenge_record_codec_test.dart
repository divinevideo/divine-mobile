import 'dart:convert';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/challenges/challenge_record_codec.dart';

import '../../../packages/challenges_repository/test/harness.dart';

void main() {
  group('ChallengeRecordCodec.readAction', () {
    test('restores exact signed bytes and signed relay authority', () async {
      final h = Harness();
      final review = await h.prepare();
      final action = (await h.repository.submit(review)).action!;
      final restored = ChallengeRecordCodec.readAction(
        ChallengeRecordCodec.action(action),
      );
      expect(restored.signedBody, action.signedBody);
      expect(restored.review.fields.toJson(), review.fields.toJson());
      expect(restored.challengeRelays, action.challengeRelays);
    });

    test(
      'configured-only acknowledgement cannot gain advertised authority',
      () async {
        final h = Harness();
        final review = await h.prepare();
        final action = (await h.repository.submit(review)).action!;
        const configured = 'wss://configured.example.test';
        final configuredOnly = PendingChallengeAction(
          review: review,
          signedBody: action.signedBody,
          challengeRelays: action.challengeRelays,
          targets: [...action.targets, configured],
          outcomes: const {configured: RelayOutcome.accepted},
        );
        final body = ChallengeRecordCodec.action(configuredOnly);
        expect(ChallengeRecordCodec.readAction(body).submitted, isFalse);
        final corrupted = jsonDecode(body) as Map<String, dynamic>;
        corrupted['challengeRelays'] = [configured];
        expect(
          () => ChallengeRecordCodec.readAction(jsonEncode(corrupted)),
          throwsFormatException,
        );
      },
    );
  });
}
