// ABOUTME: Instagram-style combined reaction pill beneath a DM bubble —
// ABOUTME: distinct emoji glyph(s) + an overlapping stack of reactor avatars.
// ABOUTME: Tapping opens the "who reacted" sheet. One pill per message, for
// ABOUTME: both 1:1 and group conversations.

import 'package:collection/collection.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reactions_detail_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Renders the combined reaction pill for one DM message. Reads from
/// [ConversationReactionsCubit] via `BlocBuilder` with a per-message
/// `buildWhen` so only this row rebuilds when its reactions (or in-flight
/// pending state) change.
class ReactionsRow extends StatefulWidget {
  /// Construct a reactions row.
  const ReactionsRow({
    required this.conversationId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.ownerPubkey,
    required this.isSentByMe,
    this.blockedPubkeys = const <String>{},
    this.removalEnabled = true,
    super.key,
  });

  /// Conversation containing the message.
  final String conversationId;

  /// Rumor id of the target message.
  final String messageId;

  /// Author of the target message.
  final String messageAuthorPubkey;

  /// Pubkey of the current account (own-reaction detection).
  final String ownerPubkey;

  /// True if the bubble was sent by the current account.
  final bool isSentByMe;

  /// Pubkeys whose reactions should be hidden.
  final Set<String> blockedPubkeys;

  /// Whether the own-reaction row in the detail sheet may retract the
  /// reaction. False on a closed thread: the kind-5 is refused by
  /// `DmSendPolicy`, so tapping it would only drop the local copy of a
  /// reaction the recipient still holds. The sheet still opens — reading who
  /// reacted is not a write.
  final bool removalEnabled;

  @override
  State<ReactionsRow> createState() => _ReactionsRowState();
}

class _ReactionsRowState extends State<ReactionsRow> {
  /// Emojis already on the message when this row first built — a conversation
  /// opening, or a reacted row scrolling back into view. A glyph whose emoji is
  /// absent here is a post-mount addition (a live incoming reaction, or the
  /// user's own double-tap ❤️) and grows in via [_PoppingEmoji]; emojis in the
  /// baseline render settled. Captured on the first build even when the message
  /// starts with zero reactions, so the first like on a never-reacted message —
  /// which mounts the pill for the first time — still pops. This lives on the
  /// row (always mounted for a visible message) rather than the pill (absent
  /// until the first reaction), so the empty → first-reaction transition reads
  /// as an addition, not an initial mount.
  Set<String>? _baselineEmojis;

