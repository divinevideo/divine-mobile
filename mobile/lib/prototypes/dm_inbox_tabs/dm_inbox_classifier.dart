// ABOUTME: PROTOTYPE (#8076) — pure four-way DM inbox classifier.
// ABOUTME: Generalizes DmRepository.classifyPotentialRequests from two buckets
// ABOUTME: (followed/requests) to four (official/inbox/requests/likelySpam),
// ABOUTME: and returns a human-readable reason trail for every verdict.
//
// Deliberately Flutter-free and dependency-free beyond `models` and `meta`,
// so it can move into `packages/dm_repository` if the shape survives the
// product discussion. Moving it means adopting that package's self filter
// first: `classifyPotentialRequests` drops the viewer with the
// case-insensitive `pubkeysEqual` and hides self-only rows, where this uses
// an exact `!=` and sends them to requests (#5374).

import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Why a sender is allowed into the cryptographically trusted Official tab.
enum DivineIdentityKind { operationalAccount, teamMember }

/// A signed-registry identity and the capabilities attached to that role.
class DivineOfficialIdentity {
  const DivineOfficialIdentity({required this.kind, required this.label});

  final DivineIdentityKind kind;
  final String label;

  bool get isBlockable => kind == DivineIdentityKind.teamMember;
}

/// Where a conversation lands in the four-tab inbox.
enum DmInboxBucket {
  /// Authenticated DivineHQ / Divine Support / Trust & Safety.
  ///
  /// Never routed to requests or hidden by a privacy setting. Always
  /// reportable. Blocking targets individual team members only.
  official,

  /// Conversations the user has consented to: they replied, or they follow
  /// every other participant.
  inbox,

  /// First contact from someone the user does not follow. Content stays
  /// concealed until the user affirmatively opens the request.
  requests,

  /// A request carrying enough independent risk signals to collapse it out
  /// of the main request stream. Concealed, never auto-deleted.
  likelySpam,
}

/// What Divine knows about a sender at classification time.
///
/// Every field is a *local or already-synced* fact. Nothing here requires
/// decrypting message content server-side, and nothing here depends on the
/// sender using Keycast or having an email on file — those must never affect
/// spam classification.
///
/// A null count or flag means Divine does not know it. Unknown is scored as
/// neutral, never as zero: missing data is not evidence against a sender.
class DmSenderSignals {
  const DmSenderSignals({
    this.followsMe = false,
    this.mutualConnectionCount,
    this.divineVideoCount,
    this.totalLoopCount,
    this.daysSinceFirstObserved,
    this.hasProfileMetadata,
    this.distinctReporterCount = 0,
    this.recentFirstContactCount = 0,
    this.hasPriorPublicInteraction = false,
  });

  /// No usable information about this sender.
  static const unknown = DmSenderSignals();

  /// The sender follows the current user.
  final bool followsMe;

  /// How many accounts the current user follows also follow this sender.
  final int? mutualConnectionCount;

  /// Videos this sender has published on Divine.
  final int? divineVideoCount;

  /// Lifetime loops across this sender's videos, the profile header's total.
  ///
  /// Shown as context only; it does not affect the score.
  final int? totalLoopCount;

  /// Days since Divine first observed any signed event from this sender.
  ///
  /// Null when unknown. There is no authoritative npub creation date, so this
  /// is explicitly "first observed", not "account age".
  final int? daysSinceFirstObserved;

  /// Sender has both a display name and an avatar.
  final bool? hasProfileMetadata;

  /// Distinct accounts that have reported this sender.
  final int distinctReporterCount;

  /// First-contact conversations this sender opened in the recent window.
  final int recentFirstContactCount;

  /// The two accounts have interacted publicly before (like, comment, repost).
  final bool hasPriorPublicInteraction;
}

/// Per-conversation facts that do not live on [DmConversation] itself.
class DmMessageSignals {
  const DmMessageSignals({
    this.containsLink = false,
    this.containsMedia = false,
  });

  static const none = DmMessageSignals();

  /// The first-contact message contains a URL.
  final bool containsLink;

  /// The first-contact message carries an attachment or media.
  final bool containsMedia;
}

