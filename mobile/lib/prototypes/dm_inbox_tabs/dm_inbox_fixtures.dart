// ABOUTME: PROTOTYPE (#8076) — fixture conversations for the four-tab inbox.
// ABOUTME: Deliberately synthetic: no real pubkeys, no real message text, and
// ABOUTME: nothing derived from a reporter's account. Spans the corners of the
// ABOUTME: classifier so tuning the weights visibly moves rows between tabs.

import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';

/// A fixture sender: display identity plus the signals Divine would know.
class FixtureSender {
  const FixtureSender({
    required this.pubkey,
    required this.displayName,
    required this.signals,
  });

  final String pubkey;
  final String displayName;
  final DmSenderSignals signals;
}

/// One fixture row: the conversation, its participants, and its message hints.
class FixtureConversation {
  const FixtureConversation({
    required this.conversation,
    required this.messageSignals,
  });

  final DmConversation conversation;
  final DmMessageSignals messageSignals;
}

/// Everything the prototype screen needs to render and classify.
class DmInboxFixtures {
  const DmInboxFixtures({
    required this.userPubkey,
    required this.officialIdentities,
    required this.senders,
    required this.conversations,
    required this.following,
    required this.now,
  });

  /// The instant the fixtures are anchored to, so relative timestamps read
  /// the same on every launch.
  final DateTime now;

  final String userPubkey;
  final Map<String, DivineOfficialIdentity> officialIdentities;
  final Map<String, FixtureSender> senders;
  final List<FixtureConversation> conversations;
  final Set<String> following;

  List<DmConversation> get dmConversations =>
      conversations.map((f) => f.conversation).toList();

  bool isFollowing(String pubkey) => following.contains(pubkey);

  DmSenderSignals signalsFor(String pubkey) =>
      senders[pubkey]?.signals ?? DmSenderSignals.unknown;

  String displayNameFor(String pubkey) =>
      senders[pubkey]?.displayName ?? 'Unknown sender';

  DmMessageSignals messageSignalsFor(DmConversation conversation) {
    for (final fixture in conversations) {
      if (fixture.conversation.id == conversation.id) {
        return fixture.messageSignals;
      }
    }
    return DmMessageSignals.none;
  }

  /// Name shown on a row: the counterparty, or "A and N others" for a group.
  String titleFor(DmConversation conversation) {
    final others = conversation.participantPubkeys
        .where((pk) => pk != userPubkey)
        .toList();
    if (others.isEmpty) return 'Unknown sender';
    if (others.length == 1) return displayNameFor(others.first);
    return '${displayNameFor(others.first)} and ${others.length - 1} others';
  }

  static DmInboxFixtures build() => _build();
}

// Synthetic 64-char hex. `_pk('a1')` -> 'a1' repeated to full length, so the
// values look like pubkeys without resembling anyone's real key.
String _pk(String seed) {
  final buffer = StringBuffer();
  while (buffer.length < 64) {
    buffer.write(seed);
  }
  return buffer.toString().substring(0, 64);
}

const _hqPubkey = 'divinehq';
const _supportPubkey = 'divinesupport';
const _trustSafetyPubkey = 'divinetrustsafety';
const _moderationPubkey = 'divinemoderation';
const _lizTeamPubkey = 'lizteam';
const _rabbleTeamPubkey = 'rabbleteam';

int _hoursAgo(int hours) =>
    _now.subtract(Duration(hours: hours)).millisecondsSinceEpoch ~/ 1000;

// Fixed so the prototype renders identically on every launch.
final _now = DateTime(2026, 8, 22, 14);

