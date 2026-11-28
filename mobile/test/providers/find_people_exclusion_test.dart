// ABOUTME: Pins the account exclusions Find people applies before showing anyone.
// ABOUTME: Covers the live blocklist and policy wiring the provider passes in.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/find_people_providers.dart';

void main() {
  group('isExcludedFromFindPeople', () {
    const viewer =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const blocked =
        'b1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const stranger =
        'c1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    late ContentBlocklistRepository blocklist;
    late ContentPolicyEngine engine;

    setUp(() {
      blocklist = ContentBlocklistRepository();
      engine = ContentPolicyEngine.defaultRules();
    });

    test('excludes an account the viewer blocked', () async {
      await blocklist.blockUser(blocked, ourPubkey: viewer);

      expect(isExcludedFromFindPeople(blocked, blocklist, engine), isTrue);
    });

    test('keeps an account the viewer has not hidden', () async {
      await blocklist.blockUser(blocked, ourPubkey: viewer);

      expect(isExcludedFromFindPeople(stranger, blocklist, engine), isFalse);
    });
  });
}