/// One scored signal that fired, with the copy a user would see.
class DmRiskReason {
  const DmRiskReason(this.label, this.points, {this.aboutMessage = false});

  /// User-facing phrasing. Deliberately non-specific about thresholds so the
  /// panel does not double as an evasion recipe.
  final String label;

  /// Contribution to the risk score. Negative values are mitigating.
  final int points;

  /// The reason describes the hidden message itself, such as containing a
  /// link, so it must not be shown until the user opens the request.
  final bool aboutMessage;

  bool get isMitigating => points < 0;
}

/// Why one conversation landed where it did.
class DmVerdict {
  const DmVerdict({
    required this.bucket,
    required this.score,
    required this.reasons,
    this.officialParticipants = const {},
  });

  final DmInboxBucket bucket;

  /// Total risk score. Only meaningful for [DmInboxBucket.requests] and
  /// [DmInboxBucket.likelySpam]; the other two short-circuit before scoring.
  final int score;

  final List<DmRiskReason> reasons;

  /// Authenticated counterparties, populated only for an all-official room.
  final Map<String, DivineOfficialIdentity> officialParticipants;
}

/// Tunable weights and thresholds.
///
/// Every value here is a product decision, not an engineering one. They are
/// a config object so Trust & Safety could own them; in the prototype they
/// are const defaults that only the tuning panel changes.
@immutable
class DmSpamHeuristics {
  const DmSpamHeuristics({
    this.spamThreshold = 50,
    this.newAccountDays = 7,
    this.establishedAccountDays = 180,
    this.fanOutThreshold = 20,
    this.reporterThreshold = 3,
    this.mutualConnectionCap = 3,
    this.weightNoDivineVideos = 20,
    this.weightNewAccount = 25,
    this.weightNoProfileMetadata = 15,
    this.weightNoMutualConnections = 15,
    this.weightContainsLink = 25,
    this.weightContainsMedia = 10,
    this.weightHighFanOut = 40,
    this.weightReportedByOthers = 50,
    this.weightUnknownGroupInvite = 20,
    this.weightFollowsMe = -25,
    this.weightPerMutualConnection = -10,
    this.weightEstablishedAccount = -15,
    this.weightHasDivineVideos = -15,
    this.weightPriorPublicInteraction = -30,
  }) : assert(
         newAccountDays < establishedAccountDays,
         'an age cannot count as both new and established',
       ),
       assert(fanOutThreshold >= 1, 'zero fan-out would flag everyone'),
       assert(reporterThreshold >= 1, 'zero reporters would flag everyone'),
       assert(mutualConnectionCap >= 1, 'a cap of zero credits no one');

  /// Score at or above which a request collapses into Likely spam.
  final int spamThreshold;

  /// Below this many days since first observed counts as a new account.
  final int newAccountDays;

  /// Above this many days since first observed counts as established.
  final int establishedAccountDays;

  /// First-contact conversations in the window that count as high fan-out.
  final int fanOutThreshold;

  /// Distinct reporters that count as a reported sender.
  final int reporterThreshold;

  /// Mutual connections beyond this stop earning credit.
  final int mutualConnectionCap;

  final int weightNoDivineVideos;
  final int weightNewAccount;
  final int weightNoProfileMetadata;
  final int weightNoMutualConnections;
  final int weightContainsLink;
  final int weightContainsMedia;
  final int weightHighFanOut;
  final int weightReportedByOthers;
  final int weightUnknownGroupInvite;
  final int weightFollowsMe;
  final int weightPerMutualConnection;
  final int weightEstablishedAccount;
  final int weightHasDivineVideos;
  final int weightPriorPublicInteraction;

