// ABOUTME: Tests for the Divine collaborator p-tag helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  final pubkeyA = 'a' * 64;
  // On-curve keys (#8706), ordered a < d < e so the input-order test below
  // still catches a sorting implementation.
  final pubkeyB = 'd' * 64;
  final pubkeyC = 'e' * 64;

  group('buildCollaboratorPTag', () {
    test(
      'builds a 4-element Divine-convention p-tag with lowercase marker',
      () {
        expect(
          buildCollaboratorPTag(pubkeyA),
          equals(['p', pubkeyA, collaboratorInviteRelayHint, 'collaborator']),
        );
      },
    );

    test('canonicalizes supported identifiers and rejects invalid input', () {
      expect(buildCollaboratorPTag(pubkeyA.toUpperCase())[1], pubkeyA);
      expect(
        buildCollaboratorPTag(NostrKeyUtils.encodePubKey(pubkeyA))[1],
        pubkeyA,
      );
      expect(
        () => buildCollaboratorPTag('not-a-pubkey'),
        throwsArgumentError,
      );
    });
  });

  group('canonicalCollaboratorPubkeys', () {
    test('normalizes, filters, excludes, and deduplicates in input order', () {
      final result = canonicalCollaboratorPubkeys(
        identifiers: [
          '  ${pubkeyB.toUpperCase()}  ',
          NostrKeyUtils.encodePubKey(pubkeyB),
          'not-a-pubkey',
          NostrKeyUtils.encodePubKey(pubkeyA),
          pubkeyC,
        ],
        creatorIdentifier: pubkeyA.toUpperCase(),
      );

      expect(result, <String>{pubkeyB, pubkeyC});
    });

    test('keeps the first occurrence of each pubkey in input order', () {
      // Set equality ignores order, so assert over an ordered list with input
      // order deliberately unsorted — otherwise a sorting implementation would
      // satisfy the documented guarantee's tests without honouring it.
      final result = canonicalCollaboratorPubkeys(
        identifiers: [
          pubkeyC,
          pubkeyB,
          NostrKeyUtils.encodePubKey(pubkeyC),
        ],
      );

      expect(result.toList(), <String>[pubkeyC, pubkeyB]);
    });
  });

  group('buildCollaboratorPTags', () {
    test('returns an empty list for empty input', () {
      expect(buildCollaboratorPTags(const <String>[]), isEmpty);
    });

    test('plural output equals iteration of singular over the same input', () {
      final pubkeys = [pubkeyA, pubkeyB, pubkeyC];
      expect(
        buildCollaboratorPTags(pubkeys),
        equals(pubkeys.map(buildCollaboratorPTag).toList()),
      );
    });

    test('accepts a Set as well as a List', () {
      final pubkeys = <String>{pubkeyA, pubkeyB};
      final result = buildCollaboratorPTags(pubkeys);
      expect(result, hasLength(2));
      expect(
        result,
        everyElement(
          predicate<List<String>>(
            (tag) =>
                tag.length == 4 &&
                tag[0] == 'p' &&
                tag[2] == collaboratorInviteRelayHint &&
                tag[3] == 'collaborator',
          ),
        ),
      );
    });

    test('emits only canonical valid pubkeys', () {
      final result = buildCollaboratorPTags([
        pubkeyA.toUpperCase(),
        NostrKeyUtils.encodePubKey(pubkeyA),
        'not-a-pubkey',
        pubkeyB,
      ]);

      expect(result, [
        buildCollaboratorPTag(pubkeyA),
        buildCollaboratorPTag(pubkeyB),
      ]);
    });
  });
}