DmInboxFixtures _build() {
  final senders = <String, FixtureSender>{};
  void sender(String seed, String name, DmSenderSignals signals) {
    final pubkey = _pk(seed);
    senders[pubkey] = FixtureSender(
      pubkey: pubkey,
      displayName: name,
      signals: signals,
    );
  }

  // Official senders never reach the scorer, so their signals are unused.
  sender(_hqPubkey, 'DivineHQ', DmSenderSignals.unknown);
  sender(_supportPubkey, 'Divine Support', DmSenderSignals.unknown);
  sender(_trustSafetyPubkey, 'Divine Trust & Safety', DmSenderSignals.unknown);
  sender(_moderationPubkey, 'Divine Moderation', DmSenderSignals.unknown);
  sender(_lizTeamPubkey, 'Liz · Divine team', DmSenderSignals.unknown);
  sender(_rabbleTeamPubkey, 'Rabble · Divine team', DmSenderSignals.unknown);

  // --- Known, trusted people ---------------------------------------------
  sender(
    'a1',
    'Maya Okonkwo',
    const DmSenderSignals(
      followsMe: true,
      mutualConnectionCount: 12,
      divineVideoCount: 48,
      daysSinceFirstObserved: 400,
      hasProfileMetadata: true,
      hasPriorPublicInteraction: true,
    ),
  );
  sender(
    'b2',
    'Deshawn Pierce',
    const DmSenderSignals(
      followsMe: true,
      mutualConnectionCount: 5,
      divineVideoCount: 9,
      daysSinceFirstObserved: 260,
      hasProfileMetadata: true,
    ),
  );
  sender(
    'c3',
    'Rin Takahashi',
    const DmSenderSignals(
      followsMe: true,
      mutualConnectionCount: 8,
      divineVideoCount: 130,
      daysSinceFirstObserved: 520,
      hasProfileMetadata: true,
      hasPriorPublicInteraction: true,
    ),
  );

  // --- Plausible first contact (should read as a genuine request) ---------
  sender(
    'd4',
    'Priya Raman',
    const DmSenderSignals(
      mutualConnectionCount: 4,
      divineVideoCount: 22,
      daysSinceFirstObserved: 300,
      hasProfileMetadata: true,
    ),
  );
  sender(
    'e5',
    'Tobias Lund',
    const DmSenderSignals(
      followsMe: true,
      mutualConnectionCount: 1,
      divineVideoCount: 3,
      daysSinceFirstObserved: 95,
      hasProfileMetadata: true,
    ),
  );
  sender(
    'f6',
    'Nadia Broussard',
    const DmSenderSignals(
      mutualConnectionCount: 2,
      divineVideoCount: 1,
      daysSinceFirstObserved: 45,
      hasProfileMetadata: true,
      hasPriorPublicInteraction: true,
    ),
  );

  // --- The borderline cases the sliders should move ----------------------
  // Real creator, brand-new account, no mutuals. Genuine or not depending on
  // where the new-account weight sits.
  sender(
    '07',
    'Jules Amari',
    const DmSenderSignals(
      divineVideoCount: 2,
      daysSinceFirstObserved: 3,
      hasProfileMetadata: true,
      mutualConnectionCount: 1,
    ),
  );
  // Established lurker who has never posted. Punished hard by the
  // "has not posted on Divine" weight — the false-positive to watch.
  sender(
    '18',
    'Hollis Wray',
    const DmSenderSignals(
      daysSinceFirstObserved: 610,
      hasProfileMetadata: true,
      mutualConnectionCount: 2,
    ),
  );
  // Fan with a link in the first message. Link weight decides the tab.
  sender(
    '29',
    'Camille Ndiaye',
    const DmSenderSignals(
      divineVideoCount: 6,
      daysSinceFirstObserved: 140,
      hasProfileMetadata: true,
      followsMe: true,
    ),
  );

  // --- Unambiguous spam ---------------------------------------------------
  sender(
    '3a',
    'crypto_signals_daily',
    const DmSenderSignals(
      daysSinceFirstObserved: 1,
      recentFirstContactCount: 240,
      distinctReporterCount: 31,
    ),
  );
  sender(
    '4b',
    'FREE V-BUCKS GIVEAWAY',
    const DmSenderSignals(
      daysSinceFirstObserved: 0,
      recentFirstContactCount: 88,
      distinctReporterCount: 12,
    ),
  );
  sender(
    '5c',
    'noname',
    const DmSenderSignals(
      daysSinceFirstObserved: 2,
      recentFirstContactCount: 41,
    ),
  );
  // The one that matters most for T&S: harassment, not commerce. Low fan-out,
  // no links — only "new account + no history + no mutuals" flags it.
  sender(
    '6d',
    'youcanthide',
    const DmSenderSignals(daysSinceFirstObserved: 0),
  );

  // --- Group participants -------------------------------------------------
  sender(
    '7e',
    'Sofia Marchetti',
    const DmSenderSignals(
      followsMe: true,
      mutualConnectionCount: 6,
      divineVideoCount: 15,
      daysSinceFirstObserved: 310,
      hasProfileMetadata: true,
    ),
  );
  sender(
    '8f',
    'dropship_deals',
    const DmSenderSignals(
      daysSinceFirstObserved: 4,
      recentFirstContactCount: 65,
      distinctReporterCount: 7,
    ),
  );

  final user = _pk('9a');
  final following = <String>{_pk('a1'), _pk('b2'), _pk('c3'), _pk('7e')};

  var counter = 0;
  FixtureConversation conversation({
    required List<String> otherSeeds,
    required String preview,
    required int hoursAgo,
    bool currentUserHasSent = false,
    bool isRead = true,
    bool containsLink = false,
    bool containsMedia = false,
    String? subject,
  }) {
    counter++;
    final others = otherSeeds.map(_pk).toList();
    return FixtureConversation(
      conversation: DmConversation(
        id: 'fixture-${counter.toString().padLeft(2, '0')}',
        participantPubkeys: [user, ...others]..sort(),
        isGroup: others.length > 1,
        createdAt: _hoursAgo(hoursAgo + 24),
        lastMessageContent: preview,
        lastMessageTimestamp: _hoursAgo(hoursAgo),
        lastMessageSenderPubkey: others.first,
        subject: subject,
        isRead: isRead,
        currentUserHasSent: currentUserHasSent,
        dmProtocol: 'nip17',
      ),
      messageSignals: DmMessageSignals(
        containsLink: containsLink,
        containsMedia: containsMedia,
      ),
    );
  }

  final conversations = <FixtureConversation>[
    // Official — must never be routed to requests, whatever the weights say.
    conversation(
      otherSeeds: [_supportPubkey],
      preview:
          'We reviewed the report you filed on 19 August. Here is what '
          'we found and what happens next.',
      hoursAgo: 2,
      isRead: false,
    ),
    conversation(
      otherSeeds: [_hqPubkey],
      preview:
          'Your account was selected for the creator fund pilot. No '
          'action needed — details inside.',
      hoursAgo: 40,
    ),
    conversation(
      otherSeeds: [_trustSafetyPubkey],
      preview: 'A private safety update is ready for you.',
      hoursAgo: 18,
      isRead: false,
    ),
    conversation(
      otherSeeds: [_moderationPubkey],
      preview: 'We have an update about content you reported.',
      hoursAgo: 54,
    ),
    conversation(
      otherSeeds: [_lizTeamPubkey],
      preview: 'Would love your thoughts on the new creator tools.',
      hoursAgo: 10,
    ),
    conversation(
      otherSeeds: [_rabbleTeamPubkey],
      preview: 'Thanks for helping us make Divine weirder and safer.',
      hoursAgo: 70,
    ),

    // Inbox — replied to, or everyone followed.
    conversation(
      otherSeeds: ['a1'],
      preview: 'ok but the timing on the second loop is unhinged, i love it',
      hoursAgo: 1,
      currentUserHasSent: true,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['b2'],
      preview: 'sending you the audio tomorrow',
      hoursAgo: 6,
      currentUserHasSent: true,
    ),
    conversation(
      otherSeeds: ['c3'],
      preview: 'did you see what they did with the transition',
      hoursAgo: 20,
      currentUserHasSent: true,
    ),
    // Followed, never replied to — inbox, not a request.
    conversation(
      otherSeeds: ['7e'],
      preview: 'hey! following up about the collab',
      hoursAgo: 9,
      isRead: false,
    ),
    // All-followed group.
    conversation(
      otherSeeds: ['a1', 'c3', '7e'],
      preview: 'friday edit jam?',
      hoursAgo: 30,
      subject: 'edit jam',
      currentUserHasSent: true,
    ),

    // Requests — genuine first contact.
    conversation(
      otherSeeds: ['d4'],
      preview:
          'Hi! We met at the meetup in Lisbon — are you still doing the '
          'stop-motion series?',
      hoursAgo: 3,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['e5'],
      preview: 'love your work, quick question about your setup',
      hoursAgo: 12,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['f6'],
      preview:
          'you commented on my loop last week, thank you!! wanted to say '
          'hi properly',
      hoursAgo: 26,
    ),

    // Borderline — these are the rows the sliders should move.
    conversation(
      otherSeeds: ['07'],
      preview: 'just joined, your stuff is why. any advice for a beginner?',
      hoursAgo: 5,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['18'],
      preview: 'been watching since the vine days. glad you are back.',
      hoursAgo: 33,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['29'],
      preview: 'made a fan edit of your series, here it is',
      hoursAgo: 15,
      containsLink: true,
      isRead: false,
    ),

    // Likely spam.
    conversation(
      otherSeeds: ['3a'],
      preview:
          '🚀 100X GAINS GUARANTEED — join the private channel before it '
          'closes',
      hoursAgo: 1,
      containsLink: true,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['4b'],
      preview: 'CONGRATULATIONS you have been selected click here to claim',
      hoursAgo: 4,
      containsLink: true,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['5c'],
      preview: 'hi dear',
      hoursAgo: 7,
      containsMedia: true,
      isRead: false,
    ),
    conversation(
      otherSeeds: ['6d'],
      preview: 'i know where you posted from',
      hoursAgo: 2,
      isRead: false,
    ),
    // Mixed group: one followed friend, one spammer. Must not reach the inbox
    // on the strength of the friend alone.
    conversation(
      otherSeeds: ['7e', '8f'],
      preview: 'added you both, check the link',
      hoursAgo: 8,
      containsLink: true,
      isRead: false,
    ),
  ];

  return DmInboxFixtures(
    now: _now,
    userPubkey: user,
    officialIdentities: {
      _pk(_hqPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.operationalAccount,
        label: 'Official account',
      ),
      _pk(_supportPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.operationalAccount,
        label: 'Official account',
      ),
      _pk(_trustSafetyPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.operationalAccount,
        label: 'Official account',
      ),
      _pk(_moderationPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.operationalAccount,
        label: 'Official account',
      ),
      _pk(_lizTeamPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.teamMember,
        label: 'Divine team',
      ),
      _pk(_rabbleTeamPubkey): const DivineOfficialIdentity(
        kind: DivineIdentityKind.teamMember,
        label: 'Divine team',
      ),
    },
    senders: senders,
    conversations: conversations,
    following: following,
  );
}
