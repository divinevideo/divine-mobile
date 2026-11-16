// ABOUTME: PROTOTYPE (#8076) — the settings the tuning panel edits.
// ABOUTME: Held as one value so Save applies them together and back
// ABOUTME: discards them together.

import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_classifier.dart';

/// Where the Official bucket is rendered.
enum OfficialPlacement {
  /// Official gets its own tab. Findable and impersonation-resistant, but it
  /// is an extra place to look — a support message about a report lands
  /// somewhere the user is not looking by default.
  ownTab,

  /// Official is pinned to the top of Inbox. Matches "official messages go
  /// directly to the inbox" literally and stays visually distinct;
  /// operational accounts stay unblockable.
  pinnedInInbox,
}

/// How a request row presents its sender, for comparison in research.
enum RequestPresentation {
  /// Sender context only.
  contextOnly,

  /// Sender context plus an optional "Why is this here?" panel.
  contextWithReasons,

  /// Sender context plus one line of factual caution text.
  contextWithCaution,
}

/// Everything the tuning panel can change.
class DmPrototypeSettings {
  const DmPrototypeSettings({
    this.heuristics = const DmSpamHeuristics(),
    this.placement = OfficialPlacement.ownTab,
    this.presentation = RequestPresentation.contextWithReasons,
    this.showScores = false,
  });

  final DmSpamHeuristics heuristics;
  final OfficialPlacement placement;
  final RequestPresentation presentation;

  /// Facilitator view: shows numeric scores and the threshold on rows, and
  /// reasons about a still-hidden message. Off for participants, because the
  /// numbers double as an evasion recipe.
  final bool showScores;

  DmPrototypeSettings copyWith({
    DmSpamHeuristics? heuristics,
    OfficialPlacement? placement,
    RequestPresentation? presentation,
    bool? showScores,
  }) {
    return DmPrototypeSettings(
      heuristics: heuristics ?? this.heuristics,
      placement: placement ?? this.placement,
      presentation: presentation ?? this.presentation,
      showScores: showScores ?? this.showScores,
    );
  }
}
