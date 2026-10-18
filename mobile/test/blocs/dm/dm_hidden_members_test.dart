// ABOUTME: Tests which group members the viewer's own lists hide: whose
// ABOUTME: messages and inbox previews collapse, and who is left for a chat
// ABOUTME: without them.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_hidden_members.dart';

class _MockDmRepository extends Mock implements DmRepository {}

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

  group('dmPreviewHidden', () {
    bool previewHidden({
      required String? lastSender,
      bool isGroup = true,
      bool everyMemberBlocked = false,
      Set<String> hidden = const {hiddenMember},
    }) => dmPreviewHidden(
      conversation: DmConversation(
        id: 'e' * 64,
        participantPubkeys: const [viewer, hiddenMember, visibleMember],
        isGroup: isGroup,
        createdAt: 1700000000,
        lastMessageContent: 'see you at 8',
        lastMessageSenderPubkey: lastSender,
      ),
      currentUserPubkey: viewer,
      everyMemberBlocked: everyMemberBlocked,
      isHidden: hidden.contains,
    );

    test("hides a hidden member's last message in a group", () {
      expect(previewHidden(lastSender: hiddenMember), isTrue);
    });

    test('never hides a one-to-one preview', () {
      expect(
        previewHidden(lastSender: hiddenMember, isGroup: false),
        isFalse,
      );
    });

    test('never hides the preview once every member is blocked', () {
      expect(
        previewHidden(lastSender: hiddenMember, everyMemberBlocked: true),
        isFalse,
      );
    });

    test("never hides the viewer's own last message", () {
      expect(
        previewHidden(lastSender: viewer, hidden: const {viewer}),
        isFalse,
      );
    });

    test("never hides the viewer's own last message when the key differs in "
        'case', () {
      final upperViewer = viewer.toUpperCase();

      expect(
        previewHidden(lastSender: upperViewer, hidden: {upperViewer}),
        isFalse,
      );
    });

    test('does not hide a member who is not hidden', () {
      expect(previewHidden(lastSender: visibleMember), isFalse);
    });

    test('does not hide a preview whose sender was never recorded', () {
      expect(previewHidden(lastSender: null), isFalse);
    });

    test('does not hide a preview with an empty sender', () {
      expect(previewHidden(lastSender: '', hidden: const {''}), isFalse);
    });
  });

  group('dmConversationsAsSeen', () {
    const roomId =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const directId =
        '2222222222222222222222222222222222222222222222222222222222222222';
    late _MockDmRepository dmRepository;

    setUpAll(() {
      registerFallbackValue(<String, Set<String>>{});
    });

    setUp(() {
      dmRepository = _MockDmRepository();
    });

    DmConversation room({
      String lastSender = hiddenMember,
      int timestamp = 1700000300,
      bool isRead = false,
    }) => DmConversation(
      id: roomId,
      participantPubkeys: const [viewer, hiddenMember, visibleMember],
      isGroup: true,
      createdAt: 1700000000,
      lastMessageContent: 'from $lastSender',
      lastMessageTimestamp: timestamp,
      lastMessageSenderPubkey: lastSender,
      isRead: isRead,
    );

    DmConversation direct({int timestamp = 1700000200}) => DmConversation(
      id: directId,
      participantPubkeys: const [viewer, hiddenMember],
      isGroup: false,
      createdAt: 1700000000,
      lastMessageContent: 'from the hidden peer',
      lastMessageTimestamp: timestamp,
      lastMessageSenderPubkey: hiddenMember,
      isRead: false,
    );

    void answer(DmVisibleActivity activity) {
      when(
        () => dmRepository.visibleActivityExcluding(any()),
      ).thenAnswer((_) async => {roomId: activity});
    }

    Future<List<DmConversation>> asSeen(
      List<DmConversation> conversations, {
      Set<String> hidden = const {hiddenMember},
      Set<String> blocked = const {hiddenMember},
    }) => dmConversationsAsSeen(
      conversations: conversations,
      currentUserPubkey: viewer,
      isHidden: hidden.contains,
      isBlockedByUs: blocked.contains,
      dmRepository: dmRepository,
    );

    test('returns the list as stored, asking nothing, when no row hides its '
        'last message', () async {
      final conversations = [
        direct(),
        room(lastSender: visibleMember),
        room(lastSender: viewer),
      ];

      final seen = await asSeen(conversations);

      expect(seen, same(conversations));
      verifyNever(() => dmRepository.visibleActivityExcluding(any()));
    });

    test('leaves a group where every member is blocked as stored', () async {
      final conversations = [room()];

      final seen = await asSeen(
        conversations,
        hidden: const {hiddenMember, visibleMember},
        blocked: const {hiddenMember, visibleMember},
      );

      expect(seen, same(conversations));
      verifyNever(() => dmRepository.visibleActivityExcluding(any()));
    });

    test(
      "reads a hidden member's group from its newest visible message",
      () async {
        answer((
          lastMessageContent: 'from the visible member',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: visibleMember,
          hasUnread: false,
        ));

        final seen = await asSeen([room()]);

        expect(
          seen.single,
          equals(
            room().copyWith(
              lastMessageContent: 'from the visible member',
              lastMessageTimestamp: 1700000100,
              lastMessageSenderPubkey: visibleMember,
              isRead: true,
            ),
          ),
        );
      },
    );

    test(
      "sets aside only that group's hidden members, never the viewer",
      () async {
        answer((
          lastMessageContent: null,
          lastMessageTimestamp: null,
          lastMessageSenderPubkey: null,
          hasUnread: false,
        ));

        await asSeen([room()], hidden: const {hiddenMember, viewer});

        final asked = verify(
          () => dmRepository.visibleActivityExcluding(captureAny()),
        ).captured.single;
        expect(
          asked,
          equals({
            roomId: {hiddenMember},
          }),
        );
      },
    );

    test('keeps a group unread when a visible member wrote after the read '
        'cursor', () async {
      answer((
        lastMessageContent: 'from the visible member',
        lastMessageTimestamp: 1700000100,
        lastMessageSenderPubkey: visibleMember,
        hasUnread: true,
      ));

      final seen = await asSeen([room()]);

      expect(seen.single.isRead, isFalse);
    });

    test('never turns a read group unread', () async {
      answer((
        lastMessageContent: 'from the visible member',
        lastMessageTimestamp: 1700000100,
        lastMessageSenderPubkey: visibleMember,
        hasUnread: true,
      ));

      final seen = await asSeen([room(isRead: true)]);

      expect(seen.single.isRead, isTrue);
    });

    test('keeps the stored, hidden preview of a group nobody visible wrote '
        'in, and reads it as read', () async {
      answer((
        lastMessageContent: null,
        lastMessageTimestamp: null,
        lastMessageSenderPubkey: null,
        hasUnread: false,
      ));

      final seen = await asSeen([room()]);

      expect(seen.single, equals(room().copyWith(isRead: true)));
    });

    test('sorts a read group by its newest visible message', () async {
      answer((
        lastMessageContent: 'from the visible member',
        lastMessageTimestamp: 1700000100,
        lastMessageSenderPubkey: visibleMember,
        hasUnread: false,
      ));

      final seen = await asSeen([room(), direct()]);

      expect(seen.map((c) => c.id), equals([directId, roomId]));
    });

    test('keeps the stored order between rows that tie', () async {
      answer((
        lastMessageContent: 'from the visible member',
        lastMessageTimestamp: 1700000100,
        lastMessageSenderPubkey: visibleMember,
        hasUnread: false,
      ));
      // Long enough that an unstable sort reorders equal rows.
      final tied = [
        for (var i = 0; i < 40; i++)
          direct().copyWith(id: i.toRadixString(16).padLeft(64, '0')),
      ];

      final seen = await asSeen([room(), ...tied]);

      expect(
        seen.map((c) => c.id),
        equals([...tied.map((c) => c.id), roomId]),
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

  group('dmEveryPeerBlocked', () {
    bool everyPeerBlocked(
      List<String> participants, {
      required bool Function(String pubkey) isBlockedByUs,
    }) => dmEveryPeerBlocked(
      participantPubkeys: participants,
      currentUserPubkey: viewer,
      isBlockedByUs: isBlockedByUs,
    );

    // A predicate that blocks everyone: only the missing peers can keep these
    // false, which is the vacuous `every` the helper guards against.
    test('is false for an empty participant list', () {
      expect(everyPeerBlocked(const [], isBlockedByUs: (_) => true), isFalse);
    });

    test('is false when the viewer is the only participant', () {
      expect(
        everyPeerBlocked(const [viewer], isBlockedByUs: (_) => true),
        isFalse,
      );
    });

    test('does not count the viewer in another letter case as a peer', () {
      expect(
        everyPeerBlocked(
          [viewer.toUpperCase(), hiddenMember],
          isBlockedByUs: const {hiddenMember}.contains,
        ),
        isTrue,
      );
    });

    test('is false when only some peers are blocked', () {
      expect(
        everyPeerBlocked(
          const [viewer, hiddenMember, visibleMember],
          isBlockedByUs: const {hiddenMember}.contains,
        ),
        isFalse,
      );
    });

    test('is true when every peer is blocked', () {
      expect(
        everyPeerBlocked(
          const [viewer, hiddenMember, visibleMember],
          isBlockedByUs: const {hiddenMember, visibleMember}.contains,
        ),
        isTrue,
      );
    });
  });
}