  @override
  void didUpdateWidget(ReactionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A ListView can rebind this element to a different message; drop the
    // baseline so it recaptures for the new message on the next build.
    if (oldWidget.messageId != widget.messageId) {
      _baselineEmojis = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when EITHER the persisted reactions for this message change OR
    // the in-flight pending entries for this message change — so the own
    // avatar's sending → settled/failed transition is reflected.
    return BlocBuilder<ConversationReactionsCubit, ConversationReactionsState>(
      buildWhen: (prev, curr) {
        if (!_listEquals(
          prev.reactionsFor(widget.messageId),
          curr.reactionsFor(widget.messageId),
        )) {
          return true;
        }
        return !_pendingForMessageEquals(
          prev.pending,
          curr.pending,
          widget.messageId,
        );
      },
      builder: (context, state) {
        final reactions = state
            .reactionsFor(widget.messageId)
            .where((r) => !widget.blockedPubkeys.contains(r.reactorPubkey))
            .toList(growable: false);
        // Capture the baseline on the first build (even when empty) so the very
        // first reaction added afterwards — the double-tap ❤️ — reads as new.
        _baselineEmojis ??= reactions.map((r) => r.emoji).toSet();
        if (reactions.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Align(
            alignment: widget.isSentByMe
                ? Alignment.centerRight
                : Alignment.centerLeft,
            // Pull the pill up ~14 px so it overlaps the bubble's bottom edge,
            // the way iMessage / WhatsApp / Signal present reactions.
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: _ReactionPill(
                reactions: reactions,
                ownerPubkey: widget.ownerPubkey,
                removalEnabled: widget.removalEnabled,
                baselineEmojis: _baselineEmojis!,
                onTap: () => ReactionsDetailSheet.show(
                  context: context,
                  cubit: context.read<ConversationReactionsCubit>(),
                  conversationId: widget.conversationId,
                  messageId: widget.messageId,
                  messageAuthorPubkey: widget.messageAuthorPubkey,
                  ownerPubkey: widget.ownerPubkey,
                  blockedPubkeys: widget.blockedPubkeys,
                  removalEnabled: widget.removalEnabled,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The combined pill: distinct emoji glyph(s) + overlapping reactor avatars.
class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.reactions,
    required this.ownerPubkey,
    required this.removalEnabled,
    required this.baselineEmojis,
    required this.onTap,
  });

  /// Live reactions for the message (blocklist-filtered, ascending createdAt).
  final List<DmReaction> reactions;
  final String ownerPubkey;
  final bool removalEnabled;

  /// Emojis already present when the enclosing row first built. A shown glyph
  /// whose emoji is absent here is a post-mount addition and grows in; emojis
  /// in the baseline render settled (see [_PoppingEmoji.animateIn]).
  final Set<String> baselineEmojis;
  final VoidCallback onTap;

  static const int _maxEmojis = 3;
  static const int _maxAvatars = 3;
  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    // Most-recent reactor first for both glyphs and avatars. Cap-at-one means
    // one live reaction per reactor, so `recent` already has one entry per
    // reactor and its length is the total reactor count.
    final recent = reactions.reversed.toList(growable: false);

    final seen = <String>{};
    final distinctEmojis = <String>[];
    for (final r in recent) {
      if (seen.add(r.emoji)) distinctEmojis.add(r.emoji);
    }
    final shownEmojis = distinctEmojis.take(_maxEmojis).toList();
    final extraEmojis = distinctEmojis.length - shownEmojis.length;

    final shownReactors = recent.take(_maxAvatars).toList();
    final extraReactors = recent.length - shownReactors.length;

    final ownReaction = recent.firstWhereOrNull(
      (r) => r.reactorPubkey == ownerPubkey,
    );
    final hasOwn = ownReaction != null;
    final isOwnPending =
        ownReaction?.publishStatus == DmReactionPublishStatus.pending;
    final isOwnFailed =
        ownReaction?.publishStatus == DmReactionPublishStatus.failed;
    final isOwnRemovalRefused =
        removalEnabled &&
        ownReaction?.publishStatus == DmReactionPublishStatus.removalRefused;

    final background = isOwnFailed || isOwnRemovalRefused
        ? context.vineColors.errorContainer
        : hasOwn
        ? context.vineColors.primaryContainer
        : context.vineColors.containerLow;
    final borderColor = isOwnFailed || isOwnRemovalRefused
        ? VineTheme.error
        : hasOwn
        ? context.vineColors.accentPositive
        : context.vineColors.outline;
    final borderRadius = BorderRadius.circular(_height / 2);

    final overflowStyle = VineTheme.labelSmallFont(
      color: context.vineColors.onSurface,
    ).copyWith(fontSize: 11, height: 1);

    final rowChildren = <Widget>[
      for (var i = 0; i < shownEmojis.length; i++) ...[
        if (i > 0) const SizedBox(width: 1),
        // Keyed by emoji so a newly-added glyph (e.g. a double-tap ❤️) spins up
        // a fresh element that grows in, while existing glyphs keep their
        // element — and settled scale — across rebuilds. animateIn gates the
        // pop to emojis absent from the row's mount-time baseline, so the
        // initial set (open / scroll-in) settles silently.
        _PoppingEmoji(
          shownEmojis[i],
          key: ValueKey(shownEmojis[i]),
          animateIn: !baselineEmojis.contains(shownEmojis[i]),
        ),
      ],
      if (extraEmojis > 0) ...[
        const SizedBox(width: 2),
        Text('+$extraEmojis', style: overflowStyle),
      ],
      const SizedBox(width: 5),
      _ReactionAvatarStack(
        reactors: shownReactors,
        extraCount: extraReactors,
        ownerPubkey: ownerPubkey,
      ),
    ];

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // Fixed-size overlay badge — pin text scaling so a large system
          // font can't inflate the pill past its fixed-height avatars.
          child: MediaQuery.withNoTextScaling(
            child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: context.l10n.dmReactionsViewA11yLabel,
        child: Opacity(
          opacity: isOwnPending ? 0.65 : 1.0,
          child: Material(
            type: MaterialType.transparency,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ExcludeSemantics(child: pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text style for a reaction glyph.
///
/// 🔥 is painted by the platform colour-emoji font (Inter ships no emoji), so a
/// forced line-height drops the glyph low on Android. Natural leading lets the
/// Row centre the glyph box — mirrors reaction_picker_overlay.
const _emojiTextStyle = TextStyle(fontSize: 15);

/// Duration of the reaction glyph grow-in.
const _emojiPopDuration = Duration(milliseconds: 180);

/// A reaction emoji glyph that gently grows in (no bounce) when [animateIn] is
/// set, otherwise mounts already at its settled scale. [_ReactionPill] keys
/// each glyph by its emoji and only passes `animateIn: true` for a glyph added
/// *after* the row mounted (a live incoming reaction or the user's own
/// double-tap ❤️) — so the initial set (conversation open, scroll-in) settles
/// silently and existing glyphs never re-pop. Scale-only (paint transform), so
/// it never reflows the fixed-height pill.
class _PoppingEmoji extends StatefulWidget {
  const _PoppingEmoji(this.emoji, {required this.animateIn, super.key});

  final String emoji;

  /// Whether this glyph grows in on mount. False for glyphs already present at
  /// the row's first build; true for a glyph that appears once mounted.
  final bool animateIn;

  @override
  State<_PoppingEmoji> createState() => _PoppingEmojiState();
}

class _PoppingEmojiState extends State<_PoppingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _emojiPopDuration,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.6,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: DivineHeartText(widget.emoji, style: _emojiTextStyle),
    );
  }
}

/// Overlapping circular reactor avatars, with a trailing "+N" circle when
/// more reactors exist than are shown.
class _ReactionAvatarStack extends StatelessWidget {
  const _ReactionAvatarStack({
    required this.reactors,
    required this.extraCount,
    required this.ownerPubkey,
  });

  final List<DmReaction> reactors;
  final int extraCount;
  final String ownerPubkey;

  static const double _size = 20;
  static const double _overlap = 13;

  @override
  Widget build(BuildContext context) {
    final circleCount = reactors.length + (extraCount > 0 ? 1 : 0);
    if (circleCount == 0) return const SizedBox.shrink();

    return SizedBox(
      width: _size + (circleCount - 1) * _overlap,
      height: _size,
      child: Stack(
        children: [
          // top/bottom: 0 + Center vertically centres each circle in the
          // stack — without it a sub-`_size` avatar pins to the top edge.
          for (var i = 0; i < reactors.length; i++)
            Positioned(
              left: i * _overlap,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PillAvatar(
                  pubkey: reactors[i].reactorPubkey,
                  dimmed:
                      reactors[i].reactorPubkey == ownerPubkey &&
                      reactors[i].publishStatus ==
                          DmReactionPublishStatus.pending,
                ),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: reactors.length * _overlap,
              top: 0,
              bottom: 0,
              child: Center(child: _ExtraReactorsCircle(count: extraCount)),
            ),
        ],
      ),
    );
  }
}

class _PillAvatar extends ConsumerWidget {
  const _PillAvatar({required this.pubkey, required this.dimmed});

  final String pubkey;
  final bool dimmed;

  static const double _diameter = 17;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(pubkey))
        .asData
        ?.value;

    // The pill is what opens the reactor sheet, so it resolves the vanish the
    // same way: a peer whose photo is still on the pill and whose sheet row
    // reads "Deleted account" is the divergence this pill would introduce.
    final isVanished = ref.watch(profileVanishedProvider(pubkey));

    // cornerRadius == diameter / 2 makes UserAvatar a true circle whose own
    // border is circular too. Clipping the default rounded-square avatar to a
    // circle would slice that border into arcs (the "cut border" artifact) —
    // the wrapping white ring hides it here, but the sheet has no ring.
    final avatar = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.vineColors.primaryText, width: 1.5),
      ),
      child: UserAvatar(
        imageUrl: isVanished ? null : profile?.picture,
        // The initial is derived from the name, so a stale row would leak the
        // account's first letter even with the picture suppressed.
        name: isVanished
            ? context.l10n.profileDeletedAccountName
            : profile?.bestDisplayName,
        size: _diameter,
        cornerRadius: _diameter / 2,
      ),
    );

    return dimmed ? Opacity(opacity: 0.5, child: avatar) : avatar;
  }
}

class _ExtraReactorsCircle extends StatelessWidget {
  const _ExtraReactorsCircle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.vineColors.containerLow,
        border: Border.all(color: context.vineColors.primaryText, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: VineTheme.labelSmallFont(
          color: context.vineColors.onSurface,
        ).copyWith(fontSize: 9, height: 1),
      ),
    );
  }
}

bool _listEquals(List<DmReaction> a, List<DmReaction> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _pendingForMessageEquals(
  Map<ReactionPublishKey, ReactionPublishLocalStatus> a,
  Map<ReactionPublishKey, ReactionPublishLocalStatus> b,
  String messageId,
) {
  if (identical(a, b)) return true;
  var aCount = 0;
  var bCount = 0;
  for (final entry in a.entries) {
    if (entry.key.messageId != messageId) continue;
    aCount++;
    if (b[entry.key] != entry.value) return false;
  }
  for (final entry in b.entries) {
    if (entry.key.messageId == messageId) bCount++;
  }
  return aCount == bCount;
}
