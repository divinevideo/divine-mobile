// ABOUTME: PROTOTYPE (#8076) — what a participant did during one session,
// ABOUTME: and the pure helpers that turn fixtures plus those actions into
// ABOUTME: rows. Flutter-free so it can be tested without pumping a screen.

import 'package:count_formatter/count_formatter.dart';
import 'package:models/models.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_fixtures.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_prototype_settings.dart';

/// Actions taken on requests during one session. Nothing is published.
class DmPrototypeSession {
  const DmPrototypeSession({
    this.revealed = const {},
    this.replied = const {},
    this.notSpam = const {},
    this.removed = const {},
    this.blocked = const {},
  });

  /// Conversation ids the user opened.
  final Set<String> revealed;

  /// Conversation ids the user sent a reply in.
  final Set<String> replied;

  /// Conversation ids the user marked as not spam.
  final Set<String> notSpam;

  /// Conversation ids deleted, or reported and removed.
  final Set<String> removed;

  /// Blocked sender pubkeys. Every conversation with them is hidden.
  final Set<String> blocked;

  DmPrototypeSession reveal(String id) => _copy(revealed: {...revealed, id});

  DmPrototypeSession reply(String id) => _copy(replied: {...replied, id});

  DmPrototypeSession markNotSpam(String id) => _copy(notSpam: {...notSpam, id});

  DmPrototypeSession remove(String id) => _copy(removed: {...removed, id});

  DmPrototypeSession block(String pubkey) =>
      _copy(blocked: {...blocked, pubkey});

  bool isRevealed(String id) => revealed.contains(id);

  /// [conversations] as this session sees them: removed and blocked rows
  /// dropped, sent replies counted as consent, opened rows counted as read.
  List<DmConversation> apply(List<DmConversation> conversations) => [
    for (final conversation in conversations)
      if (!removed.contains(conversation.id) &&
          !conversation.participantPubkeys.any(blocked.contains))
        conversation.copyWith(
          currentUserHasSent:
              conversation.currentUserHasSent ||
              replied.contains(conversation.id),
          isRead: conversation.isRead || revealed.contains(conversation.id),
        ),
  ];

  DmPrototypeSession _copy({
    Set<String>? revealed,
    Set<String>? replied,
    Set<String>? notSpam,
    Set<String>? removed,
    Set<String>? blocked,
  }) {
    return DmPrototypeSession(
      revealed: Set.unmodifiable(revealed ?? this.revealed),
      replied: Set.unmodifiable(replied ?? this.replied),
      notSpam: Set.unmodifiable(notSpam ?? this.notSpam),
      removed: Set.unmodifiable(removed ?? this.removed),
      blocked: Set.unmodifiable(blocked ?? this.blocked),
    );
  }
}

/// Classifies the fixtures as [session] has changed them.
DmInboxClassification classifyPrototype({
  required DmInboxFixtures fixtures,
  required DmPrototypeSettings settings,
  required DmPrototypeSession session,
}) {
  return DmInboxClassifier(
    officialIdentities: fixtures.officialIdentities,
    heuristics: settings.heuristics,
  ).classify(
    session.apply(fixtures.dmConversations),
    userPubkey: fixtures.userPubkey,
    isFollowing: fixtures.isFollowing,
    signalsFor: fixtures.signalsFor,
    messageSignalsFor: fixtures.messageSignalsFor,
    markedNotSpam: session.notSpam.contains,
  );
}

/// The one other participant of a one-to-one conversation, or null.
///
/// Sender context is shown for one-to-one requests only: in a group the
/// person whose counts are shown and the one who set the score can differ.
String? soleCounterparty(DmConversation conversation, String userPubkey) {
  final others = conversation.participantPubkeys
      .where((pubkey) => pubkey != userPubkey)
      .toSet();
  return others.length == 1 ? others.single : null;
}

/// Factual sender context, in display order: videos, then a mutual
/// connection, then loops.
///
/// Unknown values are left out rather than shown as zero. A known zero of
/// loops is left out too, as the profile header does for other people.
List<String> senderContextParts(
  DmSenderSignals signals, {
  required bool showLoops,
  String? mutualName,
}) {
  return [
    ?_videosPart(signals.divineVideoCount),
    ?_mutualPart(signals.mutualConnectionCount, mutualName),
    if (showLoops) ?_loopsPart(signals.totalLoopCount),
  ];
}

String? _videosPart(int? count) => switch (count) {
  null => null,
  0 => 'No videos yet',
  1 => '1 video',
  final n => '${CountFormatter.formatCompact(n)} videos',
};

String? _mutualPart(int? count, String? name) => switch ((count, name)) {
  (null, _) => null,
  (0, _) => 'No mutual connections',
  (1, final String name) => 'Followed by $name',
  (2, final String name) => 'Followed by $name and 1 other',
  (final int n, final String name) => 'Followed by $name and ${n - 1} others',
  (1, null) => '1 mutual connection',
  (final int n, null) => '$n mutual connections',
};

String? _loopsPart(int? count) => switch (count) {
  null || 0 => null,
  1 => '1 loop',
  final n => '${CountFormatter.formatCompact(n)} loops',
};

/// The reasons a row may show.
///
/// Reasons about the hidden message, such as containing a link, are held
/// back until the request is opened, unless [includeMessageReasons].
List<DmRiskReason> visibleReasons(
  DmVerdict verdict, {
  required bool includeMessageReasons,
}) => [
  for (final reason in verdict.reasons)
    if (includeMessageReasons || !reason.aboutMessage) reason,
];

/// The single strongest risk reason, for a one-line caution, or null when
/// nothing raised the risk.
DmRiskReason? cautionReason(
  DmVerdict verdict, {
  required bool includeMessageReasons,
}) {
  DmRiskReason? strongest;
  for (final reason in visibleReasons(
    verdict,
    includeMessageReasons: includeMessageReasons,
  )) {
    if (reason.points > 0 &&
        (strongest == null || reason.points > strongest.points)) {
      strongest = reason;
    }
  }
  return strongest;
}
