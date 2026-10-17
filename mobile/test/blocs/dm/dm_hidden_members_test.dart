// ABOUTME: Tests which group members the viewer's own lists hide: whose
// ABOUTME: messages collapse, and who is left for a chat without them.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/dm/dm_hidden_members.dart';

void main() {
  const viewer =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const hiddenMember =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const visibleMember =
      '4444444444444444444444444444444444444444444444444444444444444444';

  bool hiddenByDefault({
    required String senderPubkey,
    bool isGroup = true,
    bool everyMemberBlocked = false,
    Set<String> hidden = const {hiddenMember},
  }) => dmMessageHiddenByDefault(
    isGroup: isGroup,
    everyMemberBlocked: everyMemberBlocked,
    senderPubkey: senderPubkey,
    currentUserPubkey: viewer,
    isHidden: hidden.contains,
  );

  group('dmMessageHiddenByDefault', () {
    test("hides a hidden sender's message in a group", () {
      expect(hiddenByDefault(senderPubkey: hiddenMember), isTrue);
    });

    test('never hides a message in a one-to-one', () {
      expect(
        hiddenByDefault(senderPubkey: hiddenMember, isGroup: false),
        isFalse,
      );
    });

    test('never hides a message once every member is blocked', () {
      expect(
        hiddenByDefault(senderPubkey: hiddenMember, everyMemberBlocked: true),
        isFalse,
      );
    });

    test("never hides the viewer's own message", () {
      expect(
        hiddenByDefault(senderPubkey: viewer, hidden: const {viewer}),
        isFalse,
      );
    });

    test("never hides the viewer's own message when the key differs in "
        'case', () {
      final upperViewer = viewer.toUpperCase();

      expect(
        hiddenByDefault(senderPubkey: upperViewer, hidden: {upperViewer}),
        isFalse,
      );
    });

    test('does not hide a sender who is not hidden', () {
      expect(hiddenByDefault(senderPubkey: visibleMember), isFalse);
    });

    test('does not hide a message with no sender', () {
      expect(
        hiddenByDefault(senderPubkey: '', hidden: const {''}),
        isFalse,
      );
    });
  });

  group('dmPeersWithoutBlocked', () {
    const firstMember =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const lastMember =
        '5555555555555555555555555555555555555555555555555555555555555555';

    test('drops blocked members and sorts the rest', () {
      expect(
        dmPeersWithoutBlocked(
          participantPubkeys: const [
            lastMember,
            hiddenMember,
            visibleMember,
            firstMember,
          ],
          isBlockedByUs: const {hiddenMember}.contains,
        ),
        equals(const [firstMember, visibleMember, lastMember]),
      );
    });

    test('returns one member when one is left', () {
      expect(
        dmPeersWithoutBlocked(
          participantPubkeys: const [visibleMember, hiddenMember],
          isBlockedByUs: const {hiddenMember}.contains,
        ),
        equals(const [visibleMember]),
      );
    });
  });
}