  DmSpamHeuristics copyWith({
    int? spamThreshold,
    int? newAccountDays,
    int? establishedAccountDays,
    int? fanOutThreshold,
    int? reporterThreshold,
    int? mutualConnectionCap,
    int? weightNoDivineVideos,
    int? weightNewAccount,
    int? weightNoProfileMetadata,
    int? weightNoMutualConnections,
    int? weightContainsLink,
    int? weightContainsMedia,
    int? weightHighFanOut,
    int? weightReportedByOthers,
    int? weightUnknownGroupInvite,
    int? weightFollowsMe,
    int? weightPerMutualConnection,
    int? weightEstablishedAccount,
    int? weightHasDivineVideos,
    int? weightPriorPublicInteraction,
  }) {
    return DmSpamHeuristics(
      spamThreshold: spamThreshold ?? this.spamThreshold,
      newAccountDays: newAccountDays ?? this.newAccountDays,
      establishedAccountDays:
          establishedAccountDays ?? this.establishedAccountDays,
      fanOutThreshold: fanOutThreshold ?? this.fanOutThreshold,
      reporterThreshold: reporterThreshold ?? this.reporterThreshold,
      mutualConnectionCap: mutualConnectionCap ?? this.mutualConnectionCap,
      weightNoDivineVideos: weightNoDivineVideos ?? this.weightNoDivineVideos,
      weightNewAccount: weightNewAccount ?? this.weightNewAccount,
      weightNoProfileMetadata:
          weightNoProfileMetadata ?? this.weightNoProfileMetadata,
      weightNoMutualConnections:
          weightNoMutualConnections ?? this.weightNoMutualConnections,
      weightContainsLink: weightContainsLink ?? this.weightContainsLink,
      weightContainsMedia: weightContainsMedia ?? this.weightContainsMedia,
      weightHighFanOut: weightHighFanOut ?? this.weightHighFanOut,
      weightReportedByOthers:
          weightReportedByOthers ?? this.weightReportedByOthers,
      weightUnknownGroupInvite:
          weightUnknownGroupInvite ?? this.weightUnknownGroupInvite,
      weightFollowsMe: weightFollowsMe ?? this.weightFollowsMe,
      weightPerMutualConnection:
          weightPerMutualConnection ?? this.weightPerMutualConnection,
      weightEstablishedAccount:
          weightEstablishedAccount ?? this.weightEstablishedAccount,
      weightHasDivineVideos:
          weightHasDivineVideos ?? this.weightHasDivineVideos,
      weightPriorPublicInteraction:
          weightPriorPublicInteraction ?? this.weightPriorPublicInteraction,
    );
  }

  /// Every field, in declaration order. A new field must be added here too,
  /// or two configs that differ only in it compare equal.
  List<int> get _values => [
    spamThreshold,
    newAccountDays,
    establishedAccountDays,
    fanOutThreshold,
    reporterThreshold,
    mutualConnectionCap,
    weightNoDivineVideos,
    weightNewAccount,
    weightNoProfileMetadata,
    weightNoMutualConnections,
    weightContainsLink,
    weightContainsMedia,
    weightHighFanOut,
    weightReportedByOthers,
    weightUnknownGroupInvite,
    weightFollowsMe,
    weightPerMutualConnection,
    weightEstablishedAccount,
    weightHasDivineVideos,
    weightPriorPublicInteraction,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! DmSpamHeuristics) return false;
    final mine = _values;
    final theirs = other._values;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);
}

/// Result of classifying a whole list.
class DmInboxClassification {
  const DmInboxClassification({
    required this.official,
    required this.inbox,
    required this.requests,
    required this.likelySpam,
    required this.verdicts,
  });

  final List<DmConversation> official;
  final List<DmConversation> inbox;
  final List<DmConversation> requests;
  final List<DmConversation> likelySpam;

  /// Conversation id to the reason trail behind its placement.
  final Map<String, DmVerdict> verdicts;

  List<DmConversation> bucket(DmInboxBucket bucket) => switch (bucket) {
    DmInboxBucket.official => official,
    DmInboxBucket.inbox => inbox,
    DmInboxBucket.requests => requests,
    DmInboxBucket.likelySpam => likelySpam,
  };
}

