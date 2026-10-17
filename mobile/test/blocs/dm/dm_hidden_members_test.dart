// ABOUTME: Tests which group messages the conversation collapses by default
// ABOUTME: because their sender is on the viewer's own block or mute list.

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
    Set<String> hidden = const {hiddenMember},
  }) => dmMessageHiddenByDefault(
    isGroup: isGroup,
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
}