/// Four-way inbox classifier.
///
/// Ordering is deliberate and each step is a hard short-circuit:
///
/// 1. **Official** — every non-self participant is a canonical official pubkey.
///    At least one counterparty is required. Official rooms bypass
///    scoring. Mixed rooms follow the ordinary consent and relationship rules;
///    one official participant never grants trust to the whole room.
/// 2. **Inbox (consented)** — the user has replied, so consent is established.
/// 3. **Inbox (followed)** — every deduplicated non-self participant is
///    followed. `every`, not `first`, so a stranger p-tagged into a group
///    still lands in requests.
/// 4. **Scored** — everything else is a request; risk score decides whether it
///    collapses into Likely spam.
///
/// Official identity comes only from [officialIdentities]. Production must
/// supply it from a signed, release-controlled registry of full pubkeys and
/// role capabilities; the prototype passes synthetic fixtures. Never
/// from display name, profile metadata, badges, or follow state — all of which
/// an impersonator controls.
class DmInboxClassifier {
  const DmInboxClassifier({
    required this.officialIdentities,
    this.heuristics = const DmSpamHeuristics(),
  });

  final Map<String, DivineOfficialIdentity> officialIdentities;
  final DmSpamHeuristics heuristics;

  DmInboxClassification classify(
    List<DmConversation> conversations, {
    required String userPubkey,
    required bool Function(String pubkey) isFollowing,
    required DmSenderSignals Function(String pubkey) signalsFor,
    DmMessageSignals Function(DmConversation conversation)? messageSignalsFor,
    bool Function(String conversationId)? markedNotSpam,
  }) {
    final official = <DmConversation>[];
    final inbox = <DmConversation>[];
    final requests = <DmConversation>[];
    final likelySpam = <DmConversation>[];
    final verdicts = <String, DmVerdict>{};

    for (final conversation in conversations) {
      final others = conversation.participantPubkeys
          .where((pk) => pk != userPubkey)
          .toSet();

      var verdict = _classifyOne(
        conversation,
        others: others,
        isFollowing: isFollowing,
        signalsFor: signalsFor,
        messageSignals:
            messageSignalsFor?.call(conversation) ?? DmMessageSignals.none,
      );
      // The user's own call outranks the score, whatever the weights become.
      // It returns the row to Requests only; it is not consent.
      if (verdict.bucket == DmInboxBucket.likelySpam &&
          (markedNotSpam?.call(conversation.id) ?? false)) {
        verdict = DmVerdict(
          bucket: DmInboxBucket.requests,
          score: verdict.score,
          reasons: [
            ...verdict.reasons,
            const DmRiskReason('You marked this as not spam', 0),
          ],
        );
      }

      verdicts[conversation.id] = verdict;
      switch (verdict.bucket) {
        case DmInboxBucket.official:
          official.add(conversation);
        case DmInboxBucket.inbox:
          inbox.add(conversation);
        case DmInboxBucket.requests:
          requests.add(conversation);
        case DmInboxBucket.likelySpam:
          likelySpam.add(conversation);
      }
    }

    return DmInboxClassification(
      official: official,
      inbox: inbox,
      requests: requests,
      likelySpam: likelySpam,
      verdicts: verdicts,
    );
  }

  DmVerdict _classifyOne(
    DmConversation conversation, {
    required Set<String> others,
    required bool Function(String) isFollowing,
    required DmSenderSignals Function(String) signalsFor,
    required DmMessageSignals messageSignals,
  }) {
    if (others.isNotEmpty && others.every(officialIdentities.containsKey)) {
      return DmVerdict(
        bucket: DmInboxBucket.official,
        score: 0,
        reasons: const [
          DmRiskReason(
            'Every other participant is an official Divine identity',
            0,
          ),
        ],
        officialParticipants: Map.unmodifiable({
          for (final pubkey in others) pubkey: officialIdentities[pubkey],
        }),
      );
    }

    if (conversation.currentUserHasSent) {
      return const DmVerdict(
        bucket: DmInboxBucket.inbox,
        score: 0,
        reasons: [DmRiskReason('You replied to this conversation', 0)],
      );
    }

    // A degenerate row with no counterparty cannot be shown to be safe, so it
    // fails closed into requests rather than the inbox.
    if (others.isNotEmpty && others.every(isFollowing)) {
      return const DmVerdict(
        bucket: DmInboxBucket.inbox,
        score: 0,
        reasons: [DmRiskReason('You follow everyone in this conversation', 0)],
      );
    }

    final reasons = _score(
      others: others,
      isFollowing: isFollowing,
      signalsFor: signalsFor,
      messageSignals: messageSignals,
    );
    final score = reasons.fold(0, (sum, reason) => sum + reason.points);

    return DmVerdict(
      bucket: score >= heuristics.spamThreshold
          ? DmInboxBucket.likelySpam
          : DmInboxBucket.requests,
      score: score,
      reasons: reasons,
    );
  }

  List<DmRiskReason> _score({
    required Set<String> others,
    required bool Function(String) isFollowing,
    required DmSenderSignals Function(String) signalsFor,
    required DmMessageSignals messageSignals,
  }) {
    final h = heuristics;

    final unknown = others.where((pk) => !isFollowing(pk)).toList();
    if (unknown.isEmpty) {
      return const [];
    }

    // A group is only as safe as its least-known member: score each
    // unfollowed member with the verdict's own weights and keep the worst,
    // so the room inherits that member's score and reasons.
    var reasons = _scoreSender(unknown.first, signalsFor, messageSignals);
    var worst = reasons.fold(0, (sum, reason) => sum + reason.points);
    for (final pubkey in unknown.skip(1)) {
      final candidate = _scoreSender(pubkey, signalsFor, messageSignals);
      final total = candidate.fold(0, (sum, reason) => sum + reason.points);
      if (total > worst) {
        reasons = candidate;
        worst = total;
      }
    }

    void add(String label, int points) {
      if (points != 0) {
        reasons.add(DmRiskReason(label, points));
      }
    }

    // Counted from the deduplicated participants, never from the drifting
    // `DmConversation.isGroup` column (#5374). A followed member does not
    // make a stranger's group invite any less of one.
    if (others.length > 1) {
      add('Added you to a group', h.weightUnknownGroupInvite);
    }

    return reasons;
  }

  /// Scores one unfollowed participant. The conversation-wide group weight is
  /// added by [_score] once, not per sender.
  List<DmRiskReason> _scoreSender(
    String pubkey,
    DmSenderSignals Function(String) signalsFor,
    DmMessageSignals messageSignals,
  ) {
    final h = heuristics;
    final signals = signalsFor(pubkey);
    final reasons = <DmRiskReason>[];

    void add(String label, int points, {bool aboutMessage = false}) {
      if (points != 0) {
        reasons.add(DmRiskReason(label, points, aboutMessage: aboutMessage));
      }
    }

    if (signals.distinctReporterCount >= h.reporterThreshold) {
      add('Reported by other people', h.weightReportedByOthers);
    }
    if (signals.recentFirstContactCount >= h.fanOutThreshold) {
      add('Messaged many new people recently', h.weightHighFanOut);
    }

    final days = signals.daysSinceFirstObserved;
    if (days != null && days < h.newAccountDays) {
      // "First seen", not "new account": Divine only knows when it first
      // observed the key, not when the account was created.
      add('First seen recently', h.weightNewAccount);
    } else if (days != null && days > h.establishedAccountDays) {
      add('Seen on Divine for a long time', h.weightEstablishedAccount);
    }

    switch (signals.divineVideoCount) {
      case null:
        break;
      case 0:
        add('Has not posted on Divine', h.weightNoDivineVideos);
      default:
        add('Posts on Divine', h.weightHasDivineVideos);
    }

    if (signals.hasProfileMetadata == false) {
      add('No profile name or photo', h.weightNoProfileMetadata);
    }

    switch (signals.mutualConnectionCount) {
      case null:
        break;
      case 0:
        add('No connections in common', h.weightNoMutualConnections);
      case final count:
        final counted = count.clamp(0, h.mutualConnectionCap);
        add('Connections in common', counted * h.weightPerMutualConnection);
    }

    if (signals.followsMe) {
      add('Follows you', h.weightFollowsMe);
    }
    if (signals.hasPriorPublicInteraction) {
      add('You have interacted before', h.weightPriorPublicInteraction);
    }
    if (messageSignals.containsLink) {
      add(
        'First message contains a link',
        h.weightContainsLink,
        aboutMessage: true,
      );
    }
    if (messageSignals.containsMedia) {
      add(
        'First message contains media',
        h.weightContainsMedia,
        aboutMessage: true,
      );
    }
    return reasons;
  }
}
